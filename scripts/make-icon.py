"""Draws the app icon: a struck-through "600" on red. Run: python3 scripts/make-icon.py"""
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

SIZE = 1024
OUT = Path(__file__).resolve().parent.parent / "Chao600/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

# Vertical red gradient.
top, bottom = (255, 82, 82), (196, 18, 48)
background = Image.new("RGB", (SIZE, SIZE))
draw = ImageDraw.Draw(background)
for y in range(SIZE):
    t = y / (SIZE - 1)
    draw.line([(0, y), (SIZE, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))

# "600" as a white mask, centered on its ink.
font = ImageFont.truetype("/System/Library/Fonts/SFNSRounded.ttf", 360)
font.set_variation_by_name("Black")
text = Image.new("L", (SIZE, SIZE), 0)
left, top_, right, bottom_ = font.getbbox("600")
ImageDraw.Draw(text).text(((SIZE - (right - left)) / 2 - left, (SIZE - (bottom_ - top_)) / 2 - top_), "600", font=font, fill=255)

# Slash from bottom-left to top-right, with a gap cut out of the digits around it.
start, end = (200, 800), (824, 224)
gap = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(gap).line([start, end], fill=255, width=120)
slash = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(slash).line([start, end], fill=255, width=56)
for mask in (gap, slash):
    ImageDraw.Draw(mask).ellipse([start[0] - 28, start[1] - 28, start[0] + 28, start[1] + 28], fill=255)
    ImageDraw.Draw(mask).ellipse([end[0] - 28, end[1] - 28, end[0] + 28, end[1] + 28], fill=255)
ink = ImageChops.lighter(ImageChops.subtract(text, gap), slash)

icon = Image.composite(Image.new("RGB", (SIZE, SIZE), "white"), background, ink)
icon.save(OUT)
print(f"Wrote {OUT}")
