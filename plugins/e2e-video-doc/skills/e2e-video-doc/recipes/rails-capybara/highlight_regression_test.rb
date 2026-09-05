require "application_system_test_case"
require_relative "../support/video_recording"

# Copy this next to your other system tests and run it after every update of
# `video_recording.rb`:
#
#   bin/rails test test/system/highlight_regression_test.rb
#
# It proves one thing, which was silently false for two releases: the red box outlives a
# re-render of the node it frames. It used to be a mark on the element — an attribute and
# a CSS rule — and Turbo streams, React renders and DevExpress grid callbacks all replace
# that node with fresh markup that never carried the mark. Nothing failed when they did:
# the selector matched, the test passed, and only the photograph had no box on it.
#
# The subject is built here rather than found, so this needs no fixtures, no login and no
# particular screen — point PATH at any page of yours that renders.
class HighlightRegressionTest < ApplicationSystemTestCase
  include VideoRecording

  PATH = "/".freeze

  # Its own driver, matching what the video specs use: `ApplicationSystemTestCase`'s
  # default is often a Chrome that will not start inside a container, and this test then
  # fails for a reason that has nothing to do with what it checks. Copy the `driven_by`
  # from your video spec if it differs from this one.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 863 ] do |options|
    options.binary = "/usr/bin/chromium" if File.exist?("/usr/bin/chromium")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
  end

  def scenario_name = "highlight_regression"

  test "the box outlives a re-render of the node it frames" do
    visit PATH
    page.execute_script(<<~JS)
      const host = document.createElement("div");
      host.id = "regression-host";
      host.innerHTML = '<p id="the-subject" style="padding:20px">the narrated thing</p>';
      document.body.prepend(host);
    JS

    original = page.evaluate_script("document.querySelector('#regression-host').innerHTML")
    highlight_on([ "#the-subject" ])
    assert_selector "[data-e2e-overlay]", visible: :all, count: 1,
                    wait: 2 # the box is drawn at all

    # A re-render, in miniature: the markup the server sent, put back over the live node.
    # NOT `cloneNode(true)` — a clone copies attributes, so a mark on the element rides
    # along and this test passes against the very bug it exists to catch.
    page.execute_script(
      "document.querySelector('#regression-host').innerHTML = arguments[0]", original
    )

    # `assert` rather than `assert_selector`, which takes no custom message and would
    # report only "expected to find css [data-e2e-overlay]" for the one failure this
    # whole file exists to explain.
    assert page.has_selector?("[data-e2e-overlay]", visible: :all, count: 1, wait: 2),
           "the box left with the node it framed — it is being drawn inside the app's " \
           "tree instead of on document.body"

    highlight_off
    assert_no_selector "[data-e2e-overlay]", visible: :all, wait: 2
  end
end
