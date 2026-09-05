# Kleer's Claude Code plugins

The team marketplace. Add it once, and plugins added later show up on their own.

```
/plugin marketplace add kleer-la/claude-plugins
```

Then install what you want: `/plugin install <name>@kleer-la`.

### From the desktop app

Its plugin browser installs from marketplaces you already have configured, but **adding
one is a CLI command**. Either run the line above once in `claude` and restart the app, or
register the marketplace yourself and never open a terminal — in `~/.claude/settings.json`
for every project, or a project's `.claude/settings.json` for one:

```json
{
  "extraKnownMarketplaces": {
    "kleer-la": { "source": { "source": "github", "repo": "kleer-la/claude-plugins" } }
  },
  "enabledPlugins": { "e2e-video-doc@kleer-la": true }
}
```

In a project's settings this takes effect only once the folder is trusted.

Two things that look like a plugin failing and are not: they live in the **Code** tab —
Chat and Cowork take their plugins from the claude.ai account rather than from
`~/.claude` — and the Linux desktop app is a beta, installed with `apt` or a `.deb` on
Ubuntu and Debian.

## Plugins

| Plugin | What it does | When to reach for it |
|---|---|---|
| **[e2e-video-doc](plugins/e2e-video-doc/)** | Films a real end-to-end test walking your app — sign in, enter data, navigate — and turns the screenshots into a narrated MP4, with each API call drawn as a card. | You need a demo or a user guide of a flow that already ships, and you do not want it quietly going stale: because the walkthrough is a test, a screen that moves breaks the run instead of the video. |

Each plugin documents itself: what it is built on, how to start, what it costs, where it
has actually run and what it does not do all live in that plugin's own README. This table
only says enough to choose one.

## Adding a plugin to this marketplace

1. `plugins/<name>/.claude-plugin/plugin.json` with `name`, `version`, `description`, `author`
2. Skills in `plugins/<name>/skills/<skill>/SKILL.md`
3. `plugins/<name>/README.md` that stands on its own — assume the reader arrived from a
   link and has not read this page
4. An entry in `.claude-plugin/marketplace.json` with `"source": "./plugins/<name>"`, and
   a row in the table above

If one ever grows enough to deserve its own repository, the entry becomes
`{"source": "url", "url": "https://github.com/kleer-la/<repo>.git"}` and nothing changes
for anyone who has it installed. That is the reason a plugin's documentation lives with
the plugin: moving it out should be an edit to `marketplace.json`, not a documentation
project.

## Reporting something

Issues are welcome, especially "it did not work on my stack". The
[report template](.github/ISSUE_TEMPLATE/bug_report.md) asks for what actually helps: your
OS, your stack, which tools you have and where, and what went wrong. An attempt you
abandoned is a better report than a success that took three questions.

## License

MIT — see [LICENSE](LICENSE).
