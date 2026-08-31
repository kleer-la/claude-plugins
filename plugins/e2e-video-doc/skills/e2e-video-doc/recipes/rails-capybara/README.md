# Rails recipe (Capybara + Selenium)

Copy `video_recording.rb` into `test/support/`.

```ruby
class CheckoutVideoTest < ApplicationSystemTestCase
  include VideoRecording
  driven_by :selenium, using: :headless_chrome, screen_size: [1280, 800]

  def scenario_name = "checkout"

  test "placing an order" do
    setup_video_recording
    visit root_path
    capture "start"
    capture "total", highlight: "#total", scroll: "css:#total"
  end
end
```

Screenshots go to `tmp/video_screenshots/<scenario_name>/`. **The MP4 cannot stay there** —
`setup_video_recording` does `rm -rf` on that directory.

| Option | What it does |
|---|---|
| `highlight:` | Red box, one or more selectors. Raises if it does not match. |
| `focus:` | Photographs only that element. **No padding** — see below. |
| `scroll:` | `:top` \| `:bottom` \| Integer \| `"css:<selector>"` \| `"text:<substring>"`. |
| `pause:` | Wait before the shot (default 0.4). |

`dismiss_banner(selector)` closes what sits on top of the page — a trial strip, a
dev-environment bar, a notification prompt — and does nothing if it is not there. Call it
after navigating, before the first capture, so it does not end up in every frame.

`inject_csrf_meta` injects a dummy CSRF meta tag: Rails disables CSRF in the test
environment so `csrf_meta_tags` renders nothing, yet some flows still expect the tag.

## Difference from the Playwright recipe

`focus:` crops to the element's exact box: Selenium takes an element screenshot, not a
crop of the viewport, so there is no equivalent to `focusPad`. If you need context around
it, **frame with `highlight:` instead of cropping with `focus:`**.

Everything else behaves the same, on purpose.

## Running it

`run.sh` exports `RUN_VIDEO_TESTS=1` for the capture command, so video tests sit behind
that flag and a normal `bin/rails test:system` skips them. `docker exec` does not forward
the host environment — pass it through explicitly with `-e RUN_VIDEO_TESTS=1`.

```ruby
setup do
  # First in setup, not in the test body: setup_video_recording rm -rf's the screenshot
  # directory, so a skip further down still wipes the last real run's captures.
  skip "only with RUN_VIDEO_TESTS=1" unless ENV["RUN_VIDEO_TESTS"]
  setup_video_recording
end
```

```bash
docker exec -e RUN_VIDEO_TESTS=1 "$(bash "$E2E_VIDEO_DOC_ENGINE/devcontainer.sh" web)" \
  bin/rails test test/system/checkout_video_test.rb
```
