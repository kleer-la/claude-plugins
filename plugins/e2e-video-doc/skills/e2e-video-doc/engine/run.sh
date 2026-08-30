#!/usr/bin/env bash
#
# Runs one flow end to end: capture, then assemble.
#
# Reads `e2e-video-doc.json` from the project root — the only thing you write per
# project. See reference/config.md.
#
# Usage:
#   bash run.sh <flow> [--assemble-only]
#   VOICE=es-CO-SalomeNeural bash run.sh checkout

set -euo pipefail

FLOW="${1:?usage: run.sh <flow> [--assemble-only]}"
ASSEMBLE_ONLY="${2:-}"

ENGINE_DIR="$(cd "$(dirname "$0")" && pwd)"

# The config decides where the root is: searched upward from the cwd.
DIR="$PWD"
while [ "$DIR" != "/" ] && [ ! -f "$DIR/e2e-video-doc.json" ]; do
  DIR="$(dirname "$DIR")"
done
CONFIG="$DIR/e2e-video-doc.json"
[ -f "$CONFIG" ] || { echo "No e2e-video-doc.json found from $PWD upward."; exit 1; }
ROOT="$DIR"

jq -e --arg f "$FLOW" '.flows[$f]' "$CONFIG" >/dev/null 2>&1 || {
  echo "Flow '$FLOW' is not in $CONFIG. Defined:"
  jq -r '.flows | keys[]' "$CONFIG" | sed 's/^/  - /'
  exit 1
}

field() {
  # Flow override first, then the default, with {flow} substituted.
  local key="$1" value
  value=$(jq -r --arg f "$FLOW" --arg k "$key" \
    '(.flows[$f][$k] // .defaults[$k] // empty)' "$CONFIG")
  [ -n "$value" ] || { echo "Missing '$key' for flow '$FLOW' in $CONFIG" >&2; exit 1; }
  echo "${value//\{flow\}/$FLOW}"
}

CAPTURE=$(field capture)
SCREENSHOTS="$ROOT/$(field screenshots)"
NARRATION="$ROOT/$(field narration)"
OUTPUT="$ROOT/$(field output)"
VOICE="${VOICE:-$(jq -r --arg f "$FLOW" '(.flows[$f].voice // .defaults.voice // "en-US-JennyNeural")' "$CONFIG")}"

if [ "$ASSEMBLE_ONLY" != "--assemble-only" ]; then
  echo "> $FLOW — capturing"
  ( cd "$ROOT" && eval "$CAPTURE" )
fi

echo "> $FLOW — narrating and assembling"
NARRATION="$NARRATION" SCREENSHOTS="$SCREENSHOTS" OUTPUT="$OUTPUT" VOICE="$VOICE" \
  bash "$ENGINE_DIR/make_video.sh"
