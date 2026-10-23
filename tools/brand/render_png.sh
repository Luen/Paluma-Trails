#!/usr/bin/env bash
# Renders the PNG exports of the brand SVGs with headless Chrome.
# Run from anywhere after tools/brand/build_brand.py:
#
#   tools/brand/render_png.sh
#   CHROME=/path/to/chrome tools/brand/render_png.sh
set -euo pipefail

cd "$(dirname "$0")/../.."
ROOT="$(pwd -W 2>/dev/null || pwd)" # Git Bash needs the C:/… form for Chrome

if [[ -z "${CHROME:-}" ]]; then
  for candidate in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/c/Program Files/Google/Chrome/Application/chrome.exe" \
    google-chrome chromium chromium-browser; do
    if [[ -x "$candidate" ]] || command -v "$candidate" >/dev/null 2>&1; then
      CHROME="$candidate"
      break
    fi
  done
fi
: "${CHROME:?Set CHROME to a Chrome or Chromium binary}"

render() { # source width height output [extra chrome flags]
  rm -f "$4"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --window-size="$2,$3" "${@:5}" \
    --screenshot="$ROOT/$4" "file:///${ROOT#/}/$1" >/dev/null 2>&1
  [[ -s "$4" ]] || { echo "failed to render $4" >&2; exit 1; }
  echo "rendered $4"
}

# Artwork without a tile must keep its transparency, or the launch screens
# show a white square around the pin.
transparent=(--default-background-color=00000000)

icon=app/assets/icon
render $icon/icon.svg 1024 1024 $icon/icon.png
render $icon/icon.svg 512 512 $icon/icon_512.png
render $icon/icon_foreground.svg 1024 1024 $icon/icon_foreground.png "${transparent[@]}"
render $icon/icon_monochrome.svg 1024 1024 $icon/icon_monochrome.png "${transparent[@]}"
render $icon/icon_android12.svg 960 960 $icon/icon_android12.png "${transparent[@]}"
render $icon/icon_splash.svg 1024 1024 $icon/icon_splash.png "${transparent[@]}"
# The web loader is hand-written in web/index.html and uses the same image.
cp $icon/icon_splash.png app/web/splash.png

render docs/brand/social-preview.svg 1280 640 docs/brand/social-preview.png
render $icon/feature_graphic.svg 1024 500 docs/store/feature-graphic.png
render $icon/icon.svg 512 512 docs/store/icon-512.png

echo
echo "Now regenerate the platform icons and splash screens:"
echo "  cd app && dart run flutter_launcher_icons && dart run flutter_native_splash:create"
