#!/usr/bin/env bash
#
# Preflight: are the five tools here, and do they actually run?
#
# Runnable on its own, which is the point. The same check used to live only inside
# make_video.sh, behind three required variables, so the one moment it was most wanted —
# deciding what to install, before writing any capture — was the one moment it could not
# be reached. Reported by the first person to install the plugin cold.
#
# Usage:
#   bash check.sh          # says what is missing, or lists what it found
#   bash check.sh --quiet  # speaks only on failure; how make_video.sh calls it
#
# Exits 0 when all five run, 1 on the first one that does not.
#
# In a devcontainer, run it in the container that will assemble the video:
#   docker exec <container> bash /path/to/check.sh

set -uo pipefail

QUIET=""
if [ "${1:-}" = "--quiet" ]; then QUIET=yes; fi

TOOLS="edge-tts ffmpeg ffprobe jq python3"

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
runs() {
  case "$1" in
    edge-tts) edge-tts --help ;;
    ffmpeg)   ffmpeg -version ;;
    ffprobe)  ffprobe -version ;;
    jq)       jq --version ;;
    python3)  python3 --version ;;
  esac >/dev/null 2>&1
}

for cmd in $TOOLS; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing: $cmd"
    case $cmd in
      edge-tts) echo "  Install: pipx install edge-tts (or pip install edge-tts)" ;;
      ffmpeg|ffprobe) echo "  Install: $PKG ffmpeg" ;;
      jq)       echo "  Install: $PKG jq" ;;
      python3)  echo "  Install: $PKG python3" ;;
    esac
    exit 1
  elif ! runs "$cmd"; then
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

if [ -z "$QUIET" ]; then
  echo "All five run — this machine can assemble a video."
  for cmd in $TOOLS; do
    printf "  %-9s %s\n" "$cmd" "$(command -v "$cmd")"
  done
fi
exit 0
