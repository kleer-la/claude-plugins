# Kleer's Claude Code plugins

The team marketplace. Add it once, and plugins added later show up on their own.

```
/plugin marketplace add kleer-la/claude-plugins
/plugin install e2e-video-doc@kleer-la
```

### From the desktop app

Its plugin browser installs from marketplaces you already have configured, but **adding
one is a CLI command**. Either run the two lines above once in `claude` and restart the
app, or register the marketplace yourself and never open a terminal — in
`~/.claude/settings.json` for every project, or a project's `.claude/settings.json` for
one:

```json
{
  "extraKnownMarketplaces": {
    "kleer-la": { "source": { "source": "github", "repo": "kleer-la/claude-plugins" } }
  },
  "enabledPlugins": { "e2e-video-doc@kleer-la": true }
}
```

In a project's settings this takes effect only once the folder is trusted.

Two things that look like the plugin failing and are not: it lives in the **Code** tab —
Chat and Cowork take their plugins from the claude.ai account rather than from
`~/.claude` — and the Linux desktop app is a beta, installed with `apt` or a `.deb` on
Ubuntu and Debian.

## Plugins

| Plugin | What it does |
|---|---|
| [`e2e-video-doc`](plugins/e2e-video-doc/) | Walks your app like a real user and produces a narrated video, screenshots, and the detail of each API call. The walkthrough is an E2E test: when it breaks, the screen changed. |

---

# e2e-video-doc

A script walks your app doing what a person would do — sign in, enter data, navigate —
taking numbered screenshots along the way. A JSON gives them narration, and the engine
turns them into a narrated MP4 with a synthetic voice.

What comes out is not just a video: it is documentation that **fails when the product
changes**, because the walkthrough is a real end-to-end test.

## See it

[![Watch the demo](https://img.youtube.com/vi/h2U_B-G8fZg/hqdefault.jpg)](https://youtu.be/h2U_B-G8fZg)

One minute, generated from [`examples/sample-app`](examples/sample-app/) by the plugin
itself — [English](https://youtu.be/h2U_B-G8fZg) · [Español](https://youtu.be/M0JQVx_tBEg).

The two are not one recording dubbed twice. Each language captures again, so the
interface changes along with the voice: catalogue, buttons, number formatting, order
status. A screen in one language under a voice in another reads as a mistake rather than
as a translation, and that rule is the reason multi-language costs a capture run per
language.

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
[gotchas](plugins/e2e-video-doc/skills/e2e-video-doc/reference/gotchas.md).

## Getting started

Ask Claude for a video of a flow and the skill drives it. What it does, in order:

1. Detects your stack and copies the matching capture helper into your project —
   [Rails/Capybara](plugins/e2e-video-doc/skills/e2e-video-doc/recipes/rails-capybara/) or
   [Playwright](plugins/e2e-video-doc/skills/e2e-video-doc/recipes/playwright-node/).
2. Writes the walkthrough with your factories, your login helper, your seeded data.
3. Runs the capture and **looks at the PNGs before narrating** — the step that catches the
   failures a green test does not.
4. Writes the narration, adds the flow to `e2e-video-doc.json`, assembles the MP4.

The one file you write per project is `e2e-video-doc.json` at the repo root. See
[config](plugins/e2e-video-doc/skills/e2e-video-doc/reference/config.md).

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

If you are evaluating, start with [`examples/sample-app`](examples/sample-app/) — it is
the ten-minute version and needs no project of your own.

## Where it has actually run

Only the first column is a promise. The rest is what has been exercised on real projects,
and it is deliberately not a longer list.

| | Status |
|---|---|
| Rails + Capybara + Selenium | Four projects, including multi-language and devcontainers |
| Playwright + TypeScript | Two projects, including the API panel. One of them installed cold by someone outside the team, on macOS, and produced a video without asking us anything |
| Linux | Every run |
| Windows + WSL | One project, host capture and WSL assembly |
| macOS | The sample app, end to end. The engine needed no changes; six fixes went into prerequisites and error messages |
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
language — see [voices](plugins/e2e-video-doc/skills/e2e-video-doc/reference/voices.md).

## Adding a plugin to this marketplace

1. `plugins/<name>/.claude-plugin/plugin.json` with `name`, `version`, `description`, `author`
2. Skills in `plugins/<name>/skills/<skill>/SKILL.md`
3. An entry in `.claude-plugin/marketplace.json` with `"source": "./plugins/<name>"`

If one ever grows enough to deserve its own repository, the entry becomes
`{"source": "url", "url": "https://github.com/kleer-la/<repo>.git"}` and nothing changes
for anyone who has it installed.

## Reporting something

Issues are welcome, especially "it did not work on my stack". The
[report template](.github/ISSUE_TEMPLATE/bug_report.md) asks for what actually helps:
your OS, your stack, which of the five tools you have and where, and what the PNGs looked
like.

## License

MIT — see [LICENSE](LICENSE).
