#!/bin/bash
# Renders src/*.html with headless Chrome: 1320 x 2868 (6.9") into this folder and
# 1206 x 2622 copies (the "iPhone with Dynamic Island" slot) into 1206x2622/.
set -euo pipefail
cd "$(dirname "$0")"
CHROME="${CHROME:-/c/Program Files/Google/Chrome/Application/chrome.exe}"
mkdir -p 1206x2622
for page in src/*.html; do
  name="$(basename "$page" .html)"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --virtual-time-budget=4000 --window-size=1320,2868 \
    --screenshot="$PWD/$name.png" "file:///$(cygpath -m "$PWD/$page")" 2>/dev/null
  python -I -c "from PIL import Image; Image.open('$name.png').convert('RGB').resize((1206, 2622), Image.LANCZOS).save('1206x2622/$name.png')"
  echo "rendered $name"
done
