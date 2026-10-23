# Brand tools

Generators and checks for the Paluma Trails identity. The rules they implement
are in [`docs/branding.md`](../../docs/branding.md).

| File | What it does |
| --- | --- |
| `build_brand.py` | Writes the outlined wordmark, the lockups, the small-size mark, the web favicon, the feature graphic, the social preview and the README header |
| `render_png.sh` | Renders every PNG export (icons, splash, feature graphic, social preview, store icon) with headless Chrome |
| `colour_check.py` | Checks brand text contrast, map-colour contrast against the basemap and colour-vision separation of the map classes; CI runs it |

## Usage

From the repository root:

```sh
python -m pip install -r tools/brand/requirements.txt   # once
python tools/brand/build_brand.py
tools/brand/render_png.sh
cd app && dart run flutter_launcher_icons && dart run flutter_native_splash:create
```

`colour_check.py` needs only the standard library:

```sh
python tools/brand/colour_check.py
```

## Inputs

- `app/assets/fonts/atkinson_hyperlegible_next/` — the wordmark and all
  marketing text are outlined from the bundled typeface, so the SVGs need no
  font to render.
- `content/data/paluma/tracks.geojson` and `junctions.json` — the background
  of the feature graphic, social preview and README header is the real track
  network. Re-run `build_brand.py` after large content changes.
- The pin geometry is copied from `app/assets/icon/icon.svg`. If the mark ever
  changes, change it there, here and in `TrailPinMark`
  (`app/lib/src/brand/brand.dart`) together.

Do not edit the generated SVGs by hand; change the script and re-run it.
