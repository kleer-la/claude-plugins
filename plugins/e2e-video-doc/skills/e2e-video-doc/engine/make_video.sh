#!/usr/bin/env bash
#
# Assembles a narrated video from numbered screenshots + a narration JSON.
#
# Knows nothing about your project: everything comes in through the environment. All it
# cares about is the contract — `NN_name.png` files in a directory, and a JSON with the
# narration.
#
# Requires: edge-tts (pip), ffmpeg/ffprobe, jq, python3.
#   On Windows these are not on the host. See make_videos.ps1 (capture on Windows,
#   assemble in WSL).
#
# Usage:
#   NARRATION=scripts/checkout_narration.json \
#   SCREENSHOTS=tmp/video/checkout \
#   OUTPUT=public/videos/checkout.mp4 \
#   VOICE=en-US-JennyNeural \
#     bash make_video.sh

set -euo pipefail

NARRATION_FILE="${NARRATION:?set NARRATION=<path to the narration json>}"
SCREENSHOTS_DIR="${SCREENSHOTS:?set SCREENSHOTS=<directory of PNGs>}"
OUTPUT="${OUTPUT:?set OUTPUT=<path of the output mp4>}"
VOICE="${VOICE:-en-US-JennyNeural}"
RATE="${RATE:-+0%}"

AUDIO_DIR="$SCREENSHOTS_DIR/audio"
SEGMENTS_DIR="$SCREENSHOTS_DIR/segments"

# The hint leads with the package manager the reader actually has: being told to
# `apt install` on a Mac is one more translation between them and a working command.
case "$(uname -s)" in
  Darwin) PKG="brew install" ;;
  *)      PKG="apt install" ;;
esac

for cmd in edge-tts ffmpeg ffprobe jq python3; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Missing: $cmd"
    case $cmd in
      edge-tts) echo "  Install: pip install edge-tts" ;;
      ffmpeg|ffprobe) echo "  Install: $PKG ffmpeg" ;;
      jq)       echo "  Install: $PKG jq" ;;
      python3)  echo "  Install: $PKG python3" ;;
    esac
    exit 1
  fi
done

[ -f "$NARRATION_FILE" ] || { echo "No such narration file: $NARRATION_FILE"; exit 1; }
[ -d "$SCREENSHOTS_DIR" ] || { echo "No such screenshots directory: $SCREENSHOTS_DIR"; exit 1; }

echo "Building video"
echo "   Voice:       $VOICE"
echo "   Narration:   $NARRATION_FILE"
echo "   Screenshots: $SCREENSHOTS_DIR"

# `$(dirname "$OUTPUT")`: the mp4 usually lands outside the screenshots directory —
# see reference/gotchas.md, "the video cannot live in tmp/".
mkdir -p "$AUDIO_DIR" "$SEGMENTS_DIR" "$(dirname "$OUTPUT")"

ENTRIES=$(jq length "$NARRATION_FILE")
CONCAT_FILE="$SEGMENTS_DIR/concat.txt"
: > "$CONCAT_FILE"

MISSING=0
for i in $(seq 0 $((ENTRIES - 1))); do
  IDX=$(printf "%02d" $((i + 1)))
  SCREENSHOT=$(jq -r ".[$i].screenshot" "$NARRATION_FILE")
  DURATION=$(jq -r ".[$i].duration" "$NARRATION_FILE")
  NARRATION_TEXT=$(jq -r ".[$i].narration" "$NARRATION_FILE")

  IMG="$SCREENSHOTS_DIR/$SCREENSHOT"
  AUDIO="$AUDIO_DIR/${IDX}.mp3"
  SEGMENT="$SEGMENTS_DIR/${IDX}.mp4"

  if [ ! -f "$IMG" ]; then
    echo "  missing screenshot: $SCREENSHOT — skipped"
    MISSING=$((MISSING + 1))
    continue
  fi

  echo "  [$IDX] ${NARRATION_TEXT:0:60}..."
  edge-tts --voice "$VOICE" --rate "$RATE" --text "$NARRATION_TEXT" --write-media "$AUDIO" 2>/dev/null

  # The segment lasts as long as the voice does, not as long as the JSON says:
  # `duration` is a floor, not a value. If the narration runs long, the image follows.
  AUDIO_DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$AUDIO")
  SEGMENT_DURATION=$(python3 -c "print(max($AUDIO_DURATION + 0.5, $DURATION))")

  ffmpeg -y -loop 1 -i "$IMG" -i "$AUDIO" \
    -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=white" \
    -c:v libx264 -tune stillimage -pix_fmt yuv420p \
    -c:a aac -b:a 128k \
    -t "$SEGMENT_DURATION" \
    -shortest \
    "$SEGMENT" 2>/dev/null

  # realpath: SCREENSHOTS may arrive relative, and ffmpeg's concat resolves paths
  # against the list file, not against the cwd.
  echo "file '$(realpath "$SEGMENT")'" >> "$CONCAT_FILE"
done

# Without this guard ffmpeg gets an empty list and returns its own error instead of
# saying what actually happened: there were no screenshots.
if [ ! -s "$CONCAT_FILE" ]; then
  echo "Nothing to concatenate: all $ENTRIES screenshots are missing."
  echo "Did the capture step run before this?"
  exit 1
fi

echo "Concatenating $((ENTRIES - MISSING)) segments..."
ffmpeg -y -f concat -safe 0 -i "$CONCAT_FILE" -c copy "$OUTPUT" 2>/dev/null

rm -rf "$AUDIO_DIR" "$SEGMENTS_DIR"

DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUTPUT" | cut -d. -f1)
SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "Done: $OUTPUT  (${DUR}s, $SIZE)"
[ "$MISSING" -gt 0 ] && echo "Heads up: $MISSING screenshots were missing and are not in the video."
exit 0
