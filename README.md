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

## Adding a plugin

1. `plugins/<name>/.claude-plugin/plugin.json` with `name`, `version`, `description`, `author`
2. Skills in `plugins/<name>/skills/<skill>/SKILL.md`
3. An entry in `.claude-plugin/marketplace.json` with `"source": "./plugins/<name>"`

If one ever grows enough to deserve its own repository, the entry becomes
`{"source": "url", "url": "https://github.com/kleer-la/<repo>.git"}` and nothing changes
for anyone who has it installed.
