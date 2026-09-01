# What already cost us

Every item here was paid for once, on a real project. They are written down so nobody
pays for them twice.

## The video cannot live in `tmp/`

Every capture test starts with `rm -rf` on its own directory. If the MP4 ends up there,
the next run deletes it — or any full system-test run does. The config's `output` goes to
`public/videos/` or the equivalent.

## The tools are not where you think

`edge-tts`, `ffmpeg` and `jq` may be on the host, in the devcontainer, in neither, or in a
different one per machine. **Detect, do not assume.**

```bash
for c in edge-tts ffmpeg ffprobe jq; do printf "%-10s %s\n" "$c" "$(command -v $c || echo MISSING)"; done
docker exec <container> bash -lc 'for c in edge-tts ffmpeg ffprobe jq; do printf "%-10s %s\n" "$c" "$(command -v $c || echo MISSING)"; done'
```

Run the engine wherever all four are present. If they are nowhere, say which tool is
missing where instead of installing system packages on your own.

## The container name is not stable

Compose derives it from the project name, which is the directory it was started from:
`.devcontainer/` for "Reopen in Container", the repo directory for a manual
`docker compose up`. Projects opened the same way collide — on one machine two unrelated
repos both came up under the project `devcontainer`, and the container was called
`devcontainer-web-1`, with nothing in the name to say which repo it served.

A name hardcoded in `e2e-video-doc.json` goes stale in silence, and the capture step then
fails with a docker error that says nothing about video. `engine/devcontainer.sh` resolves
the service to a running container by **`working_dir`** — the path on disk identifies the
repo, the project name does not:

```json
"capture": "docker exec \"$(bash \"$E2E_VIDEO_DOC_ENGINE/devcontainer.sh\" web)\" bin/rails test ..."
```

## Windows

The host has none of the three, but WSL Ubuntu does. **The engine does not need a
rewrite**: `make_videos.ps1` captures on Windows and crosses into WSL to assemble.

**A clone on Windows has CRLF line endings**, because `core.autocrlf=true` is the
default there. Bash then fails on the engine's own shebang with `\r: command not found`,
which names neither the file nor the cause. The repo's `.gitattributes` pins `*.sh` to
`eol=lf`, and `make_videos.ps1` pipes the script through `tr -d '\r'` on the way into WSL
so clones that already exist keep working.

**`.gitattributes` only reaches a fresh clone.** Git will not rewrite a working-tree file
whose blob did not change, so `/plugin marketplace update` leaves an existing clone's
`.sh` files CRLF — confirmed on a real machine. Re-add the marketplace, or in the clone:
`git rm --cached -r . && git reset --hard`. A capture command that calls a plugin script
directly — `devcontainer.sh`, say — has nothing rescuing it, so it needs the
`.gitattributes` to have been in place when the marketplace was cloned.

**`cmd /c` does not expand `$VAR`.** The capture command runs through `cmd` on Windows,
where the syntax is `%VAR%`. The variables themselves arrive intact — a capture *script*
that reads `process.env.SCREENSHOTS` or `$env:SCREENSHOTS` works fine — but a capture
*string* written as `"$(bash "$E2E_VIDEO_DOC_ENGINE/devcontainer.sh" web)"` is bash
syntax and reaches the process as a literal. Config examples that interpolate inline are
Linux and macOS only; on Windows, put the work in a script and let it read the
environment itself.

Two more things in there that you will not work out from first principles:

- **Do not use `wsl wslpath`.** Going through PowerShell, `wsl.exe` eats the backslashes
  and the argument arrives as `C:UsersDev...`. It fails without saying why. The
  conversion is done locally, in `Convert-ToWslPath`.
- **`.Replace` and not `-replace`** for the slashes: the latter is regex, and a lone
  backslash does not compile.
- `npm.ps1` is sometimes blocked by ExecutionPolicy: use `cmd /c npm ...`. For the
  plugin's own `.ps1` there is `make_videos.cmd`, which calls it with
  `-ExecutionPolicy Bypass`.

## The skip guard goes in `setup`, not in the test body

`setup_video_recording` starts with `rm -rf` on the screenshot directory. A guard placed
in the test body runs *after* setup, so an ordinary `bin/rails test:system` skips the
video test and **deletes the screenshots of the last real run on its way past** — and the
next `--assemble-only` then has nothing to work with. Put it first in `setup`:

```ruby
setup do
  skip "only with RUN_VIDEO_TESTS=1" unless ENV["RUN_VIDEO_TESTS"]
  ...
  setup_video_recording
end
```

## The screen size is the window, not the shot

