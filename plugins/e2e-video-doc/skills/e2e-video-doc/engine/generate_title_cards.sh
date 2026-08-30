#!/usr/bin/env bash
#
# Generates opening and closing title cards (1920x1080 PNG) with ffmpeg.
# No product branding: text and colors come from the environment.
#
#   TITLE="My Product" SUB1="Placing an order" \
#   CLOSING="Thanks!" CLOSING_SUB1="myproduct.com" \
#     bash generate_title_cards.sh tmp/video/checkout
#
# Then reference 00_opening.png and 99_closing.png in the narration JSON.

set -euo pipefail

OUT_DIR="${1:?usage: generate_title_cards.sh <screenshots directory>}"
mkdir -p "$OUT_DIR"

TITLE="${TITLE:-}"
SUB1="${SUB1:-}"
SUB2="${SUB2:-}"
CLOSING="${CLOSING:-Thanks!}"
CLOSING_SUB1="${CLOSING_SUB1:-}"
CLOSING_SUB2="${CLOSING_SUB2:-}"
BACKGROUND="${BACKGROUND:-0x1a2332}"
INK="${INK:-white}"

# A font with wide coverage if present; otherwise ffmpeg's default.
FONT_FILE=""
for f in \
  "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc" \
  "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc" \
  "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf" \
  "/System/Library/Fonts/PingFang.ttc"; do
  [ -f "$f" ] && { FONT_FILE="$f"; break; }
done
font() { [ -n "$FONT_FILE" ] && echo ":fontfile='$FONT_FILE'" || echo ""; }

card() {
  local target="$1" t="$2" s1="$3" s2="$4"
  local filters="drawtext=text='${t//\'/}':fontcolor=$INK:fontsize=110$(font):x=(w-text_w)/2:y=(h-text_h)/2-120"
  [ -n "$s1" ] && filters="$filters,drawtext=text='${s1//\'/}':fontcolor=$INK:fontsize=52$(font):x=(w-text_w)/2:y=(h-text_h)/2+40"
  [ -n "$s2" ] && filters="$filters,drawtext=text='${s2//\'/}':fontcolor=$INK:fontsize=52$(font):x=(w-text_w)/2:y=(h-text_h)/2+120"
  ffmpeg -y -f lavfi -i "color=c=$BACKGROUND:s=1920x1080:d=1" -vf "$filters" -frames:v 1 "$target" 2>/dev/null
}

[ -n "$TITLE" ] && { card "$OUT_DIR/00_opening.png" "$TITLE" "$SUB1" "$SUB2"; echo "  $OUT_DIR/00_opening.png"; }
card "$OUT_DIR/99_closing.png" "$CLOSING" "$CLOSING_SUB1" "$CLOSING_SUB2"
echo "  $OUT_DIR/99_closing.png"
