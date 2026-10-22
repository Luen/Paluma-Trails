# App icon, splash and store artwork

The artwork is original to Paluma Trails. It is not derived from any third-party
icon set, so it can be used in the app, the web build and the store listing.
Read [the branding guide](../../../docs/branding.md) before changing the mark,
palette or usage rules.

## Source artwork

| File | Purpose |
| --- | --- |
| `icon.svg` | 1024×1024 master: tile background + trail pin |
| `icon_foreground.svg` | Adaptive-icon foreground (transparent, inside the 66 dp safe zone) |
| `icon_monochrome.svg` | Android 13+ themed-icon layer (alpha only, transparent) |
| `icon_android12.svg` | Android 12+ splash icon (960×960, inside the 640 dp circle) |
| `icon_splash.svg` | Pin-only mark used by the older splash screens and the web loader |
| `feature_graphic.svg` | 1024×500 Play Store feature graphic |

Palette: rainforest green `#14532D`, cream `#F4ECD8`, sand `#E9C46A`.

The matching PNGs are committed next to the SVGs because the generators consume
PNG files. Render them after changing an SVG (any SVG renderer works; this is the
command used on macOS):

```sh
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

"$CHROME" --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=1 --window-size=1024,1024 \
  --screenshot=assets/icon/icon.png "file://$PWD/assets/icon/icon.svg"

"$CHROME" --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=1 --window-size=1024,1024 \
  --default-background-color=00000000 \
  --screenshot=assets/icon/icon_foreground.png \
  "file://$PWD/assets/icon/icon_foreground.svg"

# Repeat for icon_monochrome.png (1024×1024), icon_splash.png (1024×1024),
# icon_android12.png (960×960) and icon_512.png (512×512).
```

## Generated outputs

```sh
cd app
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

This writes the Android launcher icons (legacy + adaptive + monochrome), the iOS
`AppIcon` set, the web favicon/PWA icons, the launch screens and the web splash.
`tool/check_generated_icons.sh` regenerates them and fails if anything drifted;
CI runs the same check.

The adaptive foreground is already scaled to the safe zone, so
`adaptive_icon_foreground_inset` is `0`. Do not add padding to the foreground
file without changing that setting.

## Store listing

`docs/store/` holds the 512×512 store icon, the 1024×500 feature graphic and
the phone screenshots, rendered from `icon.svg` and `feature_graphic.svg`.
