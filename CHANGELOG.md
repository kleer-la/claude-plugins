# Changelog

## 0.3.3

0.3.0 made `scroll:` instant and only got half of it. Found while updating a downstream
issue and looking at what that project's flow actually calls: every one of its captures
uses `scroll: :bottom`, which was the half still animating.

### Fixed

- **`:bottom`, `:top` and the pixel offset scrolled smoothly too.** `window.scrollTo(0, y)`
  is the two-argument form, which means `behavior: "auto"`, which resolves to the computed
  `scroll-behavior` — smooth on a Bootstrap app, or anywhere a stylesheet asks for it. Only
  `scroll_into_view` was fixed in 0.3.0. All branches now pass `behavior: "instant"`.

  **Demonstrated on Capybara/Selenium**, which is where it bites: with the old code, the
  scroll position one command after `apply_scroll(:bottom)` was **0** on a 4213px page, and
  4213 once it settled — so a capture with a short pause photographs the top of the page and
  calls it the bottom. With the fix it is 4213 immediately. The longer the page, the worse:
  a default `pause: 0.4` covers a short scroll and not a long one, which is why this can sit
  in a project for months looking fine.

  **On Playwright the same change is a guard, not a demonstrated fix.** The bare capture
  path there completed the scroll before the shutter in every measurement, and two probes of
  the underlying behaviour disagreed with each other, so the honest claim is parity with the
  Capybara recipe and protection if that ever changes — not a bug caught.

### Added

- `examples/sample-app/tests/framing.spec.ts` gains a bottom-scroll case, and it takes two
  photographs — one immediately, one after the page cannot still be moving — and asserts they
  are of the same place. It deliberately passes neither `highlight:` nor `assertInFrame`:
  `boundingBox()` inside `highlightOn` scrolls the element into view, and the framing check's
  retry re-centres it, so **either option quietly corrects the very thing under test**. That
  is worth knowing before writing any test in this area; two earlier versions of this one
  passed against a deliberately broken recipe for exactly that reason.
- `examples/sample-app/tests/pixels.ts` — `redPixels` and `frameDiff`, shared by the
  fixtures. Both decode PNGs by drawing them into a canvas in the browser, so the tests need
  no image library and no ffmpeg.

## 0.3.2

