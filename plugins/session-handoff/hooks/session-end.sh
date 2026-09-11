#!/usr/bin/env bash
# Copy the transcript next to the rest of the session state. Must finish in
# well under the SessionEnd budget (~1.5s). Does not assemble anything: a
# podcast on every /clear would be noise, and 1.5 seconds cannot run TTS.

set -u
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
[ -n "$cwd" ] || exit 0
[ -n "$transcript" ] || exit 0
[ -f "$transcript" ] || exit 0

state="$cwd/.claude/session-handoff"
mkdir -p "$state" || exit 0
cp -f "$transcript" "$state/transcript.jsonl" 2>/dev/null || true
exit 0
