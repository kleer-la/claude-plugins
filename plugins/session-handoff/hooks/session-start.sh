#!/usr/bin/env bash
# Snapshot the "before" of this session: git HEAD, time, cwd.
# Resume and compact must not reset the HEAD — that is the whole point of
# taking it now rather than reconstructing it at the end.
#
# Writes: <cwd>/.claude/session-handoff/start.json
# No-ops without jq rather than breaking the session.

set -u
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')
source=$(printf '%s' "$input" | jq -r '.source // "startup"')
[ -n "$cwd" ] || exit 0

state="$cwd/.claude/session-handoff"
mkdir -p "$state" || exit 0
start="$state/start.json"

# compact / resume are the same working session. Keep the original HEAD.
if [ -f "$start" ]; then
  case "$source" in
    resume|compact)
      jq --arg src "$source" '.last_seen_source = $src' "$start" > "$start.tmp" 2>/dev/null \
        && mv "$start.tmp" "$start"
      exit 0
      ;;
  esac
fi

git_root=""
git_head=""
git_branch=""
if command -v git >/dev/null 2>&1; then
  git_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$git_root" ]; then
    git_head=$(git -C "$git_root" rev-parse HEAD 2>/dev/null || true)
    git_branch=$(git -C "$git_root" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  fi
fi

started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

jq -n \
  --arg sid "$session_id" \
  --arg cwd "$cwd" \
  --arg src "$source" \
  --arg at "$started_at" \
  --arg root "$git_root" \
  --arg head "$git_head" \
  --arg branch "$git_branch" \
  '{
    session_id: $sid,
    cwd: $cwd,
    source: $src,
    started_at: $at,
    git: (if $root == "" then null else {root: $root, head: $head, branch: $branch} end)
  }' > "$start"

# A new session (startup / clear) starts a new touched list.
: > "$state/touched.txt"

# Local exclude so `git status` is not the plugin's state directory.
# .git/info/exclude is not committed.
if [ -n "$git_root" ] && [ -d "$git_root/.git/info" ]; then
  exclude="$git_root/.git/info/exclude"
  if ! grep -qxF '.claude/session-handoff/' "$exclude" 2>/dev/null; then
    printf '%s\n' '.claude/session-handoff/' >> "$exclude"
  fi
fi
exit 0
