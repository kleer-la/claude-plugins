# Sample app

The smallest application worth filming: a catalogue, a cart, a form, and one API call.

It exists for three reasons — it is the ten-minute way to see the plugin work without
owning a suitable project, it is the regression fixture for the Playwright recipe, and the
video it produces is the one we can show people.

## Run it

**Node 18 or newer.** Check first — an older one fails while building a native dependency
and reports a `node-gyp` error that says nothing about the real problem:

```bash
node -v
```

If it is older (or `npx` is missing, which means Node is older than 8): `brew install node`,
or use nvm.

```bash
npm install
npx playwright install chromium     # once, if you have never used Playwright here
bash <plugin>/engine/run.sh checkout
```

`<plugin>` is the installed marketplace copy of `plugins/e2e-video-doc/skills/e2e-video-doc`.
The result lands in `videos/checkout.mp4` — about a minute, six frames, Spanish narration.

The engine needs `edge-tts`, `ffmpeg`, `ffprobe`, `jq` and `python3`:

```bash
for c in edge-tts ffmpeg ffprobe jq python3; do printf "%-10s %s\n" "$c" "$(command -v $c || echo MISSING)"; done
```

```bash
brew install ffmpeg jq        # macOS
sudo apt install ffmpeg jq    # Debian/Ubuntu
pip install edge-tts          # both
```

To see just the screenshots, without narrating anything:

```bash
npx playwright test
```

## What is where

| | |
|---|---|
| `server.mjs` | Node's http module and nothing else. No database, no framework, no build. |
| `public/` | The app: catalogue, cart, confirmation. |
| `tests/checkout.video.spec.ts` | The walkthrough. This is a real end-to-end test. |
| `scripts/checkout_video_narration.json` | One entry per capture, in order. |
| `e2e-video-doc.json` | The only file you write per project. |

## One difference from your project

Your project **copies** `capture.ts` and `apiPanel.ts` out of the recipe, so they age with
your code. This sample **imports them from the recipe directly**, so that a change which
breaks either one fails here first. That is the point of it being in this repo — every bug
found in those two files so far was found in somebody's private repository.

## What the walkthrough exercises

- `highlight` — the red box, on a table row and then on the order total
- `capture` — six numbered PNGs at 1280x720, which is 16:9, so the engine pads nothing
- `apiPanel` — the POST drawn as a card, with `pickFields` keeping three keys and saying
  how many it left out
- A real `201`, and a `400` the server will return if you want to film a rejection

## If you are evaluating the plugin

Read `tests/checkout.video.spec.ts` first. It is about sixty lines, and it is the whole
idea: a walkthrough written in the project's own stack, that photographs itself as it goes.
