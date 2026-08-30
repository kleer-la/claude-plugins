#!/usr/bin/env bash
#
# Runs one flow end to end: capture, then assemble.
#
# Reads `e2e-video-doc.json` from the project root — the only thing you write per
# project. See reference/config.md.
#
# Usage:
#   bash run.sh <flow> [lang] [--assemble-only]
#   VOICE=es-CO-SalomeNeural bash run.sh checkout
#
# If the config declares `languages`, pass one to pick it. The capture step is re-run
# per language, because the interface has to be in the same language as the voice.

set -euo pipefail

FLOW="${1:?usage: run.sh <flow> [lang] [--assemble-only]}"
LANG_ARG=""
ASSEMBLE_ONLY=""
for arg in "${@:2}"; do
  case "$arg" in
    --assemble-only) ASSEMBLE_ONLY="yes" ;;
    *) LANG_ARG="$arg" ;;
  esac
done

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

# Languages are optional. Without them, {lang} and {lang_suffix} resolve to empty and
# everything behaves as a single-language project.
HAS_LANGS=$(jq -r 'if (.languages // {}) == {} then "no" else "yes" end' "$CONFIG")
if [ "$HAS_LANGS" = "yes" ]; then
  LANG_CODE="${LANG_ARG:-$(jq -r '.languages | keys_unsorted[0]' "$CONFIG")}"
  jq -e --arg l "$LANG_CODE" '.languages[$l]' "$CONFIG" >/dev/null 2>&1 || {
    echo "Language '$LANG_CODE' is not in $CONFIG. Defined:"
    jq -r '.languages | keys_unsorted[]' "$CONFIG" | sed 's/^/  - /'
    exit 1
  }
  LANG_SUFFIX=$(jq -r --arg l "$LANG_CODE" '.languages[$l].suffix // ""' "$CONFIG")
else
  [ -z "$LANG_ARG" ] || { echo "This config declares no languages, but '$LANG_ARG' was passed."; exit 1; }
  LANG_CODE=""
  LANG_SUFFIX=""
fi

subst() {
  local v="$1"
  v="${v//\{flow\}/$FLOW}"
  v="${v//\{lang_suffix\}/$LANG_SUFFIX}"
  v="${v//\{lang\}/$LANG_CODE}"
  echo "$v"
}

field() {
  # Flow override first, then the default, with the placeholders substituted.
  local key="$1" value
  value=$(jq -r --arg f "$FLOW" --arg k "$key" \
    '(.flows[$f][$k] // .defaults[$k] // empty)' "$CONFIG")
  [ -n "$value" ] || { echo "Missing '$key' for flow '$FLOW' in $CONFIG" >&2; exit 1; }
  subst "$value"
}

CAPTURE=$(field capture)
SCREENSHOTS="$ROOT/$(field screenshots)"
NARRATION="$ROOT/$(field narration)"
OUTPUT="$ROOT/$(field output)"
VOICE="${VOICE:-$(jq -r --arg f "$FLOW" --arg l "$LANG_CODE" \
  '(.languages[$l].voice // .flows[$f].voice // .defaults.voice // "en-US-JennyNeural")' "$CONFIG")}"

LABEL="$FLOW${LANG_CODE:+ ($LANG_CODE)}"

if [ -z "$ASSEMBLE_ONLY" ]; then
  echo "> $LABEL — capturing"
  ( cd "$ROOT" && eval "$CAPTURE" )
fi

echo "> $LABEL — narrating and assembling"
NARRATION="$NARRATION" SCREENSHOTS="$SCREENSHOTS" OUTPUT="$OUTPUT" VOICE="$VOICE" \
  bash "$ENGINE_DIR/make_video.sh"
