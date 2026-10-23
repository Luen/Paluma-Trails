"""Builds the Paluma Trails brand artwork from code.

    python -m pip install -r tools/brand/requirements.txt
    python tools/brand/build_brand.py
    tools/brand/render_png.sh        # PNG exports for GitHub and Google Play

Everything here is generated, so edit this script rather than the SVGs:

- the wordmark, outlined from the bundled typeface (Atkinson Hyperlegible
  Next Bold) with HarfBuzz shaping, so it needs no font to display;
- horizontal and stacked lockups in the four colourways;
- the small-size mark (`app/assets/icon/icon_small.svg`) and the web favicon;
- the Play feature graphic, the GitHub social preview and the README header,
  whose background is the real track network from content/data.

The pin geometry is copied from app/assets/icon/icon.svg and matches
TrailPinMark in app/lib/src/brand/brand.dart.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path

import uharfbuzz as hb
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "app/assets/fonts/atkinson_hyperlegible_next"
BRAND = ROOT / "docs/brand"
ICON = ROOT / "app/assets/icon"
WEB = ROOT / "app/web"
TRACKS = ROOT / "content/data/paluma/tracks.geojson"
JUNCTIONS = ROOT / "content/data/paluma/junctions.json"

RAINFOREST = "#14532D"
CREAM = "#F4ECD8"
SAND = "#E9C46A"
MIST = "#9CC3A6"
PALE_MIST = "#C9DDCB"

NAME = "Paluma Trails"
TAGLINE = "Every track and junction, offline."
EYEBROW = "PALUMA RANGE NATIONAL PARK · QUEENSLAND"

# Wordmark tracking, in em. The app's Wordmark widget uses the same value.
WORDMARK_TRACKING = -0.015

# --- Mark -----------------------------------------------------------------

# icon.svg grid: the pin spans x 260–764, y 176–864 (504 × 688).
PIN_OUTLINE = (
    "M512 176C373 176 260 289 260 428C260 624 512 864 512 864"
    "C512 864 764 624 764 428C764 289 651 176 512 176Z"
)
PIN_HOLE = "M372 422A140 140 0 1 0 652 422A140 140 0 1 0 372 422Z"
PIN_MOUNTAIN = "M396 470L466 356L512 414L556 348L628 470Z"
# Small-size mark: a larger hole and no mountain.
PIN_SMALL_HOLE = "M354 424A158 158 0 1 0 670 424A158 158 0 1 0 354 424Z"
PIN_W, PIN_H, PIN_X, PIN_Y = 504, 688, 260, 176


def pin(x: float, y: float, height: float, fill: str, small: bool = False) -> str:
    """The pin with its cut-outs, top-left at (x, y)."""
    s = height / PIN_H
    d = PIN_OUTLINE + (PIN_SMALL_HOLE if small else PIN_HOLE + PIN_MOUNTAIN)
    return (
        f'<path transform="translate({x:.2f} {y:.2f}) scale({s:.5f}) '
        f'translate({-PIN_X} {-PIN_Y})" fill="{fill}" fill-rule="evenodd" d="{d}"/>'
    )


# --- Type -----------------------------------------------------------------


@dataclass
class Outline:
    path: str  # SVG path data with the baseline at y = 0
    width: float  # advance width
    top: float  # highest ink above the baseline (positive)
    bottom: float  # lowest ink below the baseline (positive when below)
    left: float  # ink starts this far from x = 0


_FONT_CACHE: dict[str, tuple[TTFont, hb.Font]] = {}


def _font(weight: str) -> tuple[TTFont, hb.Font]:
    if weight not in _FONT_CACHE:
        path = FONTS / f"AtkinsonHyperlegibleNext-{weight}.ttf"
        blob = hb.Blob.from_file_path(str(path))
        _FONT_CACHE[weight] = (TTFont(str(path)), hb.Font(hb.Face(blob)))
    return _FONT_CACHE[weight]


def outline(text: str, size: float, weight: str = "Bold", tracking: float = 0.0) -> Outline:
    """Shapes `text` with HarfBuzz (kerning included) and returns its outline."""
    tt, font = _font(weight)
    upem = tt["head"].unitsPerEm
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(font, buf, {"kern": True, "liga": True})

    glyph_set = tt.getGlyphSet()
    order = tt.getGlyphOrder()
    scale = size / upem
    pen = SVGPathPen(glyph_set, ntos=lambda v: f"{v:.2f}".rstrip("0").rstrip("."))
    bounds = BoundsPen(glyph_set)
    x = 0.0
    track = tracking * upem
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        name = order[info.codepoint]
        # Font units are y-up; SVG is y-down.
        transform = (scale, 0, 0, -scale, (x + pos.x_offset) * scale, -pos.y_offset * scale)
        glyph_set[name].draw(TransformPen(pen, transform))
        glyph_set[name].draw(TransformPen(bounds, (1, 0, 0, 1, x + pos.x_offset, pos.y_offset)))
        x += pos.x_advance + track
    x -= track
    xmin, ymin, xmax, ymax = bounds.bounds
    return Outline(pen.getCommands(), x * scale, ymax * scale, -ymin * scale, xmin * scale)


def cap_height(size: float, weight: str = "Bold") -> float:
    tt, _ = _font(weight)
    return tt["OS/2"].sCapHeight / tt["head"].unitsPerEm * size


def text_path(o: Outline, x: float, baseline: float, fill: str, extra: str = "") -> str:
    return (
        f'<path transform="translate({x:.2f} {baseline:.2f})" fill="{fill}"{extra} '
        f'd="{o.path}"/>'
    )


def svg(width: float, height: float, body: str, title: str) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width:g}" height="{height:g}" '
        f'viewBox="0 0 {width:g} {height:g}" role="img" aria-label="{title}">\n'
        f"  <title>{title}</title>\n"
        "  <!-- Generated by tools/brand/build_brand.py; do not edit by hand. -->\n"
        f"{body}</svg>\n"
    )


# --- Lockups ----------------------------------------------------------------

COLOURWAYS = {
    # suffix: (mark and wordmark colour, preview field)
    "": (RAINFOREST, CREAM),
    "-reversed": (CREAM, RAINFOREST),
    "-black": ("#000000", "#FFFFFF"),
    "-white": ("#FFFFFF", "#000000"),
}

F = 100.0  # wordmark size the lockups are drawn at


def horizontal_lockup(fill: str, x0: float = 0, y0: float = 0, size: float = F) -> tuple[str, float, float]:
    """Pin beside the wordmark. Returns (svg body, width, height) without clear space.

    The pin is 1.1 em tall with its head centred on the capital height, so it
    rises just above the cap line and its tip sits below the baseline.
    """
    word = outline(NAME, size, "Bold", WORDMARK_TRACKING)
    pin_h = size * 1.1
    gap = size * 0.32
    pin_w = pin_h * PIN_W / PIN_H
    cap = cap_height(size)
    head_centre = 246 / PIN_H * pin_h  # circle centre below the pin top
    pin_top = 0.0
    baseline = head_centre + cap / 2
    top = min(pin_top, baseline - word.top)
    bottom = max(pin_top + pin_h, baseline + word.bottom)
    body = (
        "  " + pin(x0, y0 + pin_top - top, pin_h, fill) + "\n"
        "  " + text_path(word, x0 + pin_w + gap - word.left, y0 + baseline - top, fill) + "\n"
    )
    return body, pin_w + gap + word.width - word.left, bottom - top


def stacked_lockup(fill: str, x0: float = 0, y0: float = 0, size: float = F) -> tuple[str, float, float]:
    word = outline(NAME, size, "Bold", WORDMARK_TRACKING)
    pin_h = size * 1.7
    pin_w = pin_h * PIN_W / PIN_H
    gap = size * 0.34
    ink = word.width - word.left
    width = max(ink, pin_w)
    baseline = pin_h + gap + word.top
    body = (
        "  " + pin(x0 + (width - pin_w) / 2, y0, pin_h, fill) + "\n"
        "  " + text_path(word, x0 + (width - ink) / 2 - word.left, y0 + baseline, fill) + "\n"
    )
    return body, width, baseline + word.bottom


def write_lockups() -> None:
    BRAND.mkdir(parents=True, exist_ok=True)
    for suffix, (fill, _) in COLOURWAYS.items():
        for name, build in (("horizontal", horizontal_lockup), ("stacked", stacked_lockup)):
            # Clear space: a quarter of the pin's height on every side.
            pin_h = F * (1.1 if name == "horizontal" else 1.7)
            pad = pin_h * 0.25
            body, w, h = build(fill, pad, pad)
            (BRAND / f"lockup-{name}{suffix}.svg").write_text(
                svg(round(w + 2 * pad, 1), round(h + 2 * pad, 1), body, NAME), encoding="utf-8", newline="\n"
            )
        word = outline(NAME, F, "Bold", WORDMARK_TRACKING)
        pad = F * 0.2
        w, h = word.width - word.left + 2 * pad, word.top + word.bottom + 2 * pad
        body = "  " + text_path(word, pad - word.left, pad + word.top, fill) + "\n"
        (BRAND / f"wordmark{suffix}.svg").write_text(
            svg(round(w, 1), round(h, 1), body, NAME), encoding="utf-8", newline="\n"
        )


# --- Small-size mark --------------------------------------------------------


def write_small_mark() -> None:
    """A 32-unit tile for 16–32 px: bigger pin, bigger hole, no mountain."""
    body = (
        f'  <rect width="32" height="32" rx="7" fill="{RAINFOREST}"/>\n'
        "  " + pin((32 - 27 * PIN_W / PIN_H) / 2, 2.5, 27, CREAM, small=True) + "\n"
    )
    content = svg(32, 32, body, NAME)
    (ICON / "icon_small.svg").write_text(content, encoding="utf-8", newline="\n")
    (WEB / "favicon.svg").write_text(content, encoding="utf-8", newline="\n")


# --- Track network illustration ----------------------------------------------


def _simplify(points: list[tuple[float, float]], tolerance: float) -> list[tuple[float, float]]:
    """Ramer–Douglas–Peucker."""
    if len(points) < 3:
        return points
    (x1, y1), (x2, y2) = points[0], points[-1]
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy) or 1e-9
    worst, index = 0.0, 0
    for i, (x, y) in enumerate(points[1:-1], 1):
        d = abs(dy * x - dx * y + x2 * y1 - y2 * x1) / length
        if d > worst:
            worst, index = d, i
    if worst <= tolerance:
        return [points[0], points[-1]]
    return _simplify(points[: index + 1], tolerance)[:-1] + _simplify(points[index:], tolerance)


def network(x: float, y: float, height: float, *, opacity: float = 0.55) -> tuple[str, float]:
    """The park's track network and junctions, fitted to `height`. Returns (body, width)."""
    tracks = json.loads(TRACKS.read_text(encoding="utf-8"))["features"]
    junctions = json.loads(JUNCTIONS.read_text(encoding="utf-8"))["junctions"]
    coords = [c for f in tracks for c in f["geometry"]["coordinates"]]
    west, east = min(c[0] for c in coords), max(c[0] for c in coords)
    south, north = min(c[1] for c in coords), max(c[1] for c in coords)
    kx = math.cos(math.radians((north + south) / 2))
    scale = height / (north - south)
    width = (east - west) * kx * scale

    def project(lon: float, lat: float) -> tuple[float, float]:
        return x + (lon - west) * kx * scale, y + (north - lat) * scale

    stroke = height / 260
    lines = []
    for feature in tracks:
        pts = _simplify([project(*c[:2]) for c in feature["geometry"]["coordinates"]], 0.6)
        d = "M" + "L".join(f"{px:.1f} {py:.1f}" for px, py in pts)
        dash = ' stroke-dasharray="{0:.1f} {1:.1f}"'.format(stroke * 2.5, stroke * 2) if feature["properties"]["class"] == "other" else ""
        lines.append(f'    <path d="{d}"{dash}/>')
    dots = []
    for j in junctions:
        px, py = project(j["location"]["lon"], j["location"]["lat"])
        dots.append(f'    <circle cx="{px:.1f}" cy="{py:.1f}" r="{stroke * 2.2:.1f}"/>')
    body = (
        f'  <g fill="none" stroke="{MIST}" stroke-width="{stroke:.2f}" stroke-linecap="round" '
        f'stroke-linejoin="round" opacity="{opacity}">\n' + "\n".join(lines) + "\n  </g>\n"
        f'  <g fill="{SAND}" stroke="{RAINFOREST}" stroke-width="{stroke * 0.8:.2f}" opacity="{min(1, opacity + 0.3)}">\n'
        + "\n".join(dots)
        + "\n  </g>\n"
    )
    return body, width


