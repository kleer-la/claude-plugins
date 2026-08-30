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

## Windows

The host has none of the three, but WSL Ubuntu does. **The engine does not need a
rewrite**: `make_videos.ps1` captures on Windows and crosses into WSL to assemble.

Two things in there that you will not work out from first principles:

- **Do not use `wsl wslpath`.** Going through PowerShell, `wsl.exe` eats the backslashes
  and the argument arrives as `C:UsersDev...`. It fails without saying why. The
  conversion is done locally, in `Convert-ToWslPath`.
- **`.Replace` and not `-replace`** for the slashes: the latter is regex, and a lone
  backslash does not compile.
- `npm.ps1` is sometimes blocked by ExecutionPolicy: use `cmd /c npm ...`. For the
  plugin's own `.ps1` there is `make_videos.cmd`, which calls it with
  `-ExecutionPolicy Bypass`.

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

## Frame before you crop

At full size a single cell cannot be found on its own: either you frame it
(`highlight:`) or you crop the image around it (`focus:`). Without one of the two, the
narration points at something the viewer cannot locate.

**A `highlight:` that does not match must fail loudly.** It is narration pointing at
something no longer on the screen — exactly the change the video exists to catch.

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
