# Store listing assets

Read [the branding guide](../branding.md) for logo, palette and voice rules.

| File | Size | Notes |
| --- | --- | --- |
| `icon-512.png` | 512×512 | Google Play store icon, opaque |
| `feature-graphic.png` | 1024×500 | Google Play feature graphic, opaque |
| `screenshots/01-map.png` | 1080×1746 | Map with the offline trail network |
| `screenshots/02-next-junction.png` | 1080×1746 | Blue dot and distance to the next junction |

The icon and feature graphic are rendered from sources in `app/assets/icon/`:

- `icon.svg` → `icon-512.png`
- `feature_graphic.svg` → `feature-graphic.png`

The screenshots come from the web build at 540×873 CSS pixels (2× device
pixel ratio), with a simulated GPS fix at
`(-18.942978, 146.188905)`: the junction distance is real content, not a mock.

See `app/assets/icon/README.md` for the render and generation commands, and #52
for the store listing itself.
