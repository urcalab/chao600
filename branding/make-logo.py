"""Generates every Chao 600 logo asset from one design: a struck-through "600" on red.

Type is Nunito Black (SIL Open Font License), converted to paths so the files don't
depend on installed fonts. Needs fonttools (pip install fonttools), rsvg-convert and
ImageMagick (brew install librsvg imagemagick).

Run: python3 branding/make-logo.py
"""
import subprocess
import tempfile
import urllib.request
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parent.parent
BRANDING = ROOT / "branding"
SITE = ROOT / "site"
APP_ICON = ROOT / "Chao600/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
FONT_URL = "https://github.com/google/fonts/raw/main/ofl/nunito/Nunito%5Bwght%5D.ttf"

RED_TOP, RED_BOTTOM = "#FF5A5F", "#D0103A"
INK, INK_ON_DARK, MUTED, PAPER = "#16161A", "#FFFFFF", "#5B5B63", "#FAFAF8"


def font(weight):
    path = Path(tempfile.gettempdir()) / "Nunito-wght.ttf"
    if not path.exists():
        urllib.request.urlretrieve(FONT_URL, path)
    return instantiateVariableFont(TTFont(path), {"wght": weight})


BLACK, BOLD = font(1000), font(700)


def shape(face, text, size):
    """SVG path for `text` with its baseline at y=0, plus advance width and ink bounds."""
    glyphs, cmap = face.getGlyphSet(), face.getBestCmap()
    scale = size / face["head"].unitsPerEm
    path, bounds = SVGPathPen(glyphs), BoundsPen(glyphs)
    x = 0
    for char in text:
        name = cmap[ord(char)]
        transform = (scale, 0, 0, -scale, x, 0)
        glyphs[name].draw(TransformPen(path, transform))
        glyphs[name].draw(TransformPen(bounds, transform))
        x += glyphs[name].width * scale
    x0, y0, x1, y1 = bounds.bounds
    return path.getCommands(), x, (x0, y0, x1, y1)


def cap_height(face, size):
    return face["OS/2"].sCapHeight * size / face["head"].unitsPerEm


def mark(rounded):
    """The mark on a 1024 canvas: rounded for the web, full-bleed for the App Store icon."""
    probe = shape(BLACK, "600", 1000)[2]
    size = 1000 * 600 / (probe[2] - probe[0])  # "600" ink spans 600 of 1024
    d, _, (x0, y0, x1, y1) = shape(BLACK, "600", size)
    tx, ty = 512 - (x0 + x1) / 2, 512 - (y0 + y1) / 2
    corner = ' rx="229"' if rounded else ""
    slash = 'x1="200" y1="800" x2="824" y2="224" stroke-linecap="round"'
    return f"""<defs>
    <linearGradient id="red" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{RED_TOP}"/><stop offset="1" stop-color="{RED_BOTTOM}"/>
    </linearGradient>
    <mask id="gap" maskUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024">
      <rect width="1024" height="1024" fill="#fff"/><line {slash} stroke="#000" stroke-width="120"/>
    </mask>
  </defs>
  <rect width="1024" height="1024"{corner} fill="url(#red)"/>
  <g mask="url(#gap)"><path transform="translate({tx:.1f} {ty:.1f})" fill="#fff" d="{d}"/></g>
  <line {slash} stroke="#fff" stroke-width="56"/>"""


def svg(width, height, body, background=None):
    fill = f'<rect width="{width}" height="{height}" fill="{background}"/>' if background else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">{fill}{body}</svg>\n'


def lockup(color):
    """Mark plus "Chao 600" wordmark, cap height centered on the mark."""
    h = 128
    size = 0.44 * h / (cap_height(BLACK, 1) or 0.7)
    d, advance, _ = shape(BLACK, "Chao 600", size)
    x = h * 1.25
    baseline = h / 2 + cap_height(BLACK, size) / 2
    body = (f'<g transform="scale({h / 1024})">{mark(True)}</g>'
            f'<path transform="translate({x:.1f} {baseline:.1f})" fill="{color}" d="{d}"/>')
    return svg(round(x + advance + 4), h, body)


def social_card():
    """1200×630 preview for links shared on WhatsApp, X, etc."""
    w, h, m = 1200, 630, 240
    left = 104
    text_x = left + m + 64
    title, _, _ = shape(BLACK, "Chao 600", 112)
    line1, _, _ = shape(BOLD, "Bloquea las llamadas", 46)
    line2, _, _ = shape(BOLD, "600 y 809 en tu iPhone.", 46)
    body = (f'<g transform="translate({left} {(h - m) / 2}) scale({m / 1024})">{mark(True)}</g>'
            f'<path transform="translate({text_x} 284)" fill="{INK}" d="{title}"/>'
            f'<path transform="translate({text_x} 366)" fill="{MUTED}" d="{line1}"/>'
            f'<path transform="translate({text_x} 424)" fill="{MUTED}" d="{line2}"/>')
    return svg(w, h, body, background=PAPER)


def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    print("wrote", path.relative_to(ROOT))


def png(source, target, width, height=None, opaque=False):
    raster = subprocess.run(["rsvg-convert", "-w", str(width), "-h", str(height or width), str(source)],
                            check=True, capture_output=True).stdout
    flags = ["-background", RED_BOTTOM, "-alpha", "remove", "-alpha", "off"] if opaque else []
    subprocess.run(["magick", "png:-", *flags, str(target)], input=raster, check=True)
    print("wrote", target.relative_to(ROOT))


write(BRANDING / "icon.svg", svg(1024, 1024, mark(False)))
write(BRANDING / "logo.svg", svg(1024, 1024, mark(True)))
write(BRANDING / "logo-horizontal.svg", lockup(INK))
write(BRANDING / "logo-horizontal-white.svg", lockup(INK_ON_DARK))
write(BRANDING / "og.svg", social_card())

png(BRANDING / "icon.svg", APP_ICON, 1024, opaque=True)
png(BRANDING / "logo.svg", BRANDING / "logo.png", 1024)
for name in ("logo.svg", "logo-horizontal.svg", "logo-horizontal-white.svg"):
    write(SITE / name, (BRANDING / name).read_text())
write(SITE / "favicon.svg", (BRANDING / "logo.svg").read_text())
png(BRANDING / "logo.svg", SITE / "favicon-32.png", 32)
png(BRANDING / "icon.svg", SITE / "apple-touch-icon.png", 180, opaque=True)
png(BRANDING / "og.svg", SITE / "og.png", 1200, 630)
