"""Contrast and colour-vision checks for the brand and map palettes.

Run from the repository root:

    python tools/brand/colour_check.py

It prints WCAG contrast ratios against the basemap fills and the smallest
CIEDE2000 difference between map classes under normal vision and simulated
deuteranopia, protanopia and tritanopia (Machado, Oliveira and Fernandes 2009,
full severity). The script exits non-zero when a check in `CHECKS` fails, so the
numbers in docs/branding.md cannot quietly drift from the palette in
app/lib/src/map/map_palette.dart.

Standard library only.
"""

from __future__ import annotations

import itertools
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PALETTE_DART = ROOT / "app/lib/src/map/map_palette.dart"

# Basemap fills a track or marker is most likely to sit on (light basemap,
# app/assets/bundle/basemap/style.json).
BASEMAP = {
    "park": "#9CD3B4",
    "wood": "#A0D9A0",
    "earth": "#E2DFDA",
}

# Brand pairs that carry text; see docs/branding.md.
BRAND_TEXT = [
    ("cream on rainforest", "#F4ECD8", "#14532D", 4.5),
    ("mist on rainforest", "#9CC3A6", "#14532D", 4.5),
    ("pale mist on rainforest", "#C9DDCB", "#14532D", 4.5),
    ("rainforest on cream", "#14532D", "#F4ECD8", 4.5),
    ("sand on rainforest", "#E9C46A", "#14532D", 3.0),
]

# Machado et al. (2009) simulation matrices at severity 1.0, in linear RGB.
CVD = {
    "deuteranopia": (
        (0.367322, 0.860646, -0.227968),
        (0.280085, 0.672501, 0.047413),
        (-0.011820, 0.042940, 0.968881),
    ),
    "protanopia": (
        (0.152286, 1.052583, -0.204868),
        (0.114503, 0.786281, 0.099216),
        (-0.003882, -0.048116, 1.051998),
    ),
    "tritanopia": (
        (1.255528, -0.076749, -0.178779),
        (-0.078411, 0.930809, 0.147602),
        (0.004733, 0.691367, 0.303900),
    ),
}


def _rgb(hex_colour: str) -> tuple[float, float, float]:
    h = hex_colour.lstrip("#")[-6:]
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))  # type: ignore[return-value]


