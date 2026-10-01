#!/usr/bin/env bash
#
# Compares two capture runs of the same flow, frame by frame, to see which numbered
# screens moved before deciding whether the narration still matches what is on screen.
#
# `assertInFrame` validates one PNG at the moment it is shot; nothing compares two runs
# against each other. `videos/` and `tmp/` are gitignored, so there is no committed
# baseline — keep the previous run's screenshot directory aside (e.g. a copy to
# `tmp/video_screenshots/checkout_en_before`) before recapturing, then point this at the
# two directories.
#
# Matches files by name (NN_name.png) and scores each pair with ffmpeg's own SSIM filter
# — 1.0 is identical, lower is more different. No new dependency: ffmpeg is already
# required to assemble the video.
#
# Usage:
#   bash diff_frames.sh <before_dir> <after_dir> [threshold]
#
#   threshold   SSIM below this is flagged as DIFFERS. Default 0.999.
#
# This score is of the WHOLE frame, so a small content change scores closer to "same"
# than you would expect: on the sample app, changing one product's price — visible in a
# five-row catalogue table, a cart total and a confirmation card — moved three of the six
# checkout frames to 0.9975-0.9981 and the other three only to 0.9993-0.9997, because
# there the changed text is a small part of a mostly-unchanged page. Two independent,
# unmodified captures of the same screen scored exactly 1.000000 in that same run, with
# no measured noise floor to stay above — but that was a deterministic headless app; a
# project with a clock, an animation or font hinting that varies between runs may not be
# that quiet, and the right threshold for it is not this one. Before trusting any number
# here, run this once between two captures where nothing changed and see what "same"
# actually scores on your app. The threshold only decides what gets a DIFFERS label —
# every score is printed regardless, and reading them is the part that does not lie.
#
# Exit codes:
#   0  every matching frame is at or above the threshold, and both sides have the same files
#   1  at least one frame differs beyond the threshold, a frame exists on only one side,
#      or a pair could not be compared (e.g. its dimensions changed)

set -euo pipefail

BEFORE="${1:?usage: diff_frames.sh <before_dir> <after_dir> [threshold]}"
AFTER="${2:?usage: diff_frames.sh <before_dir> <after_dir> [threshold]}"
THRESHOLD="${3:-0.999}"

[ -d "$BEFORE" ] || { echo "No such directory: $BEFORE"; exit 1; }
[ -d "$AFTER" ] || { echo "No such directory: $AFTER"; exit 1; }
command -v ffmpeg >/dev/null || { echo "ffmpeg is required. Check it with check.sh."; exit 1; }

TMP_ERR="$(mktemp)"
trap 'rm -f "$TMP_ERR"' EXIT

# Every NN_name.png on either side, de-duplicated, in name order — so a frame missing
# from one side still shows up instead of being silently skipped.
# A `while read` loop, not `mapfile`: that needs bash 4+, and macOS's own bash is 3.2.
FILES=()
while IFS= read -r f; do
  FILES+=("$f")
done < <(
  { ls "$BEFORE" 2>/dev/null; ls "$AFTER" 2>/dev/null; } |
    grep -E '^[0-9]{2}_.*\.png$' | sort -u
)
[ "${#FILES[@]}" -gt 0 ] || { echo "No NN_name.png files in either directory."; exit 1; }

STATUS=0
for f in "${FILES[@]}"; do
  A="$BEFORE/$f"
  B="$AFTER/$f"

  if [ ! -f "$A" ]; then
    echo "  $f  only in $(basename "$AFTER")"
    STATUS=1
    continue
  fi
  if [ ! -f "$B" ]; then
    echo "  $f  only in $(basename "$BEFORE")"
    STATUS=1
    continue
  fi

  ffmpeg -y -i "$A" -i "$B" -lavfi ssim -f null - >/dev/null 2>"$TMP_ERR" || true
  # PNGs compare on R/G/B, screenshots from a browser on Y/U/V — "All:" is the field
  # that exists either way. Its absence (wrong dimensions, a corrupt PNG) means the
  # filter never ran, which is itself worth flagging rather than silently skipping.
  # `-o`, not `-P`: macOS's grep has no PCRE support, and this plugin runs there.
  SSIM=$(grep -o 'All:[0-9.]*' "$TMP_ERR" | tail -1 | cut -d: -f2)
  if [ -z "$SSIM" ]; then
    echo "  $f  could not compare — $(tail -1 "$TMP_ERR")"
    STATUS=1
    continue
  fi

  if python3 -c "exit(0 if $SSIM < $THRESHOLD else 1)"; then
    echo "  $f  DIFFERS  (ssim $SSIM)"
    STATUS=1
  else
    echo "  $f  same     (ssim $SSIM)"
  fi
done

exit $STATUS
