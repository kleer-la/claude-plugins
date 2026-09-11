---
name: session-handoff
description: Turns a working session with an agent into a 3–4 minute briefing the rest of the team can listen to. Use it when asked for a handoff podcast, a session briefing, to catch teammates up, "poné al tanto al equipo", "generá el podcast de la sesión", or at the end of a session that changed a shared document. The conversation is the source; the document diff is the ground truth.
---

# session-handoff

A session with an agent produces a lot of context that stays trapped there. This
skill writes a short briefing the rest of the team can listen to: what actually
changed in the shared document, which decisions were taken (and which were
rejected), what is still open, and where to look.

The conversation is the source. The document diff is the ground truth. If the
agent says it changed a section and the file did not move, the briefing says
the file did not move.

## The cut line

```
session           →  briefing.json  →  engine
(transcript +         THE CONTRACT     (edge-tts + ffmpeg)
 the real diff)
```

**Above the line the plugin is source-agnostic.** The engine is bash + ffmpeg +
edge-tts and does not care whether the beats came from a git diff, a Google Doc
or a wiki. v1 only ships the git recipe.

## Before doing anything

1. **Run `bash engine/check.sh`.** Four tools, checked by running them rather
   than locating them. Do it now: it is the only failure here that needs a
   human to install something.
2. **Read [reference/gotchas.md](reference/gotchas.md).** Short, and every item
   is there because the alternative was a bad podcast.
3. **Is there a `session-handoff.json` at the project root?** If not, copy
   [examples/session-handoff.json](../../../examples/session-handoff.json). See
   [reference/config.md](reference/config.md).

## Producing a briefing

1. **Ask whether this briefing will be shared.** The MP3 is for other humans.
   If the session had secrets, personal asides, or anything that should not
   leave the pair, stop. [gotchas](reference/gotchas.md) lists what to strip
   even when they say yes.
2. **Run `bash engine/diff.sh` from the project root.**
   - Exit 0: there are changes. Read `changes.diff`, `changes.stat`, `files.txt`
     under `.claude/session-handoff/`.
   - Exit 2: the shared artifact did not move. **Do not invent a podcast of
     the conversation.** Say so. If they insist, the briefing can cover
     decisions with no `change` beat, and you must say in the opening that
     the document itself is untouched.
   - Exit 1: no `start.json` or no git. If the plugin was installed mid-session,
     take `HEAD` as the "before" only after confirming with the user; it will
     miss edits already committed. If there is no git, stop: v1 has no other
     recipe.
3. **Read the transcript only for what the diff cannot tell you** — decisions,
   rejected alternatives, open questions. Skip tool calls, retries, dead ends
   that did not change a decision, and anything that looks like a secret.
   The transcript is at `.claude/session-handoff/transcript.jsonl` if
   SessionEnd already copied it; otherwise use the conversation you are in.
4. **Write `briefing.json`** next to the other session state —
   `.claude/session-handoff/briefing.json`. See
   [reference/briefing.md](reference/briefing.md). One beat per idea, short
   sentences, 3–4 minutes. Every `change` beat names a path that appears in
   `files.txt`. If a beat has no ancla in the diff, drop it or mark it as a
   decision.
5. **Show the briefing to the user and wait.** This is the same step as
   looking at the PNGs before spending audio in e2e-video-doc. Offer to edit
   beats. Do not call the engine until they say go.
6. **Assemble.**

   ```bash
   BRIEFING=.claude/session-handoff/briefing.json \
   OUTPUT=handoffs/$(date -u +%Y-%m-%d)-<slug>.mp3 \
   VOICE="${VOICE:-$(jq -r '.defaults.voice // "es-AR-ElenaNeural"' session-handoff.json 2>/dev/null)}" \
     bash engine/make_brief.sh
   ```

   `<slug>` is a few words from the title, lowercase, hyphens. The MP3 does
   not live in `.claude/` or in `tmp/` — the team has to find it.
7. **Report:** file path, duration, size, how many `change` beats were
   anchored in `files.txt`, and how many beats had no ancla. Then stop. Do
   not add a written recap on top of the audio unless they ask: the audio
   *is* the recap.

## What you do not do

- Do not narrate the session beat by beat. That is a transcript with a voice.
- Do not fire this from SessionEnd. The hook copies the transcript and that
  is all. This skill runs while the session is still alive, on purpose.
- Do not dramatise the user and the agent as two podcast hosts.
- Do not put `.env`, tokens, passwords, or private asides in the narration.
- Do not write the briefing from memory of the chat when `changes.diff` is
  sitting there unread.

## What is here

| | |
|---|---|
| `engine/check.sh` | Preflight. Run it first. |
| `engine/diff.sh` | Git recipe: since SessionStart, what actually moved. |
| `engine/make_brief.sh` | `briefing.json` → MP3. Driven by the environment. |
| `engine/test.sh` | Engine + hooks, no Claude Code session required. |
| `reference/` | [briefing](reference/briefing.md) · [config](reference/config.md) · [voices](reference/voices.md) · [gotchas](reference/gotchas.md) |
| `recipes/git/` | What the git recipe promises and what it does not. |
