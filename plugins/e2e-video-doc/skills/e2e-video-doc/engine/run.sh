#!/usr/bin/env bash
#
# Orquesta un flujo completo: captura y después arma el video.
#
# Lee `e2e-video-doc.json` de la raíz del proyecto — lo único que hay que escribir
# por proyecto. Ver reference/config.md.
#
# Uso:
#   bash run.sh <flujo> [--solo-armar]
#   VOICE=es-CO-SalomeNeural bash run.sh alta

set -euo pipefail

FLOW="${1:?uso: run.sh <flujo> [--solo-armar]}"
SOLO_ARMAR="${2:-}"

ENGINE_DIR="$(cd "$(dirname "$0")" && pwd)"

# La config manda dónde está la raíz: se busca hacia arriba desde el cwd.
DIR="$PWD"
while [ "$DIR" != "/" ] && [ ! -f "$DIR/e2e-video-doc.json" ]; do
  DIR="$(dirname "$DIR")"
done
CONFIG="$DIR/e2e-video-doc.json"
[ -f "$CONFIG" ] || { echo "No encontré e2e-video-doc.json desde $PWD hacia arriba."; exit 1; }
ROOT="$DIR"

campo() {
  # Primero el override del flujo, si no el default, con {flow} reemplazado.
  local clave="$1"
  local valor
  valor=$(jq -r --arg f "$FLOW" --arg k "$clave" \
    '(.flows[$f][$k] // .defaults[$k] // empty)' "$CONFIG")
  [ -n "$valor" ] || { echo "Falta '$clave' para el flujo '$FLOW' en $CONFIG" >&2; exit 1; }
  echo "${valor//\{flow\}/$FLOW}"
}

jq -e --arg f "$FLOW" '.flows[$f]' "$CONFIG" >/dev/null 2>&1 || {
  echo "El flujo '$FLOW' no está en $CONFIG. Definidos:"
  jq -r '.flows | keys[]' "$CONFIG" | sed 's/^/  - /'
  exit 1
}

CAPTURE=$(campo capture)
SCREENSHOTS="$ROOT/$(campo screenshots)"
NARRATION="$ROOT/$(campo narration)"
OUTPUT="$ROOT/$(campo output)"
VOICE="${VOICE:-$(jq -r --arg f "$FLOW" '(.flows[$f].voice // .defaults.voice // "es-AR-ElenaNeural")' "$CONFIG")}"

if [ "$SOLO_ARMAR" != "--solo-armar" ]; then
  echo "▶ $FLOW — capturando"
  ( cd "$ROOT" && eval "${CAPTURE//\{flow\}/$FLOW}" )
fi

echo "▶ $FLOW — narrando y armando"
NARRATION="$NARRATION" SCREENSHOTS="$SCREENSHOTS" OUTPUT="$OUTPUT" VOICE="$VOICE" \
  bash "$ENGINE_DIR/make_video.sh"
