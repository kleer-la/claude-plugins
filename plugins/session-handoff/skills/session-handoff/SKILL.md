---
name: session-handoff
description: Turns a working session with an agent into a 3–4 minute briefing the rest of the team can listen to. Use it when asked for a handoff podcast, a session briefing, to catch teammates up, "poné al tanto al equipo", "generá el podcast de la sesión", "haceme el handoff", or at the end of a session that changed a shared document — or reviewed one. The conversation is the source; the document diff is the ground truth when there is one.
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
session           →  briefing.json  →  audio
(transcript +         THE CONTRACT     (the Kleer service, the
 the real diff)                         connector, or edge-tts + ffmpeg)
```

**Above the line the plugin is source-agnostic.** The audio side does not care
whether the beats came from a git diff, a Google Doc or a review in a chat.

## Which situation are you in?

Look, do not ask. Three facts decide it:

1. **Is there a shell** (a Bash tool)? Claude Desktop and the web chat usually
   have none.
2. **Is there a tool called `briefing_audio`**, from the Kleer session-handoff
   connector? It turns the beats into an MP3 without a shell.
3. **Is there a git repository, and did the shared document move?**

| Situation | Mode | Audio |
|---|---|---|
| Git repo, and the document moved | **diff** | `make_brief.sh` or `briefing_audio` |
| No git, or nothing moved, and the user wants the briefing anyway | **review** | same |
| No shell and no `briefing_audio` | either | none: see [No way to make audio](#no-way-to-make-audio) |

Diff mode is the default and the plugin's reason to exist. Review mode is the
exception, and only when the user says yes.

## Before doing anything (with a shell)

1. **Run `bash engine/check.sh`** only if you will use the local engine, that is,
   if `SESSION_HANDOFF_TTS_TOKEN` is not set. Four tools, checked by running
   them rather than locating them. With the token, `make_brief.sh` needs only
   `curl` and `jq`. See [config](reference/config.md).
2. **Read [reference/gotchas.md](reference/gotchas.md).** Short, and every item
   is there because the alternative was a bad podcast.
3. **Is there a `session-handoff.json` at the project root?** If not, copy
   [examples/session-handoff.json](../../../examples/session-handoff.json).

Without a shell, skip all three: read the gotchas, nothing else.

## Diff mode

1. **Ask whether this briefing will be shared.** The MP3 is for other humans.
   If the session had secrets, personal asides, or anything that should not
   leave the pair, stop. [gotchas](reference/gotchas.md) lists what to strip
   even when they say yes.
2. **Run `bash engine/diff.sh` from the project root.**
   - Exit 0: there are changes. Read `changes.diff`, `changes.stat`, `files.txt`
     under `.claude/session-handoff/`.
   - Exit 2: the shared document did not move. Do not invent a recap of the
     conversation. Say so, and offer [review mode](#review-mode).
   - Exit 1: no `start.json` or no git. If the plugin was installed
     mid-session and there is git, take `HEAD` as the "before" only after
     confirming with the user; it will miss edits already committed. If there
     is no git, say so and offer [review mode](#review-mode).
3. **Read the transcript only for what the diff cannot tell you** — decisions,
   rejected alternatives, open questions. Skip tool calls, retries, dead ends
   that did not change a decision, and anything that looks like a secret.
   The transcript is at `.claude/session-handoff/transcript.jsonl` if
   SessionEnd already copied it; otherwise use the conversation you are in.
4. **Write the briefing.** See [reference/briefing.md](reference/briefing.md).
   One beat per idea, short sentences, 3–4 minutes. Every `change` beat names
   a path that appears in `files.txt`. If a beat has no ancla in the diff, drop
   it or mark it as a decision. With a shell, write it to
   `.claude/session-handoff/briefing.json`; without one, it lives in the chat.
5. **Show the briefing to the user and wait.** Offer to edit beats. Do not
   make audio until they say go.
6. **Assemble** ([below](#assemble)).
7. **Report:** where the audio is (a path, or the link and when it expires),
   duration and size when you know them, how many `change` beats were anchored
   in `files.txt`, and how many beats had no ancla. Then stop. Do not add a
   written recap on top of the audio unless they ask: the audio *is* the recap.

## Review mode

For a session where the shared document did not change, or where there is no
repository at all: someone sent a proposal and the session reviewed it, weighed
an offer, decided what to answer. The work is in the decisions, and a diff has
nothing to say about them.

The document is no longer the ground truth, so this mode is deliberately
smaller and says so out loud.

1. **Offer it, never assume it.** "No document changed. Do you want a review
   briefing — decisions and open questions only, about two minutes?" If the
   answer is no, stop; a text summary in the chat is a fine alternative.
2. **Ask whether it will be shared**, as in diff mode. A review often carries
   other people's messages pasted from another chat: see
   [gotchas](reference/gotchas.md), "Pasted messages are not yours to broadcast".
3. **Write it shorter:** one to two minutes, five or six beats at most.
   - `open` names **what was reviewed**, says plainly **that it was not
     modified**, and says for whom or on whose request when the user told you.
   - `decision` beats carry the verdicts and the feedback given, and the
     alternative that was rejected when there was one.
   - `open-question` beats carry what is still unresolved and who has the ball.
   - `where` says where the reviewed document and the thread live.
   - **No `change` beats.** There is no diff to anchor them, and a `change`
     beat with no path is an invented one.
4. **Set `artifact`** to `{ "kind": "review", "name": "<what was reviewed>",
   "modified": false }`. See [briefing](reference/briefing.md).
5. **Show it and wait**, then [assemble](#assemble) and report as in diff mode.

Do not retell the reviewed document. The listener can read it; what they cannot
read is what was decided about it.

## Assemble

Pick the first that applies:

1. **A shell, and `SESSION_HANDOFF_TTS_TOKEN` is set or `check.sh` passes:**

   ```bash
   BRIEFING=.claude/session-handoff/briefing.json \
   OUTPUT=handoffs/$(date -u +%Y-%m-%d)-<slug>.mp3 \
   VOICE="${VOICE:-$(jq -r '.defaults.voice // "es-AR-ElenaNeural"' session-handoff.json 2>/dev/null)}" \
     bash engine/make_brief.sh
   ```

   `<slug>` is a few words from the title, lowercase, hyphens. The MP3 does
   not live in `.claude/` or in `tmp/` — the team has to find it. With the
   token it is synthesised remotely (only `curl` and `jq` needed) and falls
   back to the local engine; see [config](reference/config.md).

2. **The `briefing_audio` tool is available** (no shell needed, the case in
   Claude Desktop and the web chat): call it once with the beats you showed the
   user.

   - `beats`: the array as approved, each `{ "narration": "...", "duration": N }`.
     Leave out beats with no narration, and never send `duration` above 60.
   - `voice` and `rate`: only when the user asked for another voice
     (`es-AR-ElenaNeural` and `+8%` are the defaults).
   - It returns a `download_url` and an `expires_at`. **The link works for one
     hour, without a login, and the audio is not kept afterwards.** Give the
     user the link, tell them to download the file now, and say when it
     expires. If the tool answers with a limit or a busy message, say so
     plainly; do not retry in a loop.

3. **Neither:** [No way to make audio](#no-way-to-make-audio).

## No way to make audio

No shell and no `briefing_audio` tool means this session cannot produce the MP3.
Say that in one sentence, and do not pretend the briefing is audio.

Give them the briefing as text, ready to read aloud. Then tell them how to get
audio next time: sign in at **handoff.kleer.la** and add the connector
(`https://handoff.kleer.la/handoff/mcp`) in Claude Desktop or the web chat with
"Add custom connector", or, in Claude Code, set `SESSION_HANDOFF_TTS_TOKEN`
with the personal token that page shows.

## What you do not do

- Do not narrate the session beat by beat. That is a transcript with a voice.
- Do not refuse a session only because there is no git. Offer review mode.
- Do not start review mode unasked, and do not use it to avoid an empty diff
  you should have reported.
- Do not fire this from SessionEnd. The hook copies the transcript and that
  is all. This skill runs while the session is still alive, on purpose.
- Do not dramatise the user and the agent as two podcast hosts.
- Do not put `.env`, tokens, passwords, or private asides in the narration.
- Do not write the briefing from memory of the chat when `changes.diff` is
  sitting there unread.

## What is here

| | |
|---|---|
| `engine/check.sh` | Preflight for the local engine. Run it first when there is no token. |
| `engine/diff.sh` | Git recipe: since SessionStart, what actually moved. |
| `engine/make_brief.sh` | `briefing.json` → MP3. Remote with a token, local otherwise. |
| `engine/test.sh` | Engine + hooks, no Claude Code session required. |
| `reference/` | [briefing](reference/briefing.md) · [config](reference/config.md) · [voices](reference/voices.md) · [gotchas](reference/gotchas.md) |
| `recipes/git/` | What the git recipe promises and what it does not. |