The engine pads to 1920x1080 with `force_original_aspect_ratio=decrease`, so a capture
that is not 16:9 lands inside white bands. Selenium's `screen_size` sets the **window**,
and the browser chrome eats ~143px of it: `[1280, 720]` yields a 1280x577 shot and a
letterboxed video. Ask for the height you want plus the chrome (`[1280, 863]` for a
1280x720 frame), then check the PNG rather than trusting the number you asked for.

## The interface has to speak the same language as the voice

A screen in one language with a voice-over in another reads as a mistake, not as a
translation. So a multi-language build is not "assemble the same screenshots with a
different audio track" — **each language re-captures**, with the app's locale set for the
run.

That is why `capture` accepts `{lang}`: pass it through to whatever your app reads
(`VIDEO_LOCALE`, `LANG`, a query parameter) and let the walkthrough render in that
language before the shot.

The cost is real — N languages means N capture runs — and it is worth paying. The
alternative looks broken.

## One flow per run

Running several video specs at once takes twice as long *and* makes them fight over
shared state: config flags each one turns on and off, seeded data, sessions. The
orchestrator runs **only** the spec for the requested flow.

## What is not a screenshot

A generated PDF does not photograph well in headless Chrome — the viewer does not render
reliably. Generate the real PDF and rasterise it separately (`pdftoppm`), on whichever
side that tool exists, and drop the PNG into the directory as one more capture.

Same problem, same answer: **any frame the browser cannot take is generated separately and
enters as a numbered PNG.** The engine cannot tell the difference.

## An API call has nothing to photograph

If the video only shows the result on screen, the viewer has to take on faith that the API
did anything. `apiPanel.ts` draws the call as a card — what was sent, what came back, what
to look at — and photographs it with the same `capture`, so it lands in the same MP4
without touching the narration pipeline.

The trimming is deliberate: a body of forty fields is forty fields nobody can read on
screen. `pickFields` keeps the keys the narration is pointing at and says how many were
left out. `trimValue` shows the start of the credential, not the credential.

## A throttled API answers 429 while you are filming it

An API that allows one request per window per scope will start refusing as soon as the
walkthrough runs at machine speed, and `apiPanel` faithfully documents an error that is
not part of the story. Pace the calls — roughly 1.3s between them was enough on a v4 API
that allows one per second — and remember the walkthrough re-runs per language, so the
pacing cost is paid N times.

## Frame before you crop

At full size a single cell cannot be found on its own: either you frame it
(`highlight:`) or you crop the image around it (`focus:`). Without one of the two, the
narration points at something the viewer cannot locate.

**A `highlight:` that does not match must fail loudly.** It is narration pointing at
something no longer on the screen — exactly the change the video exists to catch.

**But a `highlight:` that matches the wrong thing passes silently.** It frames the first
match, and a test that passes proves only that something matched. On a real run the box
landed on the wrong row, because inbound and outbound records were numbered in separate
sequences and both were "81". Only the PNG showed it. Make the selector identify one
element, and check the frame.

**A `scroll:` on a page that already fits is a no-op**, and returns a perfectly valid
photograph of the top of the page. Nothing fails. If the narration says "further down",
assert that `window.scrollY` actually moved.

These two are why step 3 exists — *run only the capture and look at the PNGs* — and they
are the two it catches that nothing else does.

**`focus:` suits tall regions, `highlight:` suits wide ones.** Cropping a wide, short
element — a table row — yields something like 1280x174, which the engine then pads into
1920x1080 with enormous bands above and below.

## Borrow fixture data, and give it back

When the walkthrough needs to touch shared data (a known password, a config flag, an
enabled feature), borrow it at the start and return it in `afterAll` / `teardown`, so it
comes back even when the test fails.

**The borrow must be idempotent.** If a run is cut short before returning, the next borrow
has to **return first**. Without that, the second borrow takes the already-borrowed value
as if it were the original and leaves it stuck — it happened: a counter that should have
gone back to its original value kept climbing instead.

## Clean the screen before the shot

Things that dirty the video and are not the product: a component library's trial strip,
development-environment banners, debug bars. Close them in the capture helper, not in each
test — that is what `dismissBanner` is for.

In a Rails test environment CSRF is disabled and `csrf_meta_tags` renders nothing, yet
some flows still expect the tag to be present. Inject a dummy one after navigating
(`inject_csrf_meta`).

## The bugs that show up on their own

Forcing the full walkthrough finds things no unit test looks at: missing pagination,
broken ordering in lists, errors the user never sees.

A real example: a button answered *"the following records could not be received"* without
saying why. Temporarily removing an empty `catch` surfaced the real message — a precise,
actionable error from the service underneath. The empty `catch` was a defect in its own
right: it discarded that message and replaced it with a useless one.

When the generator breaks, **ask first whether the thing that is wrong is the product.**
