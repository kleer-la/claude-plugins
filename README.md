# Kleer's Claude Code plugins

The team marketplace. Add it once, and plugins added later show up on their own.

```
/plugin marketplace add kleer-la/claude-plugins
/plugin install e2e-video-doc@kleer-la
```

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

## What you need

On whichever machine assembles the video:

```bash
for c in edge-tts ffmpeg ffprobe jq python3; do printf "%-10s %s\n" "$c" "$(command -v $c || echo MISSING)"; done
```

`pip install edge-tts`, and `apt install ffmpeg jq` (or `brew install ffmpeg jq`). The TTS
is Microsoft Edge's, which needs no API key. On Windows these live in WSL, and the plugin
captures on the host and crosses the bridge to assemble — see the Windows section of
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
