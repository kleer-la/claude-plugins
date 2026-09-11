# session-handoff

A session with an agent produces a lot of context that stays trapped there.
This plugin writes a 3–4 minute briefing the rest of the team can listen to:
what actually changed in the shared document, which decisions were taken (and
which were rejected), what is still open, and where to look.

The conversation is the source. The document diff is the ground truth. If the
agent says it changed a section and the file did not move, the briefing says
the file did not move.

## See it

The [sample briefing](examples/sample-briefing.json) is the contract in full —
five beats, Argentine Spanish, a made-up pricing canvas. Assemble it with:

```bash
BRIEFING=examples/sample-briefing.json \
OUTPUT=/tmp/handoff-sample.mp3 \
VOICE=es-AR-ElenaNeural \
  bash skills/session-handoff/engine/make_brief.sh
```

The [fixture](examples/fixture-briefing.json) is the shorter version the engine
test uses. Neither is a recording of a real team session; that is the next
thing this plugin has to survive, and it has not yet.

## What you get

- **A 3–4 minute MP3** per session, in any of edge-tts's voices.
- **A briefing that refuses to exist when the document did not move.** An empty
  diff is not a conversation recap.
- **Decisions the diff cannot show** — the alternative that was considered and
  dropped, the question left open for the rest of the team.

Useful for catching up a teammate who was not in the pair, an async stand-up
that does not need a meeting, and leaving a trail on a shared canvas that is
cheaper to hear than to reconstruct from git log.

## Install

```
/plugin marketplace add kleer-la/claude-plugins
/plugin install session-handoff@kleer-la
```

