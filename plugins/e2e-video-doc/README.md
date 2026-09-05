# e2e-video-doc

A script walks your app doing what a person would do — sign in, enter data, navigate —
taking numbered screenshots along the way. A JSON gives them narration, and the engine
turns them into a narrated MP4 with a synthetic voice.

What comes out is not just a video: it is documentation that **fails when the product
changes**, because the walkthrough is a real end-to-end test.

## See it

[![Watch the demo](https://img.youtube.com/vi/h2U_B-G8fZg/hqdefault.jpg)](https://youtu.be/h2U_B-G8fZg)

One minute, generated from [`examples/sample-app`](examples/sample-app/) by the
plugin itself — [English](https://youtu.be/h2U_B-G8fZg) ·
[Español](https://youtu.be/M0JQVx_tBEg).

The two are not one recording dubbed twice. Each language captures again, so the
interface changes along with the voice: catalogue, buttons, number formatting, order
status. A screen in one language under a voice in another reads as a mistake rather than
as a translation, and that rule is the reason multi-language costs a capture run per
language.

## What you get

- **A 3-4 minute narrated MP4** per flow, in any of edge-tts's voices.
- **A walkthrough that fails loudly** when the product moves under it.
- **API calls made visible** — an HTTP call has nothing to photograph, so it gets drawn as
  a card and filmed alongside the real screens.

Useful for offline QA, asynchronous team review, explaining a feature to customers or
support, release notes and user guides that regenerate themselves, checking the result of
work delegated to an AI agent, and a permanent demo of a feature on the product site.

## Install

```
/plugin marketplace add kleer-la/claude-plugins
/plugin install e2e-video-doc@kleer-la
```

The marketplace README covers [installing without a
terminal](../../README.md#from-the-desktop-app), for the desktop app.

## How this differs from prompt-to-video plugins

`framecraft`, `demo-video` and `narrateai-demomaker` start from a description: you write a
prompt, or lay the scenes out one by one, and the model renders what you said. Nothing
compares the result against the product — the video is as true as the description was on
the day someone wrote it.

Here the video is a by-product of a test run. The walkthrough boots the app, signs in,
fills the forms and navigates; every frame is a screenshot of the real screen at that
moment.

| | Prompt / scene driven | e2e-video-doc |
|---|---|---|
| Where the frames come from | What you described | What the app actually rendered |
| Someone moves the button | The video still renders, now wrong | The walkthrough fails and the run stops |
| Regenerating | Prompt again, review it again | `run.sh` — no model involved |
| Needs a running app | No | Yes: the app, your fixtures, a login |
| Where it fits | A product that does not exist yet, marketing cuts, anything that is not a screen | A flow that already ships and has to stay documented |

The difference that matters is the failure mode, not the fidelity. A described video decays
in silence: nobody notices the screen moved until a customer follows the video and cannot
find the button. The same change here turns the walkthrough red, in CI, alongside the rest
of the suite — the documentation breaks loudly instead of lying quietly.

The price of that is real: this only works on a flow you can drive for real. When there is
no app to click yet, those plugins do things this one cannot.

## What it is built on

Five things, on whichever machine assembles the video: `ffmpeg` and `ffprobe` put the
frames and the audio together, `edge-tts` speaks the narration, `jq` reads the config,
`python3` does the arithmetic. Microsoft Edge's voices need no API key and no account.

**There are no install instructions here on purpose.** Ask Claude to run the plugin's
preflight, `engine/check.sh`: it reports which of the five are missing on *this* machine
and with which command, and an agent installs them better than a page can predict. The
preflight also checks them by **running** them rather than locating them, which is not the
same question — a `pip`-installed `edge-tts` whose Python was later upgraded is still
found by `command -v` and still cannot run.

On Windows the five live in WSL: the plugin captures on the host and crosses the bridge to
assemble. See the Windows section of
[gotchas](skills/e2e-video-doc/reference/gotchas.md).

## Getting started

Ask Claude for a video of a flow and the skill drives it. What it does, in order:

1. Detects your stack and copies the matching capture helper into your project —
   [Rails/Capybara](skills/e2e-video-doc/recipes/rails-capybara/) or
   [Playwright](skills/e2e-video-doc/recipes/playwright-node/).
2. Settles with you where the walkthrough will run, before writing anything — see the
   first bullet of [what it does not do](#what-it-does-not-do).
3. Writes the walkthrough with your factories, your login helper, your seeded data.
4. Runs the capture and **looks at the PNGs before narrating** — the step that catches the
   failures a green test does not.
5. Writes the narration, adds the flow to `e2e-video-doc.json`, assembles the MP4.

The one file you write per project is `e2e-video-doc.json` at the repo root. See
[config](skills/e2e-video-doc/reference/config.md).

## How it is split

```
capture  →  NN_name.png  +  [{screenshot, duration, narration}]  →  engine
(yours)                 THE CONTRACT                             (the plugin's)
```

The engine is stack-agnostic — it does not care whether the PNG came from Capybara,
Playwright, or a rasterised PDF. The walkthrough is yours, because it uses your factories
and has to age with your project.

## What it costs

The expensive part happens once. Regeneration is a bash script.

| | Time | Model tokens |
|---|---|---|
| Try it on the sample app | ~10 minutes | Essentially none — `npm install`, then one command |
| First flow in **your** app | An hour or two | Real. An agent has to learn your login, your fixtures, your screens |
| Every regeneration after that | Minutes | **None.** `run.sh` is bash, ffmpeg and edge-tts; no model is involved |
| Each extra language | One more capture run | **None** |

That last row is the whole economics of it. A video recorded by hand is worth what it cost
the day it was made and decays from there; this one costs its tokens once and then
regenerates from a script for as long as the walkthrough keeps passing.

If you are evaluating, start with [`examples/sample-app`](examples/sample-app/) — it
is the ten-minute version and needs no project of your own.

## Where it has actually run

Only the first column is a promise. The rest is what has been exercised on real projects,
and it is deliberately not a longer list.

| | Status |
|---|---|
| Rails + Capybara + Selenium | Four projects, including multi-language and devcontainers |
| Playwright + TypeScript | Three projects, including the API panel. One was installed cold by someone outside the team, on macOS, and produced a video without asking us anything; another got there too, but only after six questions — which app, which environment, whether to touch a real secret ([#9](https://github.com/kleer-la/claude-plugins/issues/9)) |
| Linux | Every run |
| Windows + WSL | One project, host capture and WSL assembly |
| macOS | The sample app, end to end. The engine needed no changes; six fixes went into prerequisites and error messages |
| Any other stack | The contract is `NN_name.png` + a narration JSON. The engine does not care what produced the PNGs — but no one has written a third recipe yet |

## What it does not do

- **It does not decide where the walkthrough may run, and it cannot.** If the happy path
  spends money or leaves the building — an LLM call, a message, a payment — or leans on
  external state nobody controls, that is settled with you before a line is written. Taken
  late, it was the most expensive hour of a real session
  ([#9](https://github.com/kleer-la/claude-plugins/issues/9)). A login behind an external
  identity provider is the same shape of problem: the walkthrough injects an authenticated
  session the way your integration tests do, instead of automating Google or Auth0.
- **The walkthrough has to live with the app to be worth it.** It can technically live in
  another repo, and then it breaks in a place nobody is looking — see
  [#4](https://github.com/kleer-la/claude-plugins/issues/4).
- **The framing check measures the element's box, not its text.** A caption wider than the
  viewport, or any block inside an `overflow-x: auto` wrapper, is refused even when every
  word of it is on screen ([#13](https://github.com/kleer-la/claude-plugins/issues/13)).
- **Frames pair to narration by number.** Inserting one renumbers every file after it and
  every `screenshot` key in the narration
  ([#13](https://github.com/kleer-la/claude-plugins/issues/13)).
- **No speech-rate setting** in the config yet, though the engine honours `RATE`
  ([#2](https://github.com/kleer-la/claude-plugins/issues/2)).
- **Title cards are generated, not supplied.** A project that wants its own opening image
  copies it in from the capture step ([#2](https://github.com/kleer-la/claude-plugins/issues/2)).
- **Multi-language costs a capture run per language**, on purpose: the interface has to be
  in the language the voice is speaking, or it reads as a mistake.

## Questions people have actually asked

**Does it replace automated testing?** No, it complements it. It captures the full path as
a user lives it, which is what tests of the parts do not see.

**Do I need Claude Code to use it?** To write the first walkthrough, yes — that is what
learns your project. To regenerate the video afterwards, no: `run.sh` is bash, ffmpeg and
edge-tts, and no model is involved.

**My stack is neither Rails nor Playwright.** The engine does not know what produced the
PNGs, so it works the same. What you write is the capture, in your stack, using the
Playwright recipe as the reference for what it has to do.

**Does test data end up in the video?** Whatever your walkthrough uses — which is why it is
written against factories and seeded data, never production. `apiPanel`'s `trimValue`
shows the start of a value rather than the value, and is meant for credentials.

**Does it record the screen?** No. It builds the video from numbered screenshots, which is
what makes it stable and regenerable. You will not see a cursor moving.

**Does it work offline?** No. The voices are generated against Microsoft Edge's service:
no account and no API key, but it does need a network.

**Which voices?** Edge's, including Spanish for several countries. Picked per flow or per
language — see [voices](skills/e2e-video-doc/reference/voices.md).

## Where it came from

Four projects had the same pipeline copied by hand, each drifting on its own. Comparing
the four copies of the engine, every one had fixes the others lacked:

| | A | B | C | D |
|---|---|---|---|---|
| environment overrides | yes | yes | **no** | yes |
| `realpath` in the concat list | yes | — | **no** | yes |
| `mkdir -p` of the output directory | **no** | **no** | **no** | yes |
| empty-concat guard | **no** | **no** | **no** | yes |

This engine is the union of all four.
[`reference/gotchas.md`](skills/e2e-video-doc/reference/gotchas.md) is the rest of what
those four projects learned the expensive way.

## Layout

```
.claude-plugin/plugin.json
CHANGELOG.md    # this plugin's versions — plugin.json says which one you have
skills/e2e-video-doc/
  SKILL.md      # the entry point
  engine/       # the engine — depends on no project
  recipes/      # capture helpers per stack
  reference/    # config, narration, voices, and what already cost us
examples/sample-app/
                # the ten-minute demo, and the regression fixture for the
                # Playwright recipe — its tests import the helper directly
```

## Reporting something

Issues are welcome, especially "it did not work on my stack". The
[report template](../../.github/ISSUE_TEMPLATE/bug_report.md) asks for what actually
helps: your OS, your stack, which of the five tools you have and where, and what the PNGs
looked like. An attempt you abandoned is a better report than a success that took three
questions.
