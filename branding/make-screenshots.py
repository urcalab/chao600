"""Frames raw 6.9" simulator screenshots (1320×2868) for the App Store: headline on red, app below.

Raw captures come from the Debug build launched with `-screenshot protected|loading|setup`
and go in branding/screenshots/raw/. Same requirements as make-logo.py.

Run: python3 branding/make-screenshots.py
"""
import base64
import importlib.util
import subprocess
from pathlib import Path

spec = importlib.util.spec_from_file_location("make_logo", Path(__file__).with_name("make-logo.py"))
logo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(logo)

W, H = 1320, 2868
SHOT_W = 1080
SHOT_TOP = 620
RADIUS = 88
SHOTS = logo.BRANDING / "screenshots"

FRAMES = [
    ("protected", ["Chao a las llamadas", "600 y 809"]),
    ("loading", ["11 millones de", "números bloqueados"]),
    ("setup", ["Se activa", "en un minuto"]),
]


def headline(lines, size=118, top=300, leading=1.18):
    paths = []
    for i, text in enumerate(lines):
        d, advance, _ = logo.shape(logo.BLACK, text, size)
        paths.append(f'<path transform="translate({(W - advance) / 2:.1f} {top + i * size * leading:.1f})" fill="#fff" d="{d}"/>')
    return "".join(paths)


def frame(raw, lines):
    shot_h = SHOT_W * H / W
    x = (W - SHOT_W) / 2
    data = base64.b64encode(raw.read_bytes()).decode()
    return f"""<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{logo.RED_TOP}"/><stop offset="1" stop-color="{logo.RED_BOTTOM}"/>
    </linearGradient>
    <clipPath id="screen"><rect x="{x}" y="{SHOT_TOP}" width="{SHOT_W}" height="{shot_h}" rx="{RADIUS}"/></clipPath>
    <filter id="shadow" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="24" stdDeviation="36" flood-color="#5a0012" flood-opacity="0.35"/>
    </filter>
  </defs>
  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  {headline(lines)}
  <rect x="{x}" y="{SHOT_TOP}" width="{SHOT_W}" height="{shot_h}" rx="{RADIUS}" fill="#fff" filter="url(#shadow)"/>
  <image x="{x}" y="{SHOT_TOP}" width="{SHOT_W}" height="{shot_h}" clip-path="url(#screen)" xlink:href="data:image/png;base64,{data}"/>
</svg>"""


if __name__ == "__main__":
    for i, (name, lines) in enumerate(FRAMES, start=1):
        svg_path = SHOTS / f"{i}-{name}.svg"
        svg_path.write_text(frame(SHOTS / "raw" / f"{name}.png", lines))
        target = SHOTS / f"{i}-{name}.png"
        raster = subprocess.run(["rsvg-convert", "-w", str(W), "-h", str(H), str(svg_path)],
                                check=True, capture_output=True).stdout
        subprocess.run(["magick", "png:-", "-background", logo.RED_BOTTOM, "-alpha", "remove", "-alpha", "off", str(target)],
                       input=raster, check=True)
        svg_path.unlink()
        print("wrote", target.relative_to(logo.ROOT))
