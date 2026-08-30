#!/usr/bin/env bash
#
# Genera placa de apertura y de cierre (1920x1080 PNG) con ffmpeg.
# Sin marca de ningún producto: el texto y los colores vienen por entorno.
#
#   TITULO="Mi Producto" SUB1="Alta de un pedido" \
#   CIERRE="¡Gracias!" CIERRE_SUB1="miproducto.com" \
#     bash generate_title_cards.sh tmp/video/alta
#
# Después referenciá 00_opening.png y 99_closing.png en el JSON de narración.

set -euo pipefail

OUT_DIR="${1:?uso: generate_title_cards.sh <directorio de capturas>}"
mkdir -p "$OUT_DIR"

TITULO="${TITULO:-}"
SUB1="${SUB1:-}"
SUB2="${SUB2:-}"
CIERRE="${CIERRE:-¡Gracias!}"
CIERRE_SUB1="${CIERRE_SUB1:-}"
CIERRE_SUB2="${CIERRE_SUB2:-}"
FONDO="${FONDO:-0x1a2332}"
TINTA="${TINTA:-white}"

# Fuente con cobertura amplia si está; si no, la default de ffmpeg.
FONT_FILE=""
for f in \
  "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc" \
  "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc" \
  "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf" \
  "/System/Library/Fonts/PingFang.ttc"; do
  [ -f "$f" ] && { FONT_FILE="$f"; break; }
done
fuente() { [ -n "$FONT_FILE" ] && echo ":fontfile='$FONT_FILE'" || echo ""; }

placa() {
  local destino="$1" t="$2" s1="$3" s2="$4"
  local filtros="drawtext=text='${t//\'/}':fontcolor=$TINTA:fontsize=110$(fuente):x=(w-text_w)/2:y=(h-text_h)/2-120"
  [ -n "$s1" ] && filtros="$filtros,drawtext=text='${s1//\'/}':fontcolor=$TINTA:fontsize=52$(fuente):x=(w-text_w)/2:y=(h-text_h)/2+40"
  [ -n "$s2" ] && filtros="$filtros,drawtext=text='${s2//\'/}':fontcolor=$TINTA:fontsize=52$(fuente):x=(w-text_w)/2:y=(h-text_h)/2+120"
  ffmpeg -y -f lavfi -i "color=c=$FONDO:s=1920x1080:d=1" -vf "$filtros" -frames:v 1 "$destino" 2>/dev/null
}

[ -n "$TITULO" ] && { placa "$OUT_DIR/00_opening.png" "$TITULO" "$SUB1" "$SUB2"; echo "  $OUT_DIR/00_opening.png"; }
placa "$OUT_DIR/99_closing.png" "$CIERRE" "$CIERRE_SUB1" "$CIERRE_SUB2"
echo "  $OUT_DIR/99_closing.png"
