# e2e-video-doc

A script walks your app doing what a person would do — sign in, enter data, navigate —
taking numbered screenshots along the way. A JSON gives them narration, and the engine
turns them into a narrated MP4 with a synthetic voice.

What comes out is not just a video: it is documentation that **fails when the product
changes**, because the walkthrough is a real end-to-end test.

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

## What you need

On whichever machine assembles the video:

```bash
for c in edge-tts ffmpeg ffprobe jq python3; do printf "%-10s %s\n" "$c" "$(command -v $c || echo MISSING)"; done
```

```bash
brew install ffmpeg jq        # macOS
sudo apt install ffmpeg jq    # Debian/Ubuntu
pip install edge-tts          # both
```

The TTS is Microsoft Edge's, which needs no API key. On Windows these live in WSL, and the
plugin captures on the host and crosses the bridge to assemble — see the Windows section of
[gotchas](skills/e2e-video-doc/reference/gotchas.md).

## Getting started

Ask Claude for a video of a flow and the skill drives it. What it does, in order:

1. Detects your stack and copies the matching capture helper into your project —
   [Rails/Capybara](skills/e2e-video-doc/recipes/rails-capybara/) or
   [Playwright](skills/e2e-video-doc/recipes/playwright-node/).
2. Writes the walkthrough with your factories, your login helper, your seeded data.
3. Runs the capture and **looks at the PNGs before narrating** — the step that catches the
   failures a green test does not.
4. Writes the narration, adds the flow to `e2e-video-doc.json`, assembles the MP4.

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

If you are evaluating, start with [`examples/sample-app`](../../examples/sample-app/) — it
is the ten-minute version and needs no project of your own.

## Where it has actually run

Only the first column is a promise. The rest is what has been exercised on real projects,
and it is deliberately not a longer list.

| | Status |
|---|---|
| Rails + Capybara + Selenium | Four projects, including multi-language and devcontainers |
| Playwright + TypeScript | One project, including the API panel |
| Linux | Every run |
| Windows + WSL | One project, host capture and WSL assembly |
| macOS | **Never run.** Nothing should stop it; nobody has tried |
| Any other stack | The contract is `NN_name.png` + a narration JSON. The engine does not care what produced the PNGs — but no one has written a third recipe yet |

## What it does not do

- **The walkthrough has to live with the app to be worth it.** It can technically live in
  another repo, and then it breaks in a place nobody is looking — see
  [#4](https://github.com/kleer-la/claude-plugins/issues/4).
- **No speech-rate setting** in the config yet, though the engine honours `RATE`
  ([#2](https://github.com/kleer-la/claude-plugins/issues/2)).
- **Title cards are generated, not supplied.** A project that wants its own opening image
  copies it in from the capture step ([#2](https://github.com/kleer-la/claude-plugins/issues/2)).
- **Multi-language costs a capture run per language**, on purpose: the interface has to be
  in the language the voice is speaking, or it reads as a mistake.

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
skills/e2e-video-doc/
  SKILL.md      # the entry point
  engine/       # the engine — depends on no project
  recipes/      # capture helpers per stack
  reference/    # config, narration, voices, and what already cost us
```

## Reporting something

Issues are welcome, especially "it did not work on my stack". The
[report template](../../.github/ISSUE_TEMPLATE/bug_report.md) asks for what actually helps:
your OS, your stack, which of the five tools you have and where, and what the PNGs looked
like.
