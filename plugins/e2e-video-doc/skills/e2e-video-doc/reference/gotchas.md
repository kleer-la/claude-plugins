# What already cost us

Every item here was paid for once, on a real project. They are written down so nobody
pays for them twice.

## The walkthrough really does what it shows

A capture run is the app doing the thing, not a picture of it. If the happy path spends
money or leaves the building — a call to an LLM, a WhatsApp or an email, a payment, a
webhook — then filming it spends money and leaves the building too, once per language,
every time the video is regenerated. And if it leans on external state nobody controls —
a real WhatsApp session, a third-party sandbox that resets — the walkthrough will break
for reasons that have nothing to do with the product it exists to watch.

**Decide where the run happens before writing a line of capture, and decide it with the
user.** A project with those effects usually already owns the doubles for them — a fake
provider, a fake LLM, a sandbox key — because its own tests needed them; use those, with
an ephemeral database and the app on a port of its own, and check nothing real moved
(`docker ps` before and after). On a project running in "local production" mode this was
the most expensive decision of the whole session, more than any technical problem, and it
was expensive because it was taken late.

Reaching for a real session token to go faster is not the shortcut it looks like: Claude
Code's permission classifier blocks automated use of live credentials against a live API,
even one the user signed by hand.

## A login through an external provider is not a form

Google Identity Services, Auth0, a corporate SSO: there is nothing on the page to fill in,
and driving the provider from headless Chrome is fragile where it is not refused outright.
Do not automate it. **Inject an already-authenticated session the way the project's own
integration tests do it** — the JWT into `localStorage`, the signed cookie, the test-only
sign-in helper. Where that precedent exists the login step costs minutes; where it does
not, writing it is the first task, and it is worth having regardless of the video.

## The video cannot live in `tmp/`

Every capture test starts with `rm -rf` on its own directory. If the MP4 ends up there,
the next run deletes it — or any full system-test run does. The config's `output` goes to
`public/videos/` or the equivalent.

## The tools are not where you think

`edge-tts`, `ffmpeg` and `jq` may be on the host, in the devcontainer, in neither, or in a
different one per machine. **Detect, do not assume.**

```bash
bash engine/check.sh
docker exec <container> bash /path/to/engine/check.sh
```

Run the engine wherever all five pass. If they pass nowhere, say which tool is missing
where instead of installing system packages on your own.

`check.sh` exists precisely so this can be answered before any work is done. It used to be
reachable only through `make_video.sh`, which needs a narration, a screenshots directory
and an output path — so the check arrived an hour after the moment it was useful.

**On PATH is not the same as working.** `edge-tts` is a Python entry point, and a Homebrew
Python upgrade leaves it behind with a shebang naming an interpreter that no longer exists
— `command -v` finds the file, running it says `bad interpreter`. Found on a Mac whose
`edge-tts` pointed at a python3.7 that had been gone for a while. `check.sh` therefore
*runs* each tool rather than merely locating it, and a hand-written `command -v` loop is
the check we already know is not enough. `pipx install edge-tts` puts it in its own
virtualenv and survives the next Python upgrade; `pip install` does not — and on recent
Debian and Ubuntu it is refused outright (PEP 668, `externally-managed-environment`), so
pipx is the first step rather than the alternative. Installing pipx itself is a `sudo apt`
away, which needs a human at a terminal; `check.sh` says exactly that when pipx is missing
too, instead of printing a command that cannot run.

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

**The copy you are reading may be older than the plugin.** `/plugin marketplace update`
does not always leave the installed clone matching what is on GitHub, and the skill files
give no sign of it: a project ported a fix from the repository while its own installed
`capture.ts` still had the old mechanism in it, so an agent following the local skill
would have rebuilt the bug it had just removed. Check before trusting a local copy —
`.claude-plugin/plugin.json` carries the version, and `CHANGELOG.md` says what that
version should contain. Re-adding the marketplace is the blunt fix.

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

**A `highlight:` that matched could once still be gone by the time of the shot.** Both
recipes used to mark the element itself — an attribute, plus a CSS rule for it — and a
framework throws that mark away when it re-renders the node. Turbo replaces it with the
server's HTML, React with the render output; neither ever carried the attribute. The loss
was silent: the selector matched, `count()` passed, the test passed, and only the
photograph had no box on it.

Measured on a real Rails app and on the sample: **3411 red pixels before the re-render,
0 after, with a green test both times.** The recipes now draw the box as their own element
appended to `document.body`, outside whatever the app re-renders, and the same probe scores
the same number before and after. Two consequences worth knowing:

