# e2e-video-doc

A Claude Code plugin. Walks your application like a real user and produces a narrated
video, screenshots, and the detail of each API call.

The walkthrough is an **E2E test**: when it breaks, the screen changed. That is why the
documentation it produces cannot go stale in silence.

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

Then ask Claude for a video of a flow, or write the `e2e-video-doc.json` yourself — see
`skills/e2e-video-doc/reference/config.md`.

## What it is built on

`ffmpeg` and `ffprobe` assemble, `edge-tts` speaks, `jq` reads the config, `python3` does
the arithmetic. No API key and no account.

How to install them is deliberately not written down: `engine/check.sh` says which are
missing here and with which command, and the agent takes it from there. On Windows they
are not on the host at all — capture runs there and assembly crosses into WSL.

## How it is split

```
capture  →  NN_name.png  +  [{screenshot, duration, narration}]  →  engine
(yours)                 THE CONTRACT                             (the plugin's)
```

The engine is stack-agnostic — it does not care whether the PNG came from Capybara,
Playwright, or a rasterised PDF. The walkthrough is yours, because it uses your factories
and has to age with your project.

## Where it came from

Four projects had the same pipeline copied by hand, each drifting on its own. Comparing
the four copies of the engine, every one had fixes the others lacked:

| | A | B | C | D |
|---|---|---|---|---|
| environment overrides | yes | yes | **no** | yes |
| `realpath` in the concat list | yes | — | **no** | yes |
| `mkdir -p` of the output directory | **no** | **no** | **no** | yes |
| empty-concat guard | **no** | **no** | **no** | yes |

This engine is the union of all four. `reference/gotchas.md` is the rest of what those
four projects learned the expensive way.

## Layout

```
.claude-plugin/plugin.json
skills/e2e-video-doc/
  SKILL.md      # the entry point
  engine/       # the engine — depends on no project
  recipes/      # capture helpers per stack
  reference/    # config, narration, voices, and what already cost us
```
