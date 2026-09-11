#!/usr/bin/env bash
# Regression for the engine and the hooks. Needs no Claude Code session.
# Run from anywhere:
#   bash skills/session-handoff/engine/test.sh
#
# Exits 1 on the first failure. Speaks what it did.

set -euo pipefail

ENGINE_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$ENGINE_DIR/../../.." && pwd)"

echo "== check.sh"
bash "$ENGINE_DIR/check.sh"

echo "== make_brief.sh (fixture)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
BRIEFING="$PLUGIN_DIR/examples/fixture-briefing.json" \
  OUTPUT="$TMP/fixture.mp3" \
  VOICE=es-AR-ElenaNeural \
  bash "$ENGINE_DIR/make_brief.sh"
[ -f "$TMP/fixture.mp3" ] || { echo "no mp3 written"; exit 1; }
SIZE=$(wc -c < "$TMP/fixture.mp3" | tr -d ' ')
[ "$SIZE" -gt 1000 ] || { echo "mp3 too small: $SIZE bytes"; exit 1; }
echo "   fixture mp3: $SIZE bytes"

echo "== hooks: session-start, post-tool, compact does not reset HEAD"
REPO="$TMP/proj"
mkdir -p "$REPO/docs"
git -C "$REPO" init -q
git -C "$REPO" config user.email test@example.com
git -C "$REPO" config user.name test
echo "one" > "$REPO/docs/canvas.md"
git -C "$REPO" add docs/canvas.md
git -C "$REPO" commit -q -m first
HEAD=$(git -C "$REPO" rev-parse HEAD)

printf '{"session_id":"s1","cwd":"%s","source":"startup"}\n' "$REPO" \
  | bash "$PLUGIN_DIR/hooks/session-start.sh"
[ -f "$REPO/.claude/session-handoff/start.json" ] || { echo "start.json missing"; exit 1; }
GOT=$(jq -r '.git.head' "$REPO/.claude/session-handoff/start.json")
[ "$GOT" = "$HEAD" ] || { echo "HEAD mismatch: $GOT vs $HEAD"; exit 1; }

echo "two" >> "$REPO/docs/canvas.md"
printf '{"cwd":"%s","tool_input":{"file_path":"%s/docs/canvas.md"}}\n' "$REPO" "$REPO" \
  | bash "$PLUGIN_DIR/hooks/post-tool.sh"
grep -qx 'docs/canvas.md' "$REPO/.claude/session-handoff/touched.txt"

# compact must not take the new (dirty) tree as the baseline
printf '{"session_id":"s1","cwd":"%s","source":"compact"}\n' "$REPO" \
  | bash "$PLUGIN_DIR/hooks/session-start.sh"
GOT=$(jq -r '.git.head' "$REPO/.claude/session-handoff/start.json")
[ "$GOT" = "$HEAD" ] || { echo "compact reset HEAD to $GOT"; exit 1; }

echo "== diff.sh sees the change"
bash "$ENGINE_DIR/diff.sh" "$REPO" >/dev/null
grep -q 'docs/canvas.md' "$REPO/.claude/session-handoff/files.txt"
grep -q '+two' "$REPO/.claude/session-handoff/changes.diff"

echo "== diff.sh exit 2 when nothing changed"
REPO2="$TMP/clean"
mkdir -p "$REPO2"
git -C "$REPO2" init -q
git -C "$REPO2" config user.email test@example.com
git -C "$REPO2" config user.name test
echo "x" > "$REPO2/a.md"
git -C "$REPO2" add a.md
git -C "$REPO2" commit -q -m first
printf '{"session_id":"s2","cwd":"%s","source":"startup"}\n' "$REPO2" \
  | bash "$PLUGIN_DIR/hooks/session-start.sh"
set +e
bash "$ENGINE_DIR/diff.sh" "$REPO2" >/dev/null
code=$?
set -e
[ "$code" -eq 2 ] || { echo "expected exit 2, got $code"; exit 1; }

echo "== session-end copies a transcript"
printf '{"cwd":"%s","transcript_path":"%s"}\n' "$REPO" "$REPO/docs/canvas.md" \
  | bash "$PLUGIN_DIR/hooks/session-end.sh"
[ -f "$REPO/.claude/session-handoff/transcript.jsonl" ] || { echo "transcript not copied"; exit 1; }

echo "All engine and hook checks passed."
exit 0