The marketplace README covers [installing without a
terminal](../../README.md#from-the-desktop-app), for the desktop app.

Then, towards the end of a session that changed the shared document:

```
/session-handoff:handoff
```

or ask in the language you work in: *poné al tanto al equipo*.

## How this differs from the other handoff plugins

Most Claude Code "handoff" plugins write a `HANDOFF.md` so **your next Claude
session** remembers. The audience is the model. The artifact is markdown. The
job is amnesia.

This one is for **the humans who were not in the session**. The audience is a
teammate on a bus. The artifact is an MP3. The job is catching them up on a
shared document.

| | HANDOFF.md / session memory | NotebookLM Audio Overview | session-handoff |
|---|---|---|---|
| Who it is for | You, and the next Claude | Anyone you send the file to | The teammates who missed the pair |
| What it reads | The chat, maybe git status | Whatever you uploaded | The **diff since SessionStart**, then the chat for decisions |
| What comes out | Markdown for the model | A two-host podcast about the sources | A 3–4 min briefing in one voice |
| Failure mode | A stale note | A lively chat that cannot tell *what changed today* from what the doc already said | Empty diff → no audio |

NotebookLM is the medium people already know. It is also the wrong input: you
export by hand, and the two hosts will talk about the whole document. Here the
input is the session, the ancla is the diff, and there is one narrator.

## What it is built on

Four things, on whichever machine assembles the audio: `ffmpeg` puts the beats
together, `edge-tts` speaks them, `jq` reads the JSON, `python3` does the
arithmetic. Microsoft Edge's voices need no API key and no account.

**There are no install instructions here on purpose.** Ask Claude to run the
plugin's preflight, `engine/check.sh`: it reports which of the four are missing
on *this* machine and with which command.

## Getting started

1. Install the plugin. SessionStart snapshots `git HEAD` into
   `.claude/session-handoff/start.json`. That is the "before".
2. Work as usual. Writes and edits are appended to `touched.txt`.
3. When you want the team to hear it, run `/session-handoff:handoff` (or ask).
   The skill diffs against the snapshot, writes a `briefing.json`, **shows it
   to you**, and only then calls the engine.
4. Send the MP3. That is the handoff.

The one file you may write per project is `session-handoff.json` at the repo
root. See [config](skills/session-handoff/reference/config.md).

## How it is split

```
session           →  briefing.json  →  engine
(transcript +         THE CONTRACT     (from the plugin)
 the real diff)
```

The engine is stack-agnostic — it does not care whether a beat came from a git
diff or a Google Doc. v1 only ships the git recipe. The briefing is yours,
because the decisions are.

## What it costs

The expensive part happens once, while the session is still open. Regeneration
is a bash script.

| | Time | Model tokens |
|---|---|---|
| Try the sample briefing | ~1 minute | None — `check.sh`, then one command |
| First briefing of **your** session | A few minutes | Cheap. The model is already in the session; it is writing a JSON, not re-reading the repo |
| Every regeneration after that (other voice, other language) | Seconds | **None.** `make_brief.sh` is bash, ffmpeg and edge-tts |

If you are evaluating, start with [`examples/sample-briefing.json`](examples/sample-briefing.json)
— it is the one-minute version and needs no project of your own. Then
`bash skills/session-handoff/engine/test.sh` for the hooks and the git recipe.

## Where it has actually run

Only the first column is a promise. The rest is what has been exercised, and
it is deliberately not a longer list.

| | Status |
|---|---|
| Engine (`make_brief.sh`) | Linux, `es-AR-ElenaNeural`, sample + fixture. Needs a network for TTS |
| Hooks + `diff.sh` | Linux, a throwaway git repo, including "compact must not reset HEAD" and "empty tree → exit 2" |
| Claude Code, a real pair on a shared document | **Not yet.** The skill has not been driven by an agent in an actual session |
| Google Docs / anything that is not git | The contract allows it. There is no recipe |
| Windows + WSL, macOS | Untested. The engine is the same bash as e2e-video-doc, which has run on both |

## What it does not do

- **It does not narrate the conversation.** A teammate does not need the
  retries. They need the briefing.
- **It does not run when the session ends.** SessionEnd copies the transcript
  in under two seconds and stops. You ask for the podcast on purpose, while
  you can still edit the script.
- **It does not decide which document is the shared one.** `paths` in
  `session-handoff.json`, or a question, once.
- **v1 is git.** A Google Doc, a wiki, a Notion page: the JSON contract is
  the same, the recipe is not written.
- **It does not replace the PR or the comment on the Doc.** It is *what
  happened and why*; the diff is still the diff.
- **It does not dramatise two hosts.** One voice, first person, the human who
  did the work.
- **It will not invent a briefing from an empty diff.** That is the feature.

## Questions people will ask

**Does this replace a stand-up?** No. It replaces the "catch me up on what you
and the agent did to the canvas this afternoon" side conversation.

**Do I need Claude Code to listen to it?** No. You need it to write the first
briefing. After that, `make_brief.sh` is bash and edge-tts.

**Will it leak secrets?** It will if you let it. The skill asks before
assembling, and it is instructed to strip tokens, `.env`, and private asides.
The MP3 is a thing you send; treat it that way.

**Can it fire automatically every session?** It could. It should not. A
podcast of every `/clear` is how the team learns to ignore it.

**Why not just paste the diff in Slack?** The diff is *what*. The briefing is
*why*, including what you considered and did not do. That is the part that
dies when the session closes.

## Layout

```
.claude-plugin/plugin.json
CHANGELOG.md
commands/handoff.md     # /session-handoff:handoff
hooks/                  # capture only — start.json, touched.txt, transcript
skills/session-handoff/
  SKILL.md
  engine/               # check, diff, make_brief, test
  recipes/git/
  reference/            # briefing, config, voices, gotchas
examples/
  sample-briefing.json  # the one-minute listen
  fixture-briefing.json # the engine test
  session-handoff.json  # copy to a project root
```

## Reporting something

Issues are welcome, especially "I listened to this and still had to ask the
author a question". That question belonged in the briefing. The
[report template](../../.github/ISSUE_TEMPLATE/bug_report.md) asks for what
actually helps: your OS, whether git was involved, `check.sh` output, and the
`briefing.json` (redacted) if the audio came out wrong.