# --- Marketing surfaces -----------------------------------------------------


def banner(width: float, height: float, *, word_size: float, left: float, net_height: float,
           net_right: float, eyebrow: bool = True, rule: bool = True) -> str:
    """Rainforest field, the network on the right, lockup and tagline on the left."""
    net_body, net_w = network(0, 0, net_height)
    net_x = width - net_right - net_w
    net_y = (height - net_height) / 2
    parts = [
        f'  <rect width="{width:g}" height="{height:g}" fill="{RAINFOREST}"/>\n',
        f'  <g transform="translate({net_x:.1f} {net_y:.1f})">\n{net_body}  </g>\n',
    ]

    lock_body, lock_w, lock_h = horizontal_lockup(CREAM, 0, 0, word_size)
    tag = outline(TAGLINE, word_size * 0.4, "Regular")
    eb = outline(EYEBROW, word_size * 0.2, "Bold", 0.12)
    gap_eb = word_size * 0.32
    gap_tag = word_size * 0.42
    block_h = (eb.top + gap_eb if eyebrow else 0) + lock_h + gap_tag + tag.top + (word_size * 0.5 if rule else 0)
    y = (height - block_h) / 2
    if eyebrow:
        parts.append("  " + text_path(eb, left - eb.left, y + eb.top, MIST) + "\n")
        y += eb.top + gap_eb
    parts.append(f'  <g transform="translate({left:.1f} {y:.1f})">\n{lock_body}  </g>\n')
    y += lock_h + gap_tag + tag.top
    parts.append("  " + text_path(tag, left - tag.left, y, PALE_MIST) + "\n")
    if rule:
        y += word_size * 0.32
        parts.append(
            f'  <rect x="{left:.1f}" y="{y:.1f}" width="{word_size * 1.2:.1f}" '
            f'height="{word_size * 0.06:.1f}" rx="{word_size * 0.03:.1f}" fill="{SAND}"/>\n'
        )
    return svg(width, height, "".join(parts), f"{NAME}: {TAGLINE}")


def write_marketing() -> None:
    (ICON / "feature_graphic.svg").write_text(
        banner(1024, 500, word_size=74, left=64, net_height=560, net_right=-40), encoding="utf-8", newline="\n"
    )
    (BRAND / "social-preview.svg").write_text(
        banner(1280, 640, word_size=92, left=88, net_height=720, net_right=-40), encoding="utf-8", newline="\n"
    )
    (BRAND / "readme-header.svg").write_text(
        banner(1280, 320, word_size=72, left=64, net_height=640, net_right=-80, eyebrow=False, rule=False),
        encoding="utf-8",
        newline="\n",
    )


def main() -> None:
    write_lockups()
    write_small_mark()
    write_marketing()
    for path in sorted([*BRAND.glob("*.svg"), ICON / "icon_small.svg", ICON / "feature_graphic.svg"]):
        print(f"wrote {path.relative_to(ROOT)} ({path.stat().st_size // 1024} KiB)")


if __name__ == "__main__":
    main()
