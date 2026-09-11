#!/usr/bin/env bash
# Append each written/edited project file to touched.txt. Fast; no I/O that
# can stall a Write. Paths outside the project, and the plugin's own state
# directory, are ignored.

set -u
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
[ -n "$cwd" ] || exit 0
[ -n "$path" ] || exit 0

case "$path" in
  /*) abs="$path" ;;
  *)  abs="$cwd/$path" ;;
esac

case "$abs" in
  "$cwd"|"$cwd"/*) ;;
  *) exit 0 ;;
esac

case "$abs" in
  */.claude/session-handoff/*|*/.claude/session-handoff) exit 0 ;;
esac

state="$cwd/.claude/session-handoff"
mkdir -p "$state" || exit 0
touched="$state/touched.txt"
touch "$touched"

rel="${abs#"$cwd"/}"
grep -qxF "$rel" "$touched" 2>/dev/null && exit 0
printf '%s\n' "$rel" >> "$touched"
exit 0
