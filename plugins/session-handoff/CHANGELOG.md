# Changelog

## Unreleased

`make_brief.sh` can synthesise remotely. With `SESSION_HANDOFF_TTS_TOKEN` set it POSTs the
beats to the synthesis service and writes the MP3 it returns — only `curl` and `jq` needed,
no `edge-tts`, `ffmpeg` or `python3`. A 429, 503, 5xx or an unreachable service falls back to the local
engine (the service's `Retry-After` is shown); a rejected token stops instead of hiding the problem. Without a token nothing changes.
The engine test covers it against a local stub server.

`ENGINE_DIR` can be set by the caller (Windows wrappers running the script under process
substitution), as e2e-video-doc already allowed.

## 0.1.0

First release: the contract, the git recipe, the engine, the hooks that capture
and do not assemble.

The cut is the same one e2e-video-doc already makes. The conversation is the
source; the artifact is a briefing; the ground truth is the document diff.
SessionEnd is a `cp` of the transcript. The skill runs while the session is
still alive, so a human can read the JSON before TTS.

Shipped with an engine test that does not need Claude Code: `make_brief.sh` on
a fixture, SessionStart keeping HEAD across compact, `diff.sh` exit 2 on an
untouched tree.

The first engine run taught two things that went into the same cut: process
substitutions (`< <(git …)`) fail on some machines (`/dev/fd/63`), so `diff.sh`
writes temp files instead; and `git ls-files --others` will treat
`.claude/session-handoff/` as a change unless the recipe ignores it — without
that filter, an empty session produces a briefing of the plugin's own state.
