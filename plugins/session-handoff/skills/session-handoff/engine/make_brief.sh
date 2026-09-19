#!/usr/bin/env bash
#
# Assembles a narrated MP3 from a briefing JSON.
#
# Knows nothing about your project: everything comes in through the environment.
# All it cares about is the contract — an object with a `beats` array, each beat
# carrying `narration`.
#
# Two ways to synthesise:
#   remote  SESSION_HANDOFF_TTS_TOKEN is set: the beats go to the synthesis service and
#           one finished MP3 comes back. Needs only curl and jq. Tried first.
#   local   edge-tts, ffmpeg, jq, python3 (check them with `bash check.sh`). Used when there
#           is no token, or the service is unreachable, over its limits (429) or down
#           (5xx). A rejected token (401) or a refused briefing (other 4xx) stops here
#           instead: falling back would hide a configuration problem.
# SESSION_HANDOFF_TTS_URL overrides the service address.
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

[ -f "$BRIEFING_FILE" ] || { echo "No such briefing file: $BRIEFING_FILE"; exit 1; }

# jq is the one tool both paths need; check.sh says how to install it.
command -v jq >/dev/null 2>&1 || bash "$ENGINE_DIR/check.sh" --quiet

jq -e '.beats | type == "array" and length > 0' "$BRIEFING_FILE" >/dev/null || {
  echo "Briefing is missing a non-empty .beats array: $BRIEFING_FILE"
  exit 1
}

TTS_URL="${SESSION_HANDOFF_TTS_URL:-https://eventos.kleer.la/api/tts/briefing}"

# 0 = MP3 written, 1 = stop (bad token / refused briefing), 2 = unavailable, use the local engine.
remote_brief() {
  command -v curl >/dev/null 2>&1 || { echo "curl is not installed; cannot reach the synthesis service." >&2; return 2; }
  local body hdrs part="$OUTPUT.part" code=000 rc=2 retry
  body=$(mktemp); hdrs=$(mktemp)
  mkdir -p "$(dirname "$OUTPUT")"

  # The service caps duration at 0-60 s per beat; a larger floor buys nothing.
  jq -c --arg voice "$VOICE" --arg rate "$RATE" '{
    voice: $voice, rate: $rate,
    beats: [.beats[] | select((.narration // "") != "")
            | {narration, duration: ([([.duration // 0, 0] | max), 60] | min)}]
  }' "$BRIEFING_FILE" > "$body"

  echo "Building briefing (remote)"
  echo "   Voice:     $VOICE"
  echo "   Briefing:  $BRIEFING_FILE"
  echo "   Output:    $OUTPUT"

  # The token goes to curl on stdin, not argv, so it does not show in `ps`.
  code=$(printf 'header = "Authorization: Bearer %s"\n' "$SESSION_HANDOFF_TTS_TOKEN" \
    | curl -sS --max-time 90 -K - -X POST "$TTS_URL" -H 'Content-Type: application/json' \
        --data-binary @"$body" -D "$hdrs" -o "$part" -w '%{http_code}') || code=000

  case "$code" in
    200)
      if [ -s "$part" ]; then
        mv "$part" "$OUTPUT"; rc=0
      else
        echo "The synthesis service answered 200 with no audio." >&2
      fi ;;
    401|403)
      echo "The synthesis service rejected SESSION_HANDOFF_TTS_TOKEN (HTTP $code). Check it, or generate a new one." >&2
      rc=1 ;;
    429|503)
      retry=$(sed -n 's/^[Rr]etry-[Aa]fter: *\([0-9]*\).*/\1/p' "$hdrs" | head -1)
      echo "The synthesis service is busy or switched off (HTTP $code${retry:+, retry after ${retry}s})." >&2 ;;
    4??)
      echo "The synthesis service refused the briefing (HTTP $code): $(jq -r '.error // empty' "$part" 2>/dev/null)" >&2
      rc=1 ;;
    *)
      echo "The synthesis service is unavailable (HTTP $code)." >&2 ;;
  esac
  rm -f "$body" "$hdrs" "$part"
  return "$rc"
}

if [ -n "${SESSION_HANDOFF_TTS_TOKEN:-}" ]; then
  remote_rc=0
  remote_brief || remote_rc=$?
  if [ "$remote_rc" -eq 0 ]; then
    SIZE=$(du -h "$OUTPUT" | cut -f1)
    DUR=""
    if command -v ffmpeg >/dev/null 2>&1; then
      DUR=$(ffmpeg -hide_banner -i "$OUTPUT" 2>&1 | sed -n 's/.*Duration: \([0-9:.]*\).*/\1/p' | head -1) || true
    fi
    echo "Done: $OUTPUT  (${DUR:+$DUR, }$SIZE, remote)"
    exit 0
  fi
  [ "$remote_rc" -eq 1 ] && exit 1
  echo "Using the local engine instead." >&2
fi

bash "$ENGINE_DIR/check.sh" --quiet

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
