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

# Checked by running them, not by `command -v`. A tool can be on PATH and still be
# unusable: a Homebrew Python upgrade leaves edge-tts behind with a shebang pointing at an
# interpreter that no longer exists, and `command -v` happily finds that file. Existing and
# working are different questions, and only the second one matters here.
check() {
  case "$1" in
    edge-tts) edge-tts --help ;;
    ffmpeg)   ffmpeg -version ;;
    ffprobe)  ffprobe -version ;;
    jq)       jq --version ;;
    python3)  python3 --version ;;
  esac >/dev/null 2>&1
}

for cmd in edge-tts ffmpeg ffprobe jq python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing: $cmd"
    case $cmd in
      edge-tts) echo "  Install: pipx install edge-tts (or pip install edge-tts)" ;;
      ffmpeg|ffprobe) echo "  Install: $PKG ffmpeg" ;;
      jq)       echo "  Install: $PKG jq" ;;
      python3)  echo "  Install: $PKG python3" ;;
    esac
    exit 1
  elif ! check "$cmd"; then
    echo "On PATH but will not run: $cmd  ($(command -v "$cmd"))"
    case $cmd in
      edge-tts) echo "  Usually a Python it was installed against is gone. Reinstall:" ;
                echo "    pipx install --force edge-tts   # its own venv, survives Python upgrades" ;
                echo "  If a reinstall did not help, an older copy may be shadowing it:" ;
                echo "    which -a edge-tts   # remove the stale one, then: hash -r" ;;
      *)        echo "  Reinstall it: $PKG $cmd" ;;
    esac
    exit 1
  fi
done

[ -f "$NARRATION_FILE" ] || { echo "No such narration file: $NARRATION_FILE"; exit 1; }
[ -d "$SCREENSHOTS_DIR" ] || { echo "No such screenshots directory: $SCREENSHOTS_DIR"; exit 1; }

TMP_ERR="$(mktemp)"
trap 'rm -f "$TMP_ERR"' EXIT

echo "Building video"
echo "   Voice:       $VOICE"
echo "   Narration:   $NARRATION_FILE"
echo "   Screenshots: $SCREENSHOTS_DIR"
# Said up front, so it is known before the first TTS call rather than only on success.
echo "   Output:      $OUTPUT"

# `$(dirname "$OUTPUT")`: the mp4 usually lands outside the screenshots directory —
# see reference/gotchas.md, "the video cannot live in tmp/".
mkdir -p "$AUDIO_DIR" "$SEGMENTS_DIR" "$(dirname "$OUTPUT")"

# Not realpath: it is GNU coreutils and macOS does not ship it. Failing inside a command
# substitution it also produced an empty string rather than an error, so the concat list
# filled up with blank entries and ffmpeg complained about the list instead of the cause.
abspath() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s/%s\n' "$(cd "$(dirname "$1")" && pwd -P)" "$(basename "$1")" ;;
  esac
}

# Resolved once, here: ffmpeg's concat demuxer resolves paths against the list file rather
# than the working directory, so everything written into it has to be absolute.
SEGMENTS_DIR="$(abspath "$SEGMENTS_DIR")"

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
  # stderr is kept, not discarded: edge-tts reaches the network, and a failure here used
  # to end the run in silence — the last thing on screen was this line, with no error and
  # no file. Quiet on success, loud on failure.
  if ! edge-tts --voice "$VOICE" --rate "$RATE" --text "$NARRATION_TEXT" \
       --write-media "$AUDIO" 2>"$TMP_ERR"; then
    echo "edge-tts failed on entry $IDX. Usual causes: a voice name that does not exist" >&2
    echo "(list them with: edge-tts --list-voices | grep ${VOICE%%-*}); no network access;" >&2
    echo "or an install pointing at a Python that is gone." >&2
    # The last lines, not all of them: a Python traceback is thirty lines whose final one
    # is the whole answer.
    tail -5 "$TMP_ERR" | sed 's/^/  /' >&2
    exit 1
  fi

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
    "$SEGMENT" 2>"$TMP_ERR" || {
      echo "ffmpeg failed building segment $IDX from $SCREENSHOT." >&2
      tail -20 "$TMP_ERR" | sed 's/^/  /' >&2
      exit 1
    }

  echo "file '$SEGMENT'" >> "$CONCAT_FILE"
done

# Without this guard ffmpeg gets an empty list and returns its own error instead of
# saying what actually happened: there were no screenshots.
if [ ! -s "$CONCAT_FILE" ]; then
  echo "Nothing to concatenate: all $ENTRIES screenshots are missing."
  echo "Did the capture step run before this?"
  exit 1
fi

echo "Concatenating $((ENTRIES - MISSING)) segments..."
ffmpeg -y -f concat -safe 0 -i "$CONCAT_FILE" -c copy "$OUTPUT" 2>"$TMP_ERR" || {
  echo "ffmpeg failed concatenating the segments." >&2
  tail -20 "$TMP_ERR" | sed 's/^/  /' >&2
  exit 1
}

rm -rf "$AUDIO_DIR" "$SEGMENTS_DIR"

DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUTPUT" | cut -d. -f1)
SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "Done: $OUTPUT  (${DUR}s, $SIZE)"
[ "$MISSING" -gt 0 ] && echo "Heads up: $MISSING screenshots were missing and are not in the video."
exit 0
