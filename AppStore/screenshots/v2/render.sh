#!/bin/bash
# Renders src/*.html to 1320 x 2868 PNGs with headless Chrome (App Store 6.9").
set -euo pipefail
cd "$(dirname "$0")"
CHROME="${CHROME:-/c/Program Files/Google/Chrome/Application/chrome.exe}"
for page in src/*.html; do
  name="$(basename "$page" .html)"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --window-size=1320,2868 --screenshot="$PWD/$name.png" "file:///$(cygpath -m "$PWD/$page")" 2>/dev/null
  echo "rendered $name.png"
done
