---
name: e2e-video-doc
description: Walks the application like a real user and produces a narrated video, screenshots and the detail of each API call. Use it when asked for a video of a feature, a narrated walkthrough, release notes or a user guide that regenerates itself, or to document an end-to-end flow. The walkthrough is an E2E test - when it breaks, the screen changed.
---

# e2e-video-doc

A script walks the app doing what a person would do — sign in, enter data, navigate — and
takes numbered screenshots along the way. A JSON gives them narration, and the engine
turns them into a 3-4 minute MP4 with a synthetic voice.

What comes out is not just a video: it is documentation that **fails when the product
changes**, because the walkthrough is a real E2E test.

## The cut line

```
capture  →  NN_name.png  +  [{screenshot, duration, narration}]  →  engine
(per project)          THE CONTRACT                              (from the plugin)
```

**Above the line the plugin is stack-agnostic. Below it, everything is done.** The engine
is bash + ffmpeg + edge-tts and does not care whether the PNG came from Capybara,
Playwright, or a rasterised PDF.

The walkthrough is written per project, in the stack it already has, with its factories
and its login helper — because it has to age with the project. That is the feature.

## Before doing anything

1. **Run `bash engine/check.sh`.** Five tools, checked by running them rather than
   locating them. Do it now, not when the narration is written: it is the only failure
   here that needs a human to install something, and it costs nothing to hit early. In a
   devcontainer, run it in the container that will assemble.
2. **Read [reference/gotchas.md](reference/gotchas.md).** It is short and every item was
   paid for once. Especially: where the MP4 ends up, and where the tools are installed on
   *this* machine.
3. **Detect the stack** — do not ask what you can look up:
   - `test/system/` with Capybara → [recipes/rails-capybara](recipes/rails-capybara/)
   - `playwright.config.*` → [recipes/playwright-node](recipes/playwright-node/).
     Confirm the project has **`@playwright/test`**, not just `playwright`: they are
     different packages, and the recipe needs the test runner.
   - Anything else: use the Playwright recipe as the reference for what features the
     capture helper needs, and write it in the project's stack.
4. **Is there an `e2e-video-doc.json` at the root?** If not, create it — see
   [reference/config.md](reference/config.md).

## Generating a video for an existing flow

```bash
bash engine/run.sh <flow>                   # capture and assemble
bash engine/run.sh <flow> --assemble-only   # assemble from the screenshots already there
VOICE=es-CO-SalomeNeural bash engine/run.sh <flow>
```

On Windows: `engine\make_videos.cmd <flow>` (captures on the host, assembles in WSL).

Report at the end: file path, duration, size, and **how many screenshots were missing** if
any were.

## Creating a new flow

1. **Ask what the walkthrough has to show** — do not guess. What the user achieves, where
   it starts, where it ends.
2. **Decide with the user where it will run.** Does the happy path spend money or leave
   the building — an LLM call, a message, a payment — or depend on external state nobody
   controls, like a live third-party session? Then filming it does too, once per language,
   on every regeneration. Use the doubles the project already has for its own tests, on an
   ephemeral database and its own port. This is not a technical question and it is not
   yours to settle alone; taken late, it was the most expensive hour of a real session.
3. **Write the walkthrough** in the project's stack, copying the capture helper from the
   matching recipe. Use the factories and helpers the project already has; do not seed
   data by hand if there is a seed.
4. **Run only the capture** and look at the PNGs before narrating. Fixing the walkthrough
   here is far cheaper than after the audio exists. Two failures pass the test and only
   show up in the image: a `highlight:` that framed the *first* match rather than the
   right one, and a `scroll:` that did nothing because the page already fitted. Both stop
   being silent if you name the subject: `assert_in_frame:` / `assertInFrame` refuses to
   photograph a screen where the thing the narration points at is out of frame or covered.
   On Windows: `engine\make_videos.cmd <flow> -CaptureOnly`.
5. **Write the narration JSON** — see [reference/narration.md](reference/narration.md).
   One entry per capture, in order.
6. **Add the flow** to `e2e-video-doc.json`.
7. **Generate the video and watch it.**

## When the walkthrough breaks

**Ask first whether the thing that is wrong is the product.** This generator exists partly
for that: missing pagination, broken ordering, an error the user never sees. If you find a
bug, say so before patching the script to step around it.

## What is here

| | |
|---|---|
| `engine/check.sh` | Preflight: are the five tools here and do they run? Needs nothing set up; run it first. |
| `engine/make_video.sh` | The engine. Screenshots + narration → MP4. Driven entirely by the environment. |
| `engine/run.sh` | Runs one flow from `e2e-video-doc.json`. |
| `engine/devcontainer.sh` | Resolves a Compose service to the container actually running it. Container names drift; this does not. |
| `engine/make_videos.ps1` `.cmd` | Windows: capture on the host, assemble in WSL. |
| `engine/generate_title_cards.sh` | Opening and closing title cards. |
| `recipes/playwright-node/` | `capture.ts` (highlight, focus, scroll) and `apiPanel.ts`. |
| `recipes/rails-capybara/` | `video_recording.rb`, same contract. |
| `reference/` | [config](reference/config.md) · [narration](reference/narration.md) · [voices](reference/voices.md) · [gotchas](reference/gotchas.md) |
