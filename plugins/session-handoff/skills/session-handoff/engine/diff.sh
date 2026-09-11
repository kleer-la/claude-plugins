#!/usr/bin/env bash
#
# Ground truth of the session: what actually changed since SessionStart.
# The conversation is not this. Writes three files next to start.json:
#
#   changes.diff   unified diff + new files the walk captured
#   changes.stat   --stat plus a line per untracked file
#   files.txt      paths that changed, one per line
#
# Exit codes:
#   0  there are changes
#   1  error (no git, no start.json, no HEAD)
#   2  the working tree has not moved — no briefing to produce
#
# Usage:
#   bash diff.sh                  # cwd, or the nearest session-handoff state
#   bash diff.sh /path/to/project

set -euo pipefail

ROOT="${1:-$PWD}"
DIR="$ROOT"
while [ "$DIR" != "/" ] && [ ! -f "$DIR/.claude/session-handoff/start.json" ]; do
  DIR="$(dirname "$DIR")"
done
STATE="$DIR/.claude/session-handoff"
START="$STATE/start.json"
[ -f "$START" ] || { echo "No start.json under $ROOT. Was the plugin installed for this session?"; exit 1; }

command -v jq >/dev/null || { echo "jq is required to read start.json."; exit 1; }
command -v git >/dev/null || { echo "git is required for the v1 recipe."; exit 1; }

GIT_ROOT=$(jq -r '.git.root // empty' "$START")
HEAD=$(jq -r '.git.head // empty' "$START")
[ -n "$GIT_ROOT" ] && [ -n "$HEAD" ] || {
  echo "start.json has no git HEAD. This session is not in a repository, or git was missing at SessionStart."
  echo "The skill should say so and stop, rather than invent a briefing from the chat."
  exit 1
}

# Optional path filter from the project config.
CONFIG=""
CFG_DIR="$DIR"
while [ "$CFG_DIR" != "/" ] && [ ! -f "$CFG_DIR/session-handoff.json" ]; do
  CFG_DIR="$(dirname "$CFG_DIR")"
done
[ -f "$CFG_DIR/session-handoff.json" ] && CONFIG="$CFG_DIR/session-handoff.json"

PATHS=()
if [ -n "$CONFIG" ]; then
  jq -r '.paths[]? // empty' "$CONFIG" > "$STATE/paths.tmp"
  while IFS= read -r p; do
    [ -n "$p" ] && PATHS+=("$p")
  done < "$STATE/paths.tmp"
  rm -f "$STATE/paths.tmp"
fi

# Fall back to the files the session actually touched.
TOUCHED="$STATE/touched.txt"
if [ ${#PATHS[@]} -eq 0 ] && [ -f "$TOUCHED" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] && PATHS+=("$p")
  done < "$TOUCHED"
fi

stat_file="$STATE/changes.stat"
diff_file="$STATE/changes.diff"
files_file="$STATE/files.txt"
: > "$stat_file"
: > "$diff_file"
: > "$files_file"

git_args=(-C "$GIT_ROOT" --no-pager)
if [ ${#PATHS[@]} -eq 0 ]; then
  git "${git_args[@]}" diff --stat "$HEAD" -- > "$stat_file" || true
  git "${git_args[@]}" diff "$HEAD" -- > "$diff_file" || true
  git "${git_args[@]}" diff --name-only "$HEAD" -- >> "$files_file" || true
else
  git "${git_args[@]}" diff --stat "$HEAD" -- "${PATHS[@]}" > "$stat_file" || true
  git "${git_args[@]}" diff "$HEAD" -- "${PATHS[@]}" > "$diff_file" || true
  git "${git_args[@]}" diff --name-only "$HEAD" -- "${PATHS[@]}" >> "$files_file" || true
fi

# New files git diff will not show. Restrict to touched / configured paths.
# Plugin state and generated audio are never the shared artifact.
is_internal() {
  case "$1" in
    .claude|.claude/*|.claude\\*) return 0 ;;
    handoffs|handoffs/*) return 0 ;;
  esac
  return 1
}

is_in_scope() {
  local f="$1"
  is_internal "$f" && return 1
  if [ ${#PATHS[@]} -eq 0 ]; then return 0; fi
  local p
  for p in "${PATHS[@]}"; do
    case "$f" in
      "$p"|"$p"/*) return 0 ;;
    esac
  done
  return 1
}

untracked=0
git "${git_args[@]}" ls-files --others --exclude-standard > "$STATE/untracked.tmp"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  is_in_scope "$f" || continue
  echo "new file: $f" >> "$stat_file"
  {
    echo "--- /dev/null"
    echo "+++ b/$f"
    if [ -f "$GIT_ROOT/$f" ]; then
      # Skip obvious binaries; the skill can still name the file.
      if grep -Iq . "$GIT_ROOT/$f" 2>/dev/null; then
        echo "@@ new file @@"
        sed 's/^/+/' "$GIT_ROOT/$f"
      else
        echo "@@ binary or empty; not inlined @@"
      fi
    fi
  } >> "$diff_file"
  echo "$f" >> "$files_file"
  untracked=$((untracked + 1))
done < "$STATE/untracked.tmp"
rm -f "$STATE/untracked.tmp"

# Unique paths, drop empties.
if [ -s "$files_file" ]; then
  sort -u "$files_file" | sed '/^$/d' > "$files_file.tmp"
  mv "$files_file.tmp" "$files_file"
fi

CHANGED=$(wc -l < "$files_file" | tr -d ' ')
if [ "$CHANGED" -eq 0 ] && [ ! -s "$diff_file" ]; then
  echo "No changes since $HEAD. There is nothing to brief."
  exit 2
fi

echo "Changes since ${HEAD:0:8}: $CHANGED path(s)  ($stat_file)"
cat "$stat_file"
exit 0
