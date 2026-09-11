#!/usr/bin/env bash
#
# Preflight: are the four tools here, and do they actually run?
#
# Runnable on its own, which is the point. Same idea as e2e-video-doc's check:
# finding a binary on PATH is not the same as being able to run it.
#
# Usage:
#   bash check.sh          # says what is missing, or lists what it found
#   bash check.sh --quiet  # speaks only on failure; how make_brief.sh calls it
#
# Exits 0 when all four run, 1 on the first one that does not.
#
# ffmpeg is required. ffprobe is not: some static ffmpeg builds ship without it,
# and duration is read from ffmpeg itself via python3.

set -uo pipefail

QUIET=""
if [ "${1:-}" = "--quiet" ]; then QUIET=yes; fi

TOOLS="edge-tts ffmpeg jq python3"

case "$(uname -s)" in
  Darwin) PKG="brew install" ; PIPX="brew install pipx" ;;
  *)      PKG="apt install"  ; PIPX="sudo apt install -y pipx" ;;
esac

edge_tts_install() {
  if command -v pipx >/dev/null 2>&1; then
    echo "    pipx install $1edge-tts"
  else
    echo "    $PIPX && pipx ensurepath   # pipx is not here either, and it comes first"
    echo "    pipx install $1edge-tts"
    echo "  The sudo needs a human at a terminal. \`pip install edge-tts\` is not a way"
    echo "  around it: recent Debian/Ubuntu refuse it (PEP 668)."
  fi
}

runs() {
  case "$1" in
    edge-tts) edge-tts --help ;;
    ffmpeg)   ffmpeg -version ;;
    jq)       jq --version ;;
    python3)  python3 --version ;;
  esac >/dev/null 2>&1
}

for cmd in $TOOLS; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing: $cmd"
    case $cmd in
      edge-tts) echo "  Install:" ; edge_tts_install "" ;;
      ffmpeg)   echo "  Install: $PKG ffmpeg" ;;
      jq)       echo "  Install: $PKG jq" ;;
      python3)  echo "  Install: $PKG python3" ;;
    esac
    exit 1
  elif ! runs "$cmd"; then
    echo "On PATH but will not run: $cmd  ($(command -v "$cmd"))"
    case $cmd in
      edge-tts) echo "  Usually a Python it was installed against is gone. Reinstall it in"
                echo "  its own venv, where the next Python upgrade cannot reach it:"
                edge_tts_install "--force "
                echo "  If a reinstall did not help, an older copy may be shadowing it:"
                echo "    which -a edge-tts   # remove the stale one, then: hash -r" ;;
      *)        echo "  Reinstall it: $PKG $cmd" ;;
    esac
    exit 1
  fi
done

if [ -z "$QUIET" ]; then
  echo "All four run — this machine can assemble a briefing."
  for cmd in $TOOLS; do
    printf "  %-9s %s\n" "$cmd" "$(command -v "$cmd")"
  done
fi
exit 0
