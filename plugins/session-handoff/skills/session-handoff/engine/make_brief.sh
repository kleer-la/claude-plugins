#!/usr/bin/env bash
#
# Assembles a narrated MP3 from a briefing JSON.
#
# Knows nothing about your project: everything comes in through the environment.
# All it cares about is the contract — an object with a `beats` array, each beat
# carrying `narration`.
#
# Requires: edge-tts, ffmpeg, jq, python3. Check them with `bash check.sh`.
#
# Usage:
#   BRIEFING=briefing.json \
#   OUTPUT=handoffs/2026-09-11-pricing.mp3 \
#   VOICE=es-AR-ElenaNeural \
#     bash make_brief.sh

set -euo pipefail

BRIEFING_FILE="${BRIEFING:?set BRIEFING=<path to the briefing json>}"
OUTPUT="${OUTPUT:?set OUTPUT=<path of the output mp3>}"
VOICE="${VOICE:-es-AR-ElenaNeural}"
RATE="${RATE:-+8%}"

# ENGINE_DIR is taken from the caller when it sets one: a Windows wrapper running this
# under `bash <(tr -d '\r' < make_brief.sh)` (to survive a CRLF clone) makes $0 something
# like /dev/fd/63, and deriving the directory from it fails to find check.sh next to it —
# the same bug e2e-video-doc's make_video.sh hit on Windows (see 6cbb521).
ENGINE_DIR="${ENGINE_DIR:-$(cd "$(dirname "$0")" && pwd)}"
bash "$ENGINE_DIR/check.sh" --quiet

[ -f "$BRIEFING_FILE" ] || { echo "No such briefing file: $BRIEFING_FILE"; exit 1; }

jq -e '.beats | type == "array" and length > 0' "$BRIEFING_FILE" >/dev/null || {
  echo "Briefing is missing a non-empty .beats array: $BRIEFING_FILE"
  exit 1
}

WORKDIR=$(python3 -c "import os,sys; print(os.path.abspath(os.path.dirname(sys.argv[1]) or '.'))" "$OUTPUT")
AUDIO_DIR="$WORKDIR/.session-handoff-audio"
SEGMENTS_DIR="$WORKDIR/.session-handoff-segments"
TMP_ERR="$(mktemp)"
trap 'rm -f "$TMP_ERR"; rm -rf "$AUDIO_DIR" "$SEGMENTS_DIR"' EXIT

mkdir -p "$AUDIO_DIR" "$SEGMENTS_DIR" "$(dirname "$OUTPUT")"

abspath() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s/%s\n' "$(cd "$(dirname "$1")" && pwd -P)" "$(basename "$1")" ;;
  esac
}

audio_duration() {
  python3 - "$1" <<'PY'
import re, subprocess, sys
path = sys.argv[1]
p = subprocess.run(["ffmpeg", "-hide_banner", "-i", path], capture_output=True, text=True)
m = re.search(r"Duration: (\d+):(\d+):(\d+(?:\.\d+)?)", p.stderr or "")
if not m:
    sys.stderr.write("cannot read duration of %s\n" % path)
    sys.exit(1)
h, mi, s = int(m.group(1)), int(m.group(2)), float(m.group(3))
print(h * 3600 + mi * 60 + s)
PY
}

ENTRIES=$(jq '.beats | length' "$BRIEFING_FILE")
CONCAT_FILE="$SEGMENTS_DIR/concat.txt"
: > "$CONCAT_FILE"

echo "Building briefing"
echo "   Voice:     $VOICE"
echo "   Briefing:  $BRIEFING_FILE"
echo "   Output:    $OUTPUT"

MISSING=0
for i in $(seq 0 $((ENTRIES - 1))); do
  IDX=$(printf "%02d" $((i + 1)))
  KIND=$(jq -r ".beats[$i].kind // \"beat\"" "$BRIEFING_FILE")
  NARRATION_TEXT=$(jq -r ".beats[$i].narration // empty" "$BRIEFING_FILE")
  DURATION=$(jq -r ".beats[$i].duration // 0" "$BRIEFING_FILE")

  if [ -z "$NARRATION_TEXT" ]; then
    echo "  [$IDX] empty narration ($KIND) — skipped"
    MISSING=$((MISSING + 1))
    continue
  fi

  AUDIO="$AUDIO_DIR/${IDX}.mp3"
  SEGMENT="$SEGMENTS_DIR/${IDX}.mp3"

  echo "  [$IDX] $KIND  ${NARRATION_TEXT:0:70}"
  if ! edge-tts --voice "$VOICE" --rate "$RATE" --text "$NARRATION_TEXT" \
       --write-media "$AUDIO" 2>"$TMP_ERR"; then
    echo "edge-tts failed on beat $IDX. Usual causes: a voice name that does not exist" >&2
    echo "(list them with: edge-tts --list-voices | grep ${VOICE%%-*}); no network access;" >&2
    echo "or an install pointing at a Python that is gone." >&2
    tail -5 "$TMP_ERR" | sed 's/^/  /' >&2
    exit 1
  fi

  AUDIO_DURATION=$(audio_duration "$AUDIO")
  # duration is a floor. A short breath (0.35s) is added after every beat so
  # consecutive sentences do not run into each other.
  SEGMENT_DURATION=$(python3 -c "print(max($AUDIO_DURATION + 0.35, float('$DURATION')))")
  PAD=$(python3 -c "print(max(0.0, $SEGMENT_DURATION - $AUDIO_DURATION))")

  if ! ffmpeg -y -i "$AUDIO" -af "apad=pad_dur=$PAD" -c:a libmp3lame -q:a 4 \
        "$SEGMENT" 2>"$TMP_ERR"; then
    echo "ffmpeg failed padding beat $IDX." >&2
    tail -20 "$TMP_ERR" | sed 's/^/  /' >&2
    exit 1
  fi

  echo "file '$(abspath "$SEGMENT")'" >> "$CONCAT_FILE"
done

if [ ! -s "$CONCAT_FILE" ]; then
  echo "Nothing to concatenate: all $ENTRIES beats had empty narration."
  exit 1
fi

echo "Concatenating $((ENTRIES - MISSING)) beats..."
if ! ffmpeg -y -f concat -safe 0 -i "$CONCAT_FILE" -c:a libmp3lame -q:a 4 \
      "$OUTPUT" 2>"$TMP_ERR"; then
  echo "ffmpeg failed concatenating the beats." >&2
  tail -20 "$TMP_ERR" | sed 's/^/  /' >&2
  exit 1
fi

DUR=$(audio_duration "$OUTPUT")
DUR_S=$(python3 -c "print(int(round($DUR)))")
SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "Done: $OUTPUT  (${DUR_S}s, $SIZE)"
[ "$MISSING" -gt 0 ] && echo "Heads up: $MISSING beats had empty narration and are not in the audio."
if python3 -c "import sys; sys.exit(0 if $DUR > 300 else 1)"; then
  echo "Heads up: ${DUR_S}s is longer than five minutes. Split it, or the team will not finish it."
fi
exit 0
