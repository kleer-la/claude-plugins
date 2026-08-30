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
  HIGHLIGHT_ATTR = "data-e2e-highlight".freeze
  HIGHLIGHT_STYLE_ID = "e2e-highlight-style".freeze
  HIGHLIGHT_CSS = <<~CSS.freeze
    [#{HIGHLIGHT_ATTR}] {
      outline: 3px solid #d9534f !important;
      outline-offset: 2px !important;
      box-shadow: 0 0 0 6px rgba(217, 83, 79, .18) !important;
      border-radius: 3px;
    }
  CSS

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

  # scroll:    :bottom | :top | Integer (pixels) | "css:<selector>"
  # highlight: selector or array of selectors — red box during the shot.
  # focus:     selector — photographs only that element.
  #            Note: Selenium crops to the exact box, without the air that `focusPad`
  #            gives in Playwright. If you need context around it, frame with
  #            highlight: instead of cropping with focus:.
  def capture(name, pause: 0.4, scroll: nil, highlight: nil, focus: nil)
    apply_scroll(scroll) if scroll
    marks = Array(highlight)
    highlight_on(marks) if marks.any?

    sleep pause
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
    when /\Acss:(.+)\z/ then find(Regexp.last_match(1)).execute_script("arguments[0].scrollIntoView({block: 'center'})")
    else raise ArgumentError, "unrecognized scroll: #{scroll.inspect}"
    end
  end

  def highlight_on(selectors)
    page.execute_script(<<~JS, HIGHLIGHT_STYLE_ID, HIGHLIGHT_CSS)
      if (!document.getElementById(arguments[0])) {
        const s = document.createElement("style");
        s.id = arguments[0];
        s.textContent = arguments[1];
        document.head.appendChild(s);
      }
    JS
    selectors.each do |sel|
      # Loud failure on purpose: a highlight that does not match is narration pointing at
      # something no longer on the screen — exactly the change the video exists to catch.
      find(sel).execute_script("arguments[0].setAttribute(arguments[1], '1')", HIGHLIGHT_ATTR)
    end
  end

  def highlight_off
    page.execute_script(<<~JS, HIGHLIGHT_ATTR)
      document.querySelectorAll("[" + arguments[0] + "]")
        .forEach((el) => el.removeAttribute(arguments[0]));
    JS
  end
end
