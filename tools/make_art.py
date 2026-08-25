#!/usr/bin/env python3
"""Generate the vibe-shader pack icon."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ICON = ROOT / "pack.png"
SCALE = 2
CANVAS_SIZE = 512


def rgba(hex_value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    hex_value = hex_value.lstrip("#")
    red, green, blue = (int(hex_value[index : index + 2], 16) for index in (0, 2, 4))
    return red, green, blue, alpha


def icon_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = (
        "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/noto/NotoSans-Bold.ttf",
        "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf",
    )
    for candidate in candidates:
        if Path(candidate).is_file():
            return ImageFont.truetype(candidate, size * SCALE)
    try:
        return ImageFont.load_default(size * SCALE)
    except TypeError:
        return ImageFont.load_default()


icon = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), rgba("#050817"))
draw = ImageDraw.Draw(icon, "RGBA")

for y in range(CANVAS_SIZE):
    blend = y / (CANVAS_SIZE - 1)
    color = (
        int(4 + 20 * blend),
        int(8 + 22 * blend),
        int(24 + 48 * blend),
        255,
    )
    draw.line((0, y, CANVAS_SIZE, y), fill=color)

# Eclipse glow.
glow = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
glow_draw = ImageDraw.Draw(glow, "RGBA")
for radius, alpha in ((160, 18), (115, 35), (82, 100)):
    glow_draw.ellipse(
        (256 - radius, 160 - radius, 256 + radius, 160 + radius),
        fill=(255, 114, 44, alpha),
    )
glow = glow.filter(ImageFilter.GaussianBlur(24))
icon = Image.alpha_composite(icon, glow)
draw = ImageDraw.Draw(icon, "RGBA")
draw.ellipse((184, 88, 328, 232), fill=rgba("#02030a"))
draw.arc(
    (181, 85, 331, 235),
    270,
    95,
    fill=(255, 228, 159, 255),
    width=6,
)

# Voxel cube logo.
center_x, center_y = 256, 316
cube_width, cube_height = 226, 116
draw.polygon(
    [
        (center_x, center_y - 104),
        (center_x + cube_width // 2, center_y - 46),
        (center_x, center_y + 12),
        (center_x - cube_width // 2, center_y - 46),
    ],
    fill=rgba("#5ce6b2"),
)
draw.polygon(
    [
        (center_x - cube_width // 2, center_y - 46),
        (center_x, center_y + 12),
        (center_x, center_y + 152),
        (center_x - cube_width // 2, center_y + 92),
    ],
    fill=rgba("#194f4b"),
)
draw.polygon(
    [
        (center_x + cube_width // 2, center_y - 46),
        (center_x, center_y + 12),
        (center_x, center_y + 152),
        (center_x + cube_width // 2, center_y + 92),
    ],
    fill=rgba("#27356a"),
)
draw.line(
    [
        (center_x, center_y - 104),
        (center_x + cube_width // 2, center_y - 46),
        (center_x, center_y + 12),
        (center_x - cube_width // 2, center_y - 46),
        (center_x, center_y - 104),
    ],
    fill=(182, 252, 255, 230),
    width=5,
)

# vibe-shader monogram.
draw.text(
    (175, 290),
    "VS",
    font=icon_font(48),
    fill=(238, 249, 255, 245),
    stroke_width=2,
    stroke_fill=(0, 0, 0, 150),
)

icon = icon.resize((256, 256), Image.Resampling.LANCZOS).convert("RGBA")
icon.save(ICON)
print(ICON)
