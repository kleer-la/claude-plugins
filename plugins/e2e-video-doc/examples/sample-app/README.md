# Sample app

The smallest application worth filming: a catalogue, a cart, a form, and one API call.

**What it produces:** [English](https://youtu.be/h2U_B-G8fZg) · [Español](https://youtu.be/M0JQVx_tBEg)

It exists for three reasons — it is the ten-minute way to see the plugin work without
owning a suitable project, it is the regression fixture for the Playwright recipe, and the
video it produces is the one we can show people.

It carries two flows. `checkout` is a screen walkthrough with one API call in the middle.
`api` is the other shape entirely: a call is the whole story, and the screen only proves
the effect. If your own project's video is mostly API — a webhook, a batch job, an
integration with no UI of its own — read `api` first.

## Run it

**Node 18 or newer** — `node -v`. An older one fails while building a native dependency
and reports a `node-gyp` error that says nothing about the real problem.

```bash
npm install
npx playwright install chromium     # once, if you have never used Playwright here
bash <plugin>/engine/run.sh checkout        # English
bash <plugin>/engine/run.sh checkout es     # Spanish
bash <plugin>/engine/run.sh api             # the API-only flow, English
bash <plugin>/engine/run.sh api es          # the API-only flow, Spanish
```

`<plugin>` is the installed marketplace copy of `skills/e2e-video-doc` (two levels up from here).
`checkout` lands in `videos/checkout_en.mp4` / `checkout_es.mp4` — about a minute, six
frames. `api` lands in `videos/api_en.mp4` / `api_es.mp4` — about forty seconds, five
frames, four of them cards.

The engine needs `edge-tts`, `ffmpeg`, `ffprobe`, `jq` and `python3`. To find out whether
this machine has them, and what to run if it does not:

```bash
bash <plugin>/engine/check.sh
```

To see just the screenshots, without narrating anything:

```bash
npx playwright test
```

## What is where

| | |
|---|---|
| `server.mjs` | Node's http module and nothing else. No database, no framework, no build. |
| `public/` | The app: catalogue, cart, confirmation, and a small order-lookup panel. |
| `tests/checkout.video.spec.ts` | The screen walkthrough. This is a real end-to-end test. |
| `tests/api.video.spec.ts` | The API-only flow — see [`api`](#api-the-call-is-the-whole-story) below. |
| `scripts/checkout_video_narration.json` | One entry per capture, in order. |
| `scripts/api_video_narration.json` | Same, for `api`. |
| `e2e-video-doc.json` | The only file you write per project. |

## One difference from your project

Your project **copies** `capture.ts` and `apiPanel.ts` out of the recipe, so they age with
your code. This sample **imports them from the recipe directly**, so that a change which
breaks either one fails here first. That is the point of it being in this repo — every bug
found in those two files so far was found in somebody's private repository.

## Two languages, and why the interface changes too

`e2e-video-doc.json` declares `en` and `es`. Asking for Spanish does not swap the audio
track over English screenshots — **it captures again**, with the application rendering in
Spanish, because a screen in one language under a voice in another reads as a mistake
rather than as a translation. Compare `tmp/video_screenshots/checkout_en` with
`checkout_es`: the catalogue, the buttons, the number formatting and the order status are
all different.

The language reaches the walkthrough as a Playwright **project** (`--project={lang}`)
rather than an environment-variable prefix, because the capture command runs through
`cmd /c` on Windows, where `VAR=value command` is not a thing.

## What the walkthrough exercises

- `highlight` — the red box, on a table row and then on the order total
- `capture` — six numbered PNGs at 1280x720, which is 16:9, so the engine pads nothing
- `apiPanel` — the POST drawn as a card, with `pickFields` keeping three keys and saying
  how many it left out
- A real `201`, and a `400` the server will return if you want to film a rejection
- `languages` in the config — one capture run per language, which nothing else in this
  repository demonstrates

## `api`: the call is the whole story

`checkout` uses `apiPanel` once, as a detour in the middle of a screen walkthrough. `api`
is what a walkthrough looks like when the API *is* the walkthrough: a wholesale partner
that never opens the storefront, trading a password for a token and creating orders
through `POST /api/partner/orders` instead of through the "Place order" button.
`/api/orders` — what `checkout` calls — stays open on purpose: it is what the button
itself calls, and gating it would break that walkthrough along with it.

| Frame | What it demonstrates |
|---|---|
| `01_token_emitido` | `postJson`, and the password masked by hand — `trimValue` is for showing a value's start, not for hiding all of it. |
| `02_pedido_sin_token` | `expect: "reject"` — the negative case, drawn red, filmed *before* the successful call so the contrast carries the point. |
| `03_pedido_autorizado` | `headers` + `trimValue` on the credential, and `pickFields` on the response. |
| `04_registro_de_acceso` | `showCard` — what is not an HTTP call: the server's own access-log row, fetched, not invented. |
| `05_pedido_en_pantalla` | API → screen → assertion. The order the API created is looked up on a real screen, and `expect(...).toHaveText(...)` checks it — not just `capture`. |

Every value on every card came from a real response: `postJson`'s status and body, or a
`GET /api/access-log` read straight from the server. Rule one of writing a card is that an
invented value makes it a slide, not a test.

## If you are evaluating the plugin

Read `tests/checkout.video.spec.ts` first. It is about sixty lines, and it is the whole
idea: a walkthrough written in the project's own stack, that photographs itself as it goes.
If what you need to document is mostly API, read `tests/api.video.spec.ts` next — it is
the same idea with almost nothing to look at on screen.
