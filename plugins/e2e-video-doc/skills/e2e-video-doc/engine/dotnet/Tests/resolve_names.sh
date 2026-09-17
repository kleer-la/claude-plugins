#!/usr/bin/env bash
# Runs make_video.sh's own screenshot-resolution block, cut out of the script by its markers
# rather than copied, on every case directory: <case>/narration.json and <case>/shots/.
# Prints "<case>|OK <screenshot>" or "<case>|<error>". NameParityTest compares this output
# with the .NET engine's, so a change to the block in make_video.sh shows up as a diff.
set -uo pipefail
shopt -s nullglob
SCRIPT="$1"
CASES="$2"

BLOCK=$(awk '/SCREENSHOT=\$\(jq -r "\.\[\$i\]\.screenshot/{p=1} p{print} p&&/^  fi$/{exit}' "$SCRIPT" \
  | grep -v 'DURATION=\|NARRATION_TEXT=')
if [ -z "$BLOCK" ]; then
  echo "could not find the resolution block in $SCRIPT" >&2
  exit 3
fi

for c in "$CASES"/*/; do
  c="${c%/}"
  NARRATION_FILE="$c/narration.json"
  SCREENSHOTS_DIR="$c/shots"
  i=0
  out=$( ( eval "$BLOCK"; echo "OK $SCREENSHOT" ) 2>&1 )
  echo "$(basename "$c")|$(echo "$out" | tail -1)"
done