Everything here comes from porting the 0.2.3 overlay into a **fork** of the Playwright
recipe ([#11]) — a case the skill did not describe, in the repo most exposed to the bug it
fixed.

### Added

- **A regression test for the highlight, in both recipes.** `examples/sample-app/tests/
  highlight.spec.ts` stages a re-render of the framed node from a timer inside `capture`'s
  own pause and counts the red pixels in the PNGs; it scores the same box before and after,
  and **0** after when run against the pre-0.2.3 implementation, which is how it was
  verified. `recipes/rails-capybara/highlight_regression_test.rb` is its Capybara
  counterpart, to copy into `test/system/`: it asserts the box outlives the re-render at
  the DOM level, so it needs no image decoding, no fixtures and no particular screen. Both
  were run in both directions.

### Documented

- **`SKILL.md` carries the re-render failure now, not only `gotchas.md`.** Agents follow
  the skill, and it still listed two silent failures where there had been three. It now
  says what the recipes do about the third (the box is its own element on `document.body`)
  and that **any hand-written helper or fork has to keep that property** — with Turbo
  streams, React renders and DevExpress grid callbacks named, because they are the same
  failure wearing three different hats.
- **Copy the recipe, do not fork it.** Project-specific work wraps the helper from
  outside; edits inside it have to be re-ported by hand on every update, which is how a
  real fork stayed on the broken mechanism for two releases. Where a fork already exists,
  `highlightOn`/`highlightOff` are the parts to re-port.
- **The installed copy can be older than the plugin.** `/plugin marketplace update` does
  not always leave the clone matching GitHub, and nothing in the skill files says so: one
  project ported a fix from the repository while its own installed `capture.ts` still had
  the old mechanism, so an agent following the local skill would have rebuilt the bug.
  Check `plugin.json` against `CHANGELOG.md` before trusting a local copy.

[#11]: https://github.com/kleer-la/claude-plugins/issues/11

## 0.3.1

### Added

- **`assert_in_frame:` takes the same selector forms as `scroll:`** in the Capybara recipe
  — plain CSS, `"css:…"` or `"text:…"` — so a capture can name its subject once and hand
  the same string to both. Found while applying 0.3.0 to a real report screen: its sections
  are Bootstrap cards with no id on them, and the only stable handle is the heading a reader
  can see, which is exactly why `scroll:` grew `text:` in the first place. The Playwright
  recipe already had this, because Playwright's own selector engine understands `text=`.

## 0.3.0

Five hand-maintained copies of `capture` in one project ([jaomai#70]) turned out to hold
four things the recipe did not. This takes them upstream, so the next project inherits
them by copying a file instead of by suffering.

### Added

- **`assert_in_frame:` / `assertInFrame`** — name the element the narration points at, and
  the capture refuses to be taken while that element is not whole in the viewport, or is
  covered by something. It asks the document what is actually painted at the middle of the
  element (`elementFromPoint`), so a sticky header, a modal or a cookie wall is caught, not
  merely a rectangle that looks fine. Checked twice: before the highlight is drawn, where a
  failure buys one more centred scroll, and again immediately before the shutter, where it
  raises — that is the moment the camera sees. Adapted from the `subject:` option one
  project had grown on its own.
- The sample app now carries a **sticky header and `scroll-behavior: smooth`**, and
  `tests/framing.spec.ts` exercises the rules against them: a scroll that must have landed
  by the shutter, a subject under a cookie wall that must be refused, an element with no box
  that must be refused. Those are the conditions of a real Bootstrap-shaped app, so the
  fixture now has them.

### Fixed

- **The Capybara recipe scrolled smoothly and photographed mid-flight.** Bootstrap 5 ships
  `@media (prefers-reduced-motion: no-preference) { :root { scroll-behavior: smooth } }` and
  headless Chrome reports no-preference, so on a Bootstrap app every `scroll:` was an
  animation racing `pause`. Measured on the sample: `scrollIntoView({block: "center"})` read
  `scrollY` 0 immediately and 190 six-tenths of a second later. The recipe now asks for
  `behavior: "instant"`; with the old code and `pause: 0` the framing check fails, which is
  how the fix was verified. **Playwright's `scrollIntoViewIfNeeded` was never affected** —
  measured at 190 immediately on the same page — so only one recipe changed.

### Documented

- Turbo restores the scroll position asynchronously after a navigation, so a scroll applied
  too early is undone in silence. The retry inside the framing check covers it, which is
  cheaper than the blind `sleep` it was costing one project.
- A pinned navbar hides the subject while `scrollIntoViewIfNeeded` and `align: :top` both
  consider it in view. Centring is the answer, and it is what the retry does.

[jaomai#70]: https://github.com/kleer-la/jaomai/issues/70

## 0.2.3

The remount failure #9 reported, fixed in both recipes rather than only written down
([#10]). Reproduced, fixed and re-measured on a real Rails app with Turbo and on the
sample app.

### Fixed

- **`highlight:` no longer marks the element it frames.** Both recipes set an attribute on
  the element and styled it with an outline, and any framework that re-renders that node
  between `highlightOn` and the screenshot takes the mark with it — Turbo replaces it with
  the server's HTML, React with the render output, and neither ever carried the attribute.
  Nothing failed: the selector matched, the test passed, and only the photograph had no box
  on it. Measured on a Rails login form, 3411 red pixels before the re-render and **0**
  after; on the sample app, 4004 and **0**. The box is now its own element on
  `document.body`, outside anything the app re-renders, with the geometry that reproduces
  the old `outline: 3px` at `outline-offset: 2px`. Same probe after the change: identical
  count and identical position, before and after the re-render.

  Verified across every path through `capture`: viewport shot, `fullPage`, `focus:` crop,
  and — the combination that could really have gone wrong — `fullPage` on a scrolled page
  taller than the viewport, where a `position:fixed` box has to land at the element's place
  in the whole page. Chromium puts it at `scrollY + top`, which is exactly right: element
  at page y=318, box drawn at y=313, the 5px being the 2px gap plus the 3px ring.

### Documented

- **`highlight:` and `focus:` do not combine in the Rails recipe.** Selenium photographs
  the element at its exact rect and the ring is drawn just outside it, so a capture asking
  for both comes back with no box. Measured, and equally true of the outline that preceded
  the overlay — it was never a regression, just never written down. Playwright's `focusPad`
  clips the viewport, so there the box survives.
- **`cloneNode(true)` cannot stage this failure**, which matters to anyone reproducing it:
  a clone copies attributes, the old mark rides along, and the bug appears not to exist.
  The first probe run said 3411 both times for exactly that reason. The faithful stand-in
  is putting the server's markup back over the node (`this.outerHTML = <captured html>`).

[#10]: https://github.com/kleer-la/claude-plugins/issues/10

## 0.2.2

A second outside run, this one end to end on a real Node/Nest app in "local production"
mode ([#9]): MP4 out, 8 of 8 captures used, nothing about the engine or the recipe
surprised anyone. Everything below is about the decisions the skill left implicit — which
is where the whole session's time actually went.

### Changed

- **`check.sh` no longer assumes pipx exists.** `edge-tts` missing used to answer
  `pipx install edge-tts`, and on a clean Ubuntu that is a command-not-found: pipx is not
  there, and `pip install` is refused outright (PEP 668,
  `externally-managed-environment`), so pipx is the first step rather than the
  alternative. When pipx is missing too, the check now prints the bootstrap for the
  platform and says plainly that the `sudo` needs a human at a terminal — which is exactly
  where the reported run stalled, an agent with no way to type a password.

### Documented

- **Decide where the walkthrough runs, with the user, before writing any of it.** The
  capture run is the app really doing the thing: if the happy path calls an LLM, sends a
  message or takes a payment, filming it does too, once per language, on every
  regeneration — and external state nobody controls breaks the run for reasons that are
  not the product. The skill assumed a test environment already existed; on a project
  running against real containers this was the most expensive decision of the session, and
  it is now step 2 of *Creating a new flow*.
- **A login through an external provider is not a form.** Google Identity Services, Auth0,
  SSO: do not automate the provider, inject an already-authenticated session the way the
  project's own integration tests do.
- **A `highlight:` can match and still be gone by the shot.** The recipes mark the element
  itself, and a framework remounting the node between `highlightOn` and the screenshot
  takes the mark with it — `count()` passed, the test passed, the PNG has no box on it.
  A third silent failure alongside the two already documented; gotchas now carries the
  mitigation, a box appended to `document.body` outside the app's tree, and the check that
  it also lines up under `fullPage`.

[#9]: https://github.com/kleer-la/claude-plugins/issues/9

## 0.2.1

The first report from someone outside the team who installed it cold ([#8]). The engine
and the recipe did exactly what they document — both findings are about what you have to
know *before* writing the first capture, which is the part only a stranger can test.

### Added

- `engine/check.sh` — the preflight, on its own. It already checked the five tools by
  running them, but only from inside `make_video.sh`, which requires `NARRATION`,
  `SCREENSHOTS` and `OUTPUT`: the check was unreachable at the one moment it was wanted,
  before there was a flow to run. `make_video.sh` now calls it, so there is one
  implementation. Step 1 of the skill is to run it.

### Documented

- **`@playwright/test` is not `playwright`.** A project can have the library without the
  test runner, and then `npx playwright test` starts anyway — the binary exists — and
  fails naming `playwright.config.ts` rather than the missing package. The recipe README
  says how to check, and stack detection no longer treats a `playwright.config.*` as
  proof the runner is installed.
- **Installing from the desktop app.** Its plugin browser installs from marketplaces that
  are already configured; adding one is a CLI command, which reads as "the plugin does not
  work here". The README now carries the `extraKnownMarketplaces` + `enabledPlugins` route,
  which needs no terminal at all, and names the two things that look like a failure and are
  not: the Code tab is where plugins live, and Linux desktop is a beta.
- The `command -v` loops in the README and in gotchas are gone. They were the weaker check
  that finding #4 of the macOS round taught us not to trust, and the first external tester
  wrote his own copy of one rather than finding `check.sh` — because there was none.

[#8]: https://github.com/kleer-la/claude-plugins/issues/8

## 0.2.0

Five projects in, across two stacks and two operating systems. Everything here was paid
for by a real migration; nothing was found by reading the code.

### Added

- `engine/devcontainer.sh` — resolves a Compose service to the container actually running
  it, by `working_dir` rather than by a name Compose does not keep stable.
- `run.sh` exports `RUN_VIDEO_TESTS`, `E2E_VIDEO_DOC_ENGINE` and `SCREENSHOTS` to the
  capture step, so it can call the engine's helpers and add frames of its own — a title
  card, a rasterised PDF.
- `make_videos.ps1 -CaptureOnly`, without which the documented workflow (capture, look at
  the PNGs, *then* narrate) was impossible on Windows.
- `scroll: "text:<substring>"` in both recipes, for screens where nothing has a stable
  selector.
- `dismiss_banner` in the Rails recipe. The gotchas told projects to clean the screen with
  it and only the Playwright recipe had it.
- `.gitattributes` pinning `*.sh` to `eol=lf`.

### Fixed

- **`highlight:` and `scroll: css:/text:` never worked in the Rails recipe.** They used
  `page.execute_script`'s argument convention on Capybara's `Element#execute_script`,
  which applies the script with the element as `this`. Three projects missed it because
  they only ever asked for `scroll: :bottom`.
- **`apiPanel` cut off cards taller than the frame, silently.** The last line is where
  `pickFields` puts `"… N more fields"`, so the marker saying fields were hidden was the
  first thing lost and the truncated card looked complete.
- `apiPanel` rendered `404` as a bare `404 ` — a scope-checked API returns it constantly.
- A Windows clone gets CRLF line endings and WSL bash then dies on the engine's own
  shebang. `.gitattributes` fixes fresh clones; `make_videos.ps1` strips CR in transit for
  clones that already exist.
- `run.sh` checks for `jq` before reading the config, instead of failing with a bare
  `command not found`.

### Documented

Each of these cost a real run: the container name is not stable · the skip guard belongs
in `setup`, because a guard in the test body still lets `rm -rf` delete the last run's
screenshots · `screen_size` sizes the window, not the shot (browser chrome eats ~143px) ·
`cmd /c` does not expand `$VAR` · a throttled API answers 429 while you film it · a
`highlight:` that matches the *wrong* element passes silently, as does a `scroll:` on a
page that already fits · `focus:` suits tall regions, `highlight:` suits wide ones.

## 0.1.0

First release: engine, contract, Rails and Playwright recipes, multi-language flows.
