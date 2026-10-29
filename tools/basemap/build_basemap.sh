#!/usr/bin/env bash
# Regenerates the offline basemap assets in content/basemap/.
#
# These files are committed to the repository on purpose: together they are only
# ~2.4 MB, which means a fresh clone, CI and the app binary all work offline with
# no network access and no build-time downloads.
#
# Requirements: pmtiles (brew install pmtiles), node + npm, python3, curl.
#
# Usage:
#   tools/basemap/build_basemap.sh                 # uses the default daily build
#   PROTOMAPS_BUILD=20261015 tools/basemap/build_basemap.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$REPO_ROOT/content/basemap"

BBOX="${PALUMA_BBOX:-146.05,-19.11,146.33,-18.80}"
BUILD="${PROTOMAPS_BUILD:-20261015}"
MAX_ZOOM="${MAX_ZOOM:-15}"

FONTS=("Noto Sans Regular" "Noto Sans Medium" "Noto Sans Italic")
FONT_RANGES=("0-255" "256-511" "512-767")   # Latin, Latin-1 Supplement, Latin Extended-A

mkdir -p "$TARGET/fonts" "$TARGET/sprites"

echo "==> PMTiles extract ($BUILD, bbox $BBOX, zoom 0-$MAX_ZOOM)"
pmtiles extract \
  "https://build.protomaps.com/$BUILD.pmtiles" \
  "$TARGET/paluma.pmtiles" \
  --bbox="$BBOX" \
  --maxzoom="$MAX_ZOOM" \
  --download-threads=8

echo "==> Style"
# Pass a path relative to the repo root so generate_style.mjs can confine the
# write (absolute paths outside cwd are refused).
( cd "$REPO_ROOT" && node tools/basemap/generate_style.mjs content/basemap/style.json )

echo "==> Fonts"
for font in "${FONTS[@]}"; do
  # The directory name becomes the MapLibre fontstack (and the URL path), so it
  # must not contain spaces; the upstream assets are still fetched with the
  # original, percent-encoded name.
  dir_name="${font// /-}"
  mkdir -p "$TARGET/fonts/$dir_name"
  encoded="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$font")"
  for range in "${FONT_RANGES[@]}"; do
    curl -fsSL \
      "https://protomaps.github.io/basemaps-assets/fonts/$encoded/$range.pbf" \
      -o "$TARGET/fonts/$dir_name/$range.pbf"
  done
done

echo "==> Sprites"
for file in light.json light.png light@2x.json light@2x.png; do
  curl -fsSL \
    "https://protomaps.github.io/basemaps-assets/sprites/v4/$file" \
    -o "$TARGET/sprites/$file"
done

echo "==> Done"
du -sh "$TARGET"
echo "Now run: dart run tools/paluma_cli/bin/paluma_cli.dart bundle build"