- The box is a photograph of one instant — it is positioned from the element's rect and
  does not follow it afterwards. `capture` therefore draws it *after* scrolling, which is
  the order it already used.
- **It is placed in document coordinates, not viewport ones.** A `position: fixed` box is
  placed against the window, and a full-page screenshot is not a window — it is a tall
  image the browser stitches, and where a fixed box lands in it is a browser-version
  question. Measured at the element's place in the document on one Playwright; reported
  pinned near the top of the image, framing nothing, on an older one. `position: absolute`
  plus `scrollX`/`scrollY` asks the question the picture actually answers — where is this
  element on the page — and takes the version out of it.
- Two details that go with that. `absolute` resolves against the nearest positioned
  ancestor, and a body with `position: relative` is not the document origin: draw the box,
  measure where it landed, shift it by the difference rather than assuming. And **clamp it
  inside the document** — a ring drawn 5px past the right edge is 5px of new scrollable
  area, so the page gains a horizontal scrollbar, a full-page image comes out wider, and
  every frame after it is composed differently. Read `scrollWidth`/`scrollHeight` before
  appending anything.
- Staging this failure with `cloneNode(true)` proves nothing: a clone copies attributes, so
  the old mark rides along and everything looks fine. The faithful stand-in is putting the
  server's own markup back over the node (`this.outerHTML = <captured html>`).

**A `scroll:` on a page that already fits is a no-op**, and returns a perfectly valid
photograph of the top of the page. Nothing fails. If the narration says "further down",
assert that `window.scrollY` actually moved.

These are why step 3 exists — *run only the capture and look at the PNGs* — and they are
what it catches that nothing else does: each of them leaves a green test and a wrong
image.

**`focus:` suits tall regions, `highlight:` suits wide ones.** Cropping a wide, short
element — a table row — yields something like 1280x174, which the engine then pads into
1920x1080 with enormous bands above and below.

**In the Rails recipe the two do not combine.** Selenium photographs the element at its
exact rect and the ring is drawn just outside it, so a capture asking for both comes back
cropped with no box on it — measured, and equally true of the outline that preceded the
overlay. Playwright's `focusPad` crop keeps the box, because it clips the viewport rather
than the element. Pick one per capture on Rails.

## The page is still moving when the shutter opens

**Scrolling animates, and the capture does not wait for it.** Bootstrap 5 ships
`@media (prefers-reduced-motion: no-preference) { :root { scroll-behavior: smooth } }`,
and headless Chrome reports no-preference — so on a Bootstrap app *every* scroll is an
animation, and whether the shot catches the page mid-flight is a race against `pause`.
Measured on the sample: a plain `scrollIntoView({block: "center"})` read `scrollY` 0
immediately and 190 six-tenths of a second later.

The two recipes were not equally exposed, which is not something you would work out from
first principles:

- **Capybara/Selenium went through the page's own JS and animated.** The recipe now asks
  for `behavior: "instant"`. Without it, and with `pause: 0`, the framing check below
  fails — that is how the fix was verified.
- **Playwright's `scrollIntoViewIfNeeded` is instant** regardless of the CSS: measured at
  190 immediately and 190 later, on the same page. Nothing to fix there.

**Turbo restores the scroll position asynchronously after a navigation**, so a scroll
applied a moment too early is quietly undone and the photograph is of the top of the page.
Paid for on a real project, which bought a blind `sleep 0.4` before every scroll. The
recipes take the cheaper route: check that the subject is where it should be, and scroll
again if it is not.

**A pinned navbar hides the subject and nothing notices.** `scrollIntoViewIfNeeded` and
`align: :top` both consider an element parked under a fixed bar to be in view, so the
element is technically on screen and visually gone. Centring is the fix, and it is what
both recipes do on the retry.

## Say what the picture has to contain

`assert_in_frame:` (Rails) and `assertInFrame` (Playwright) refuse to take a picture in
which the subject is not whole in the viewport, or is covered by something. They ask the
document what is actually painted at the middle of the element — `elementFromPoint` — so a
cookie wall, a modal, or a sticky header is caught, not just a bad rectangle. The check
runs twice: once before the box is drawn, where a failure buys one more centred scroll,
and once immediately before the shutter, where it raises, because that is the moment the
camera sees.

Use it on the element the narration is pointing at. It is the difference between a
walkthrough that fails when the screen changes and one that quietly photographs the wrong
part of the page.

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
