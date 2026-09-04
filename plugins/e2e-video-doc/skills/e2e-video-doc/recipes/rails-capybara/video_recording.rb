# Video captures from a Rails system test (Capybara + Selenium).
#
# Same contract as the Playwright recipe: `NN_name.png` files in a directory, which the
# engine then consumes. The parity with `capture.ts` is deliberate — `highlight:` and
# `scroll:` behave the same; `focus:` has one limitation, documented below.
#
# Usage:
#   class CheckoutVideoTest < ApplicationSystemTestCase
#     include VideoRecording
#     driven_by :selenium, using: :headless_chrome, screen_size: [1280, 800]
#     def scenario_name = "checkout"
#
#     test "placing an order" do
#       setup_video_recording
#       visit root_path
#       capture "start"
#       capture "total", highlight: "#total", scroll: "css:#total"
#     end
#   end
module VideoRecording
  # The box is drawn as its own element on document.body, not as a mark on the element
  # it frames. A mark on the element is lost the moment the framework re-renders that
  # node — Turbo replaces it with the server's HTML, which never carried the attribute —
  # and the loss is silent: the selector matched, the test passes, the photograph simply
  # has no box on it. Measured on a real app: the mark scored 3411 red pixels before the
  # remount and 0 after, with a green test both times. Nothing on document.body is
  # reachable by a re-render of the app's own tree.
  OVERLAY_ATTR = "data-e2e-overlay".freeze
  # Geometry that reproduces what `outline: 3px` at `outline-offset: 2px` used to draw:
  # 2px of air, then a 3px ring, then the glow outside it.
  OVERLAY_GAP = 2
  OVERLAY_BORDER = 3

  # Scenario name — captures go to tmp/video_screenshots/<scenario>/
  def scenario_name
    raise NotImplementedError, "define scenario_name in the test class"
  end

  def screenshot_dir
    @screenshot_dir ||= Rails.root.join("tmp", "video_screenshots", scenario_name)
  end

  def setup_video_recording
    FileUtils.rm_rf(screenshot_dir)
    FileUtils.mkdir_p(screenshot_dir)
    @step = 0
  end

  # scroll:    :bottom | :top | Integer (pixels) | "css:<selector>" | "text:<substring>"
  # highlight: selector or array of selectors — red box during the shot.
  # focus:     selector — photographs only that element.
  #            Note: Selenium crops to the exact box, without the air that `focusPad`
  #            gives in Playwright. If you need context around it, frame with
  #            highlight: instead of cropping with focus:.
  #            A `highlight:` on the same capture will not appear in the crop: the ring
  #            is drawn just outside the element, which is precisely what Selenium leaves
  #            out. Measured, and equally true of the outline this replaced — pick one.
  # assert_in_frame: selector — refuse to take the picture unless that element is whole
  #            inside the viewport and nothing is covering it. See `frame_problem`.
  def capture(name, pause: 0.4, scroll: nil, highlight: nil, focus: nil, assert_in_frame: nil)
    apply_scroll(scroll) if scroll
    # Before the box is drawn, because putting the scroll right afterwards would leave the
    # box behind at the old position — it is placed once and does not follow.
    ensure_in_frame(assert_in_frame, scroll) if assert_in_frame
    marks = Array(highlight)
    highlight_on(marks) if marks.any?

    sleep pause
    # Again, after the pause and immediately before the shutter, because this is what the
    # camera will see. Turbo resets the scroll position asynchronously after a navigation,
    # so a scroll can still be undone in the time it takes to settle — and that produces a
    # perfectly valid photograph of the wrong part of the page.
    if assert_in_frame && (problem = frame_problem(assert_in_frame))
      raise "capture(#{name.inspect}): #{assert_in_frame.inspect} #{problem} at the moment of the shot"
    end

    @step += 1
    filename = format("%02d_%s.png", @step, name)
    target = screenshot_dir.join(filename)

    if focus
      find(focus).native.save_screenshot(target.to_s)
    else
      page.save_screenshot(target)
    end

    highlight_off if marks.any?
    filename
  end

  # Closes whatever your stack puts on top of the page — a trial strip, a dev-environment
  # bar, a notification prompt. The counterpart of `dismissBanner` in the Playwright
  # recipe. Absent is fine: the walkthrough must not fail because the thing it was
  # cleaning up is not there. Call it after navigating, before the first capture.
  def dismiss_banner(selector)
    find(selector, match: :first, wait: 2).click
    sleep 0.2
  rescue Capybara::ElementNotFound
    # banner absent
  end

  # Injects a dummy CSRF meta tag. Rails disables CSRF in the test environment, so
  # `csrf_meta_tags` renders nothing — but some flows still expect the tag to be there.
  # Call it after navigating.
  def inject_csrf_meta
    page.execute_script(<<~JS)
      if (!document.querySelector("meta[name='csrf-token']")) {
        const m = document.createElement("meta");
        m.setAttribute("name", "csrf-token");
        m.setAttribute("content", "test-token");
        document.head.appendChild(m);
      }
    JS
  end

  private

  def apply_scroll(scroll)
    case scroll
    when :bottom then page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    when :top then page.execute_script("window.scrollTo(0, 0)")
    when Integer then page.execute_script("window.scrollBy(0, arguments[0])", scroll)
    when /\Acss:(.+)\z/ then scroll_into_view(find(Regexp.last_match(1), match: :first, visible: :all))
    when /\Atext:(.+)\z/
      # By visible text, for screens where nothing useful has a stable selector.
      scroll_into_view(find(:xpath, "//*[contains(text(), '#{Regexp.last_match(1)}')]", match: :first, visible: :all))
    else raise ArgumentError, "unrecognized scroll: #{scroll.inspect}"
    end
  end

  # `this`, not arguments[0]: Capybara's Element#execute_script applies the script with
  # the element as the receiver, unlike page.execute_script where it would be passed in.
  #
  # `behavior: "instant"` is not decoration. Bootstrap 5 ships
  # `@media (prefers-reduced-motion: no-preference) { :root { scroll-behavior: smooth } }`,
  # and headless Chrome reports no-preference — so on a Bootstrap app every scroll
  # animates, and whether the shot catches the page mid-flight is a race against `pause`.
  # `block: "center"` is the other half: `:top` parks the element under a fixed navbar.
  def scroll_into_view(element)
    element.execute_script("this.scrollIntoView({block: 'center', behavior: 'instant'})")
  end

  # Nil when the element is whole in the viewport and visible; otherwise a phrase saying
  # what is wrong with it. Three ways a capture goes silently wrong: the subject is off
  # the top or bottom of the frame, it has no box at all, or something is sitting on top
  # of it — a fixed navbar, a modal, a cookie bar. The last one is why this asks the
  # document what is actually painted at the middle of the element rather than trusting
  # the rectangle. The overlay this recipe draws has `pointer-events: none`, so
  # elementFromPoint looks straight through it.
  def frame_problem(selector)
    find(selector, match: :first, visible: :all).evaluate_script(<<~JS)
      (() => {
        const r = this.getBoundingClientRect();
        if (r.width === 0 || r.height === 0) return "has no box on the page";
        if (r.top < 0) return "starts " + Math.round(-r.top) + "px above the frame";
        if (r.bottom > window.innerHeight) return "runs " + Math.round(r.bottom - window.innerHeight) + "px past the bottom of the frame";
        if (r.left < 0 || r.right > window.innerWidth) return "runs off the side of the frame";
        const over = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
        if (over && over !== this && !this.contains(over)) {
          const cls = over.className && typeof over.className === "string" ? "." + over.className.trim().split(/\s+/).join(".") : "";
          return "is covered by <" + over.tagName.toLowerCase() + cls + ">";
        }
        return null;
      })()
    JS
  end

  # One retry, then a loud failure. The retry is for Turbo: it resets the scroll position
  # asynchronously after a navigation, so a scroll applied a moment too early is undone
  # and the page is back at the top with nothing complaining.
  def ensure_in_frame(selector, scroll)
    return unless (problem = frame_problem(selector))

    if scroll
      apply_scroll(scroll)
    else
      scroll_into_view(find(selector, match: :first, visible: :all))
    end
    sleep 0.3
    return unless (problem = frame_problem(selector))

    raise "capture: #{selector.inspect} #{problem}, and scrolling again did not fix it"
  end

  def highlight_on(selectors)
    selectors.each do |sel|
      # Loud failure on purpose: a highlight that does not match is narration pointing at
      # something no longer on the screen — exactly the change the video exists to catch.
      # `find` raises on its own; the rect is read through the element so this keeps
      # working for Capybara selectors, which are not all CSS.
      #
      # `this`, not arguments[0]: Element#evaluate_script applies the script with the
      # element as the receiver. The arrow function inherits that `this`; a `function`
      # would not.
      rect = find(sel).evaluate_script(<<~JS)
        (() => { const r = this.getBoundingClientRect();
                 return [ r.left, r.top, r.width, r.height ]; })()
      JS
      draw_overlay(rect)
    end
  end

  # Viewport coordinates, so the box must be drawn after any scrolling — which is the
  # order `capture` already uses — and it is a photograph of one instant: it does not
  # follow the element if the page moves afterwards. That is the trade for surviving a
  # re-render, and for a screenshot taken milliseconds later it is the right one.
  def draw_overlay(rect)
    left, top, width, height = rect.map(&:to_f)
    page.execute_script(<<~JS, OVERLAY_ATTR, left, top, width, height, OVERLAY_GAP, OVERLAY_BORDER)
      const [attr, left, top, width, height, gap, border] = arguments;
      const box = document.createElement("div");
      box.setAttribute(attr, "1");
      box.style.cssText =
        "position:fixed;box-sizing:border-box;pointer-events:none;z-index:2147483647;" +
        "left:" + (left - gap - border) + "px;top:" + (top - gap - border) + "px;" +
        "width:" + (width + 2 * (gap + border)) + "px;" +
        "height:" + (height + 2 * (gap + border)) + "px;" +
        "border:" + border + "px solid #d9534f;border-radius:3px;" +
        "box-shadow:0 0 0 6px rgba(217, 83, 79, .18)";
      document.body.appendChild(box);
    JS
  end

  def highlight_off
    page.execute_script(<<~JS, OVERLAY_ATTR)
      document.querySelectorAll("[" + arguments[0] + "]").forEach((el) => el.remove());
    JS
  end
end
