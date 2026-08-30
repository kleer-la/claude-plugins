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
| `scroll:` | `:top` \| `:bottom` \| Integer \| `"css:<selector>"`. |
| `pause:` | Wait before the shot (default 0.4). |

`inject_csrf_meta` injects a dummy CSRF meta tag: Rails disables CSRF in the test
environment so `csrf_meta_tags` renders nothing, yet some flows still expect the tag.

## Difference from the Playwright recipe

`focus:` crops to the element's exact box: Selenium takes an element screenshot, not a
crop of the viewport, so there is no equivalent to `focusPad`. If you need context around
it, **frame with `highlight:` instead of cropping with `focus:`**.

Everything else behaves the same, on purpose.

## Running it

Video tests usually sit behind a flag so they do not run in CI:

```ruby
test "placing an order" do
  skip "only with RUN_VIDEO_TESTS=1" unless ENV["RUN_VIDEO_TESTS"]
```

```bash
docker exec -e RUN_VIDEO_TESTS=1 <container> bin/rails test test/system/checkout_video_test.rb
```