def _to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _to_srgb(c: float) -> float:
    c = min(max(c, 0.0), 1.0)
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def luminance(hex_colour: str) -> float:
    r, g, b = (_to_linear(c) for c in _rgb(hex_colour))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a: str, b: str) -> float:
    hi, lo = sorted((luminance(a), luminance(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def simulate(hex_colour: str, kind: str | None) -> tuple[float, float, float]:
    rgb = _rgb(hex_colour)
    if kind is None:
        return rgb
    lin = [_to_linear(c) for c in rgb]
    return tuple(_to_srgb(sum(m * c for m, c in zip(row, lin))) for row in CVD[kind])  # type: ignore[return-value]


def _lab(rgb: tuple[float, float, float]) -> tuple[float, float, float]:
    r, g, b = (_to_linear(c) for c in rgb)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t: float) -> float:
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116

    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def delta_e(c1: tuple[float, float, float], c2: tuple[float, float, float]) -> float:
    """CIEDE2000 between two sRGB colours."""
    l1, a1, b1 = _lab(c1)
    l2, a2, b2 = _lab(c2)
    cb = (math.hypot(a1, b1) + math.hypot(a2, b2)) / 2
    g = 0.5 * (1 - math.sqrt(cb**7 / (cb**7 + 25**7)))
    a1p, a2p = (1 + g) * a1, (1 + g) * a2
    c1p, c2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360
    h2p = math.degrees(math.atan2(b2, a2p)) % 360
    dlp, dcp = l2 - l1, c2p - c1p
    dh = 0.0 if c1p * c2p == 0 else h2p - h1p
    if dh > 180:
        dh -= 360
    elif dh < -180:
        dh += 360
    dhp = 2 * math.sqrt(c1p * c2p) * math.sin(math.radians(dh / 2))
    lbp, cbp = (l1 + l2) / 2, (c1p + c2p) / 2
    if c1p * c2p == 0:
        hbp = h1p + h2p
    elif abs(h1p - h2p) <= 180:
        hbp = (h1p + h2p) / 2
    elif h1p + h2p < 360:
        hbp = (h1p + h2p + 360) / 2
    else:
        hbp = (h1p + h2p - 360) / 2
    t = (
        1
        - 0.17 * math.cos(math.radians(hbp - 30))
        + 0.24 * math.cos(math.radians(2 * hbp))
        + 0.32 * math.cos(math.radians(3 * hbp + 6))
        - 0.20 * math.cos(math.radians(4 * hbp - 63))
    )
    dth = 30 * math.exp(-(((hbp - 275) / 25) ** 2))
    rc = 2 * math.sqrt(cbp**7 / (cbp**7 + 25**7))
    sl = 1 + 0.015 * (lbp - 50) ** 2 / math.sqrt(20 + (lbp - 50) ** 2)
    sc = 1 + 0.045 * cbp
    sh = 1 + 0.015 * cbp * t
    rt = -math.sin(math.radians(2 * dth)) * rc
    return math.sqrt(
        (dlp / sl) ** 2 + (dcp / sc) ** 2 + (dhp / sh) ** 2 + rt * (dcp / sc) * (dhp / sh)
    )


def read_map_palette() -> dict[str, str]:
    """Pulls the `static const <name> = '#RRGGBB'` values from map_palette.dart."""
    source = PALETTE_DART.read_text(encoding="utf-8")
    return dict(re.findall(r"static const (\w+) = '(#[0-9A-Fa-f]{6})'", source))


def main() -> int:
    palette = read_map_palette()
    failures: list[str] = []

    print("Brand text pairs (WCAG 2.x)")
    for label, fg, bg, minimum in BRAND_TEXT:
        ratio = contrast(fg, bg)
        mark = "ok " if ratio >= minimum else "LOW"
        print(f"  {mark} {label:26s} {ratio:5.2f}:1 (needs {minimum})")
        if ratio < minimum:
            failures.append(label)

    # Lines and markers carry meaning, so they need 3:1 against the fills they
    # sit on (WCAG 1.4.11, non-text contrast).
    print("\nMap colours against the basemap (needs 3:1)")
    checked = {k: v for k, v in palette.items() if not k.startswith("sunlight")}
    for name, colour in checked.items():
        if name in {"casing", "junctionFill", "poiStroke", "labelHalo"}:
            continue
        ratios = {bg: contrast(colour, value) for bg, value in BASEMAP.items()}
        low = [bg for bg, r in ratios.items() if r < 3.0]
        mark = "ok " if not low else "LOW"
        detail = "  ".join(f"{bg} {r:4.2f}" for bg, r in ratios.items())
        print(f"  {mark} {name:16s} {colour}  {detail}")
        if low:
            failures.append(name)

    # Classes drawn with the same style must stay apart for every walker.
    lines = {k: palette[k] for k in ("walkingTrack", "mtbTrack", "road", "connector")}
    points = {k: palette[k] for k in ("poi", "junctionStroke", "waypoint")}
    print("\nSmallest CIEDE2000 difference (≥ 10 is comfortably distinct)")
    for group, colours in (("track lines", lines), ("markers", points)):
        for kind in (None, *CVD):
            worst = min(
                (delta_e(simulate(a, kind), simulate(b, kind)), na, nb)
                for (na, a), (nb, b) in itertools.combinations(colours.items(), 2)
            )
            label = kind or "normal vision"
            mark = "ok " if worst[0] >= 10 else "LOW"
            print(f"  {mark} {group:11s} {label:13s} {worst[0]:5.1f}  ({worst[1]} / {worst[2]})")
            if worst[0] < 10:
                failures.append(f"{group} {label}")

    if failures:
        print(f"\n{len(failures)} check(s) failed: {', '.join(failures)}")
        return 1
    print("\nAll checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
