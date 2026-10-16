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

# Older edge-tts releases gave version problems (reported by the maintainer; the exact
# failure is not recorded here), so the engine wants a release above 7.3. The spec is quoted wherever it is printed: unquoted, the
# shell reads the > as a redirect and "installs" edge-tts into a file called 7.3.
EDGE_TTS_MIN="7.3"
EDGE_TTS_SPEC="edge-tts>$EDGE_TTS_MIN"

# The hint leads with the package manager the reader actually has: being told to
# `apt install` on a Mac is one more translation between them and a working command.
case "$(uname -s)" in
  Darwin) PKG="brew install" ; PIPX="brew install pipx" ;;
  *)      PKG="apt install"  ; PIPX="sudo apt install -y pipx" ;;
esac

# edge-tts is the only one of the five that is not a package: it is a Python program, and
# on recent Debian/Ubuntu `pip install` refuses outright — externally-managed-environment,
# PEP 668. That makes pipx the first step rather than an alternative, and pipx is usually
# not installed either. Telling someone to run `pipx install edge-tts` when they have no
# pipx sends them to a command-not-found; the bootstrap needs sudo at an interactive
# terminal, which an agent does not have, so it is a line to hand to a human.
edge_tts_install() {
  if command -v pipx >/dev/null 2>&1; then
    echo "    pipx install $1\"$EDGE_TTS_SPEC\""
  else
    echo "    $PIPX && pipx ensurepath   # pipx is not here either, and it comes first"
    echo "    pipx install $1\"$EDGE_TTS_SPEC\""
    echo "  The sudo needs a human at a terminal. \`pip install edge-tts\` is not a way"
    echo "  around it: recent Debian/Ubuntu refuse it (PEP 668)."
  fi
}

# jq ships a static binary with no dependencies, which makes a no-root fallback cheap: one
# curl into a directory already on most people's PATH. ffmpeg has a static build too, but at
# ~80MB against jq's ~1MB it is a much bigger ask, so it stays out of this hint for now.
# Reported by someone without sudo on Linux Mint, who had no path printed here at all.
jq_install() {
  echo "    $PKG jq"
  if [ "$(uname -s)" = "Darwin" ]; then
    return
  fi
  case "$(uname -m)" in
    x86_64)        ARCH=amd64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    *)             ARCH="" ;;
  esac
  if [ -n "$ARCH" ]; then
    echo "  No sudo? A static binary needs none:"
    echo "    mkdir -p ~/.local/bin"
    echo "    curl -L https://github.com/jqlang/jq/releases/latest/download/jq-linux-$ARCH -o ~/.local/bin/jq"
    echo "    chmod +x ~/.local/bin/jq   # confirm ~/.local/bin is on PATH: echo \$PATH"
  fi
}

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

# Prints the installed edge-tts version ("edge-tts 7.2.8" -> 7.2.8), nothing if unreadable.
edge_tts_version() { edge-tts --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1; }

# True when $1 is strictly above $EDGE_TTS_MIN: the newest of the two sorts last, and
# equal to the minimum is not above it.
above_min() {
  [ "$1" != "$EDGE_TTS_MIN" ] && [ "$(printf '%s\n%s\n' "$EDGE_TTS_MIN" "$1" | sort -V | tail -1)" = "$1" ]
}

for cmd in $TOOLS; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing: $cmd"
    case $cmd in
      edge-tts) echo "  Install:" ; edge_tts_install "" ;;
      ffmpeg|ffprobe) echo "  Install: $PKG ffmpeg" ;;
      jq)       echo "  Install:" ; jq_install ;;
      python3)  echo "  Install: $PKG python3" ;;
    esac
    exit 1
  elif ! runs "$cmd"; then
    echo "On PATH but will not run: $cmd  ($(command -v "$cmd"))"
    case $cmd in
      edge-tts) echo "  Usually a Python it was installed against is gone. Reinstall it in" ;
                echo "  its own venv, where the next Python upgrade cannot reach it:" ;
                edge_tts_install "--force " ;
                echo "  If a reinstall did not help, an older copy may be shadowing it:" ;
                echo "    which -a edge-tts   # remove the stale one, then: hash -r" ;;
      *)        echo "  Reinstall it: $PKG $cmd" ;;
    esac
    exit 1
  elif [ "$cmd" = edge-tts ] && ! above_min "$(edge_tts_version)"; then
    echo "Too old: edge-tts $(edge_tts_version)  ($(command -v edge-tts)) — needs > $EDGE_TTS_MIN"
    echo "  Older releases fail against the voice service. Upgrade it in its own venv:"
    edge_tts_install "--force "
    echo "  If that did not change the version, an older copy may be shadowing it:"
    echo "    which -a edge-tts   # remove the stale one, then: hash -r"
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
