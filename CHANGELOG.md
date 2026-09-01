# Changelog

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
