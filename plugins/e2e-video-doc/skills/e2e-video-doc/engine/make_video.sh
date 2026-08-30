#!/usr/bin/env bash
#
# Arma un video narrado a partir de screenshots numerados + un JSON de narración.
#
# No sabe nada del proyecto: recibe todo por entorno. Lo único que le importa es el
# contrato — PNGs `NN_nombre.png` en un directorio, y un JSON con la narración.
#
# Requisitos: edge-tts (pip), ffmpeg/ffprobe, jq, python3.
#   En Windows: no corren en el host. Ver make_videos.ps1 (captura en Windows,
#   arma en WSL).
#
# Uso:
#   NARRATION=scripts/alta_narration.json \
#   SCREENSHOTS=tmp/video/alta \
#   OUTPUT=public/videos/alta.mp4 \
#   VOICE=es-AR-ElenaNeural \
#     bash make_video.sh

set -euo pipefail

NARRATION_FILE="${NARRATION:?falta NARRATION=<ruta al json de narración>}"
SCREENSHOTS_DIR="${SCREENSHOTS:?falta SCREENSHOTS=<directorio de PNGs>}"
OUTPUT="${OUTPUT:?falta OUTPUT=<ruta del mp4 de salida>}"
VOICE="${VOICE:-es-AR-ElenaNeural}"
RATE="${RATE:-+0%}"

AUDIO_DIR="$SCREENSHOTS_DIR/audio"
SEGMENTS_DIR="$SCREENSHOTS_DIR/segments"

for cmd in edge-tts ffmpeg ffprobe jq python3; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Falta: $cmd"
    case $cmd in
      edge-tts) echo "  Instalar: pip install edge-tts" ;;
      ffmpeg|ffprobe) echo "  Instalar: apt install ffmpeg (o brew install ffmpeg)" ;;
      jq)       echo "  Instalar: apt install jq (o brew install jq)" ;;
      python3)  echo "  Instalar: apt install python3" ;;
    esac
    exit 1
  fi
done

[ -f "$NARRATION_FILE" ] || { echo "No existe la narración: $NARRATION_FILE"; exit 1; }
[ -d "$SCREENSHOTS_DIR" ] || { echo "No existe el directorio de capturas: $SCREENSHOTS_DIR"; exit 1; }

echo "Armando video"
echo "   Voz:        $VOICE"
echo "   Narración:  $NARRATION_FILE"
echo "   Capturas:   $SCREENSHOTS_DIR"

# `$(dirname "$OUTPUT")`: el mp4 suele salir fuera del directorio de capturas —
# ver reference/gotchas.md, "el video no puede vivir en tmp/".
mkdir -p "$AUDIO_DIR" "$SEGMENTS_DIR" "$(dirname "$OUTPUT")"

ENTRIES=$(jq length "$NARRATION_FILE")
CONCAT_FILE="$SEGMENTS_DIR/concat.txt"
: > "$CONCAT_FILE"

FALTANTES=0
for i in $(seq 0 $((ENTRIES - 1))); do
  IDX=$(printf "%02d" $((i + 1)))
  SCREENSHOT=$(jq -r ".[$i].screenshot" "$NARRATION_FILE")
  DURATION=$(jq -r ".[$i].duration" "$NARRATION_FILE")
  NARRACION=$(jq -r ".[$i].narration" "$NARRATION_FILE")

  IMG="$SCREENSHOTS_DIR/$SCREENSHOT"
  AUDIO="$AUDIO_DIR/${IDX}.mp3"
  SEGMENT="$SEGMENTS_DIR/${IDX}.mp4"

  if [ ! -f "$IMG" ]; then
    echo "  falta la captura: $SCREENSHOT — se saltea"
    FALTANTES=$((FALTANTES + 1))
    continue
  fi

  echo "  [$IDX] ${NARRACION:0:60}..."
  edge-tts --voice "$VOICE" --rate "$RATE" --text "$NARRACION" --write-media "$AUDIO" 2>/dev/null

  # El segmento dura lo que dure la voz, no lo que diga el JSON: `duration` es un
  # piso, no un valor. Si la narración se alarga, la imagen la acompaña.
  AUDIO_DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$AUDIO")
  SEGMENT_DURATION=$(python3 -c "print(max($AUDIO_DURATION + 0.5, $DURATION))")

  ffmpeg -y -loop 1 -i "$IMG" -i "$AUDIO" \
    -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=white" \
    -c:v libx264 -tune stillimage -pix_fmt yuv420p \
    -c:a aac -b:a 128k \
    -t "$SEGMENT_DURATION" \
    -shortest \
    "$SEGMENT" 2>/dev/null

  # realpath: SCREENSHOTS puede venir relativo, y el concat de ffmpeg lo resuelve
  # contra el archivo de lista, no contra el cwd.
  echo "file '$(realpath "$SEGMENT")'" >> "$CONCAT_FILE"
done

# Sin esta guarda, ffmpeg recibe una lista vacía y devuelve un error suyo en lugar
# de decir lo que pasó: no había ninguna captura.
if [ ! -s "$CONCAT_FILE" ]; then
  echo "No hay segmentos que concatenar: faltan las $ENTRIES capturas."
  echo "¿Corrió la captura antes que esto?"
  exit 1
fi

echo "Concatenando $((ENTRIES - FALTANTES)) segmentos..."
ffmpeg -y -f concat -safe 0 -i "$CONCAT_FILE" -c copy "$OUTPUT" 2>/dev/null

rm -rf "$AUDIO_DIR" "$SEGMENTS_DIR"

DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUTPUT" | cut -d. -f1)
SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "Listo: $OUTPUT  (${DUR}s, $SIZE)"
[ "$FALTANTES" -gt 0 ] && echo "Ojo: $FALTANTES capturas faltaron y no están en el video."
exit 0
