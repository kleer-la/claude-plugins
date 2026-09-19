# Gotchas

Paid for in design, or in the first engine run. Read once.

## The conversation is not the artifact

A podcast of the session as it happened is 40 minutes of retries and tool
calls. Teammates need the briefing: what landed, what was decided, what was
discarded, what is open. The cut is the same one e2e-video-doc makes when it
refuses to film the cursor.

## The diff is the ground truth

The agent can claim it changed a heading. `engine/diff.sh` is what actually
moved since SessionStart. Write `change` beats from `changes.diff`, not from
memory of the chat. Decisions and rejected alternatives are the only thing
the transcript is for.

## Empty diff: no recap of the chat, but a review is not a recap

Exit 2 from `diff.sh` means the shared artifact did not move. Do not
compensate with a recap of the conversation. Say the document did not move.

Some sessions never had a diff to show: someone sent a proposal, the session
reviewed it and decided what to answer. There the decisions *are* the work.
Offer **review mode** (see SKILL.md): decisions and open questions only, no
`change` beats, an opening that says what was reviewed and that it was not
modified. Offer it; never start it unasked.

## No git is not "stop"

A chat in Claude Desktop or on the web has no repository and no shell. That
does not make the session unbriefable. The diff recipe needs git; the briefing
does not. Without git the honest options are review mode, or a text summary.

## No shell: the audio comes from the connector

Without a Bash tool, `make_brief.sh` cannot run. If the `briefing_audio` tool
is there, use it; if it is not, say the session cannot produce audio and hand
over the text with the two ways to fix that (SKILL.md, "No way to make audio").
Do not claim an MP3 that was never made.

## The connector's link expires

`briefing_audio` returns a `download_url` that works for one hour, without a
login, and the audio is not kept after that. Say when it expires and ask the
user to download the file now; the link is not a place to store it.

## Pasted messages are not yours to broadcast

A review session often has messages from other people pasted in — a Telegram
thread, an email, a proposal someone sent. The user pasted them to get your
help, not to have them read aloud to a team. Summarise positions and what was
decided ("propusieron X, contestamos Y"); do not quote messages or name people
who did not opt in. When unsure, ask before assembling.

## SessionEnd does not assemble

The hook has a budget of about 1.5 seconds and also fires on `/clear`. It
copies the transcript and stops. The skill runs while the session is still
alive, so a human can read the briefing before TTS.

## compact / resume must not reset HEAD

SessionStart fires again on compact. If it rewrote `start.json`, the "before"
would become "now" and `diff.sh` would go quiet. The hook keeps the original
HEAD on `resume` and `compact`. Do not "fix" that.

## Installed mid-session

No `start.json` means the plugin was not loaded at the beginning. Taking
current `HEAD` as the before misses anything already committed in this
session. Ask before using it.

## The state directory is not a change

`diff.sh` ignores `.claude/` and `handoffs/`. `git ls-files --others` will
otherwise report `start.json` as a new file, and an empty session produces a
briefing of the plugin itself. SessionStart also appends
`.claude/session-handoff/` to `.git/info/exclude` (local, not committed) so
`git status` stays clean.

## The audio cannot live in tmp/ or in .claude/

`tmp/` gets wiped. `.claude/session-handoff/` is session state, local, not
something a teammate will open. The MP3 goes to `handoffs/` (or wherever
`output_dir` says), next to the work.

## Secrets

The transcript has tokens, `.env` values, private asides. None of that goes
in a beat. If the session should not leave the pair, do not assemble. `share:
ask` in the config is the default because this was too easy to get wrong.

## paths is a filter, not a guess

Without `paths`, every file the session touched is in scope — including a
drive-by README fix. If the shared artifact is `docs/canvas.md`, say so in
`session-handoff.json`.

## Untracked files

A `Write` of a new file does not show up in `git diff`. `diff.sh` adds those
from `git ls-files --others` (and from `touched.txt` when `paths` is empty).
If you only read `changes.diff` and skip `files.txt`, you will miss them.

## Windows line endings

The engine is bash. A clone with `core.autocrlf=true` gives every `.sh` a
CRLF, and bash dies on its own shebang. The repo's `.gitattributes` pins
`*.sh` to `lf`. If a hook fails with `'\r': command not found`, that is why.

## edge-tts needs a network

The voices are Microsoft Edge's service: no account, no API key, but not
offline. A failure whose last line is a traceback about the network is that,
not a bad briefing.

## Duration is a floor

A beat lasts as long as the voice does, plus a short breath. Setting
`"duration": 3` on a two-sentence narration does not cut it off. It also
does not make a long narration fit in three seconds.

## Two hosts is a trap

NotebookLM's two-presenter format is entertainment. A teammate catching up
wants one person, in first person, saying what they did. v1 is one voice.
