"""The itch.io cover and click-to-play background (docs/specs/itch.md §8.1 route A, §8.4).

    uv run --project tools/marketing python tools/marketing/compose_cover.py \
        --capture <title_bare_NN.png> --globe <title_globe.json> [--align left|center] \
        [--out marketing/itch] [--preview <dir>]

The inputs come from `tools/marketing/itch_capture.gd --mode=title`: one frame of
the title screen with its menu and caption hidden, and where the globe sits in
it. The globe is cut out of that frame with a soft edge into the backdrop's ink,
scaled once and set into the lower seven tenths of a 1260 × 1000 canvas; the
word and the subtitle are typeset into the dark upper part with the game's own
fonts and colours. Nothing else is drawn.

Writes, per title variant (itch.md §2.1, switch TITLE — the recommended one
without a suffix): `cover_1260x1000.png` and `cover_630x500.png`; and once
`click_to_play_1280x720.png`. `--preview` also writes each cover at 315 × 250 and
158 × 125, the sizes itch shows it at, to look at. Reproducible: the same inputs
give the same files.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "assets" / "fonts"
WORD_FONT = FONTS / "SpaceGrotesk-Variable.ttf"
SUBTITLE_FONT = FONTS / "JetBrainsMono-Medium.ttf"
# Space Grotesk's weight axis: SemiBold.
WORD_WEIGHT = 600

# ui/theme/ui_tokens.gd, the cold palette.
INK = (0x07, 0x09, 0x0C)
TEXT_0 = (0xDC, 0xE6, 0xEE)
TEXT_1 = (0x93, 0xA6, 0xB5)

COVER = (1260, 1000)
COVER_SMALL = (630, 500)
PREVIEWS = ((315, 250), (158, 125))
CLICK_TO_PLAY = (1280, 720)
# §8.4: darkened to at most 60 % brightness.
CLICK_TO_PLAY_BRIGHTNESS = 0.6

WORD = "DOOMSDAY"
# §2.1: file suffix → subtitle; the recommended variant (A) has no suffix.
VARIANTS = {"": "Rogue Instance", "_off-switch": "Off-Switch", "_training-run": "Training Run"}

# §8.1: the upper 30 % stays dark for the type; the globe's heart in the
# central third; margins 6 %; cap heights ≥ 12 % (word) and ≥ 4.5 % (subtitle).
DARK_TOP = 0.30
MARGIN = 0.06
WORD_CAP = 0.125
SUBTITLE_CAP = 0.047
# The globe's diameter on the cover, as a share of the cover's height: its
# centre then lands at 0.30 + 0.32 = 0.62, inside the central third.
GLOBE_SHARE = 0.64
# The cut-out: full strength to just past the rim, gone at this many radii.
FADE_FROM = 1.03
FADE_TO = 1.22
# The line under the word, as a share of the cover's height.
LINE_GAP = 0.045


def cap_height(font: ImageFont.FreeTypeFont) -> int:
    left, top, right, bottom = font.getbbox("H")
    return bottom - top


def font_for_cap(path: Path, cap_px: float, weight: int | None = None) -> ImageFont.FreeTypeFont:
    """The smallest size whose capital H is at least `cap_px` tall."""
    size = max(4, int(cap_px))
    while True:
        font = ImageFont.truetype(str(path), size)
        if weight is not None:
            font.set_variation_by_axes([weight])
        if cap_height(font) >= cap_px:
            return font
        size += 1


def relative_luminance(rgb: tuple[int, int, int]) -> float:
    def channel(value: int) -> float:
        c = value / 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (channel(v) for v in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    la, lb = sorted((relative_luminance(a), relative_luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def globe_layer(capture: Image.Image, globe: dict) -> Image.Image:
    """The globe and a ring of its backdrop, square, with a soft alpha edge."""
    diameter = min(float(globe["width"]), float(globe["height"]))
    cx = float(globe["x"]) + float(globe["width"]) / 2.0
    cy = float(globe["y"]) + float(globe["height"]) / 2.0
    half = diameter / 2.0 * FADE_TO
    box = (round(cx - half), round(cy - half), round(cx + half), round(cy + half))
    # Past the frame's edge the backdrop is ink too.
    square = Image.new("RGB", (box[2] - box[0], box[3] - box[1]), INK)
    square.paste(capture.crop(box), (0, 0))
    target = round(COVER[1] * GLOBE_SHARE * FADE_TO)
    square = square.resize((target, target), Image.Resampling.LANCZOS)
    mask = Image.new("L", (target, target), 0)
    draw = ImageDraw.Draw(mask)
    centre = target / 2.0
    radius = target / 2.0 / FADE_TO
    steps = 64
    for i in range(steps, -1, -1):
        t = i / steps
        r = radius * (FADE_FROM + (FADE_TO - FADE_FROM) * t)
        draw.ellipse((centre - r, centre - r, centre + r, centre + r), fill=round(255 * (1.0 - t)))
    square.putalpha(mask.filter(ImageFilter.GaussianBlur(2)))
    return square


def compose(capture: Image.Image, globe: dict, subtitle: str, align: str) -> Image.Image:
    width, height = COVER
    cover = Image.new("RGB", COVER, INK)
    layer = globe_layer(capture, globe)
    globe_diameter = height * GLOBE_SHARE
    centre_y = height * DARK_TOP + globe_diameter / 2.0
    cover.paste(layer, (round(width / 2.0 - layer.width / 2.0),
                        round(centre_y - layer.height / 2.0)), layer)
    draw = ImageDraw.Draw(cover)
    word_font = font_for_cap(WORD_FONT, height * WORD_CAP, WORD_WEIGHT)
    subtitle_font = font_for_cap(SUBTITLE_FONT, height * SUBTITLE_CAP)
    word_box = draw.textbbox((0, 0), WORD, font=word_font)
    sub_box = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    word_h = word_box[3] - word_box[1]
    sub_h = sub_box[3] - sub_box[1]
    block = word_h + height * LINE_GAP + sub_h
    top = (height * DARK_TOP - block) / 2.0
    margin = width * MARGIN
    for text, font, box, y, colour in (
            (WORD, word_font, word_box, top, TEXT_0),
            (subtitle, subtitle_font, sub_box, top + word_h + height * LINE_GAP, TEXT_1)):
        text_w = box[2] - box[0]
        x = margin if align == "left" else (width - text_w) / 2.0
        draw.text((x - box[0], y - box[1]), text, font=font, fill=colour)
    return cover


def click_to_play(capture: Image.Image) -> Image.Image:
    frame = capture.convert("RGB")
    target_ratio = CLICK_TO_PLAY[0] / CLICK_TO_PLAY[1]
    if frame.width / frame.height > target_ratio:
        w = round(frame.height * target_ratio)
        frame = frame.crop(((frame.width - w) // 2, 0, (frame.width - w) // 2 + w, frame.height))
    else:
        h = round(frame.width / target_ratio)
        frame = frame.crop((0, (frame.height - h) // 2, frame.width, (frame.height - h) // 2 + h))
    frame = frame.resize(CLICK_TO_PLAY, Image.Resampling.LANCZOS)
    return frame.point(lambda v: round(v * CLICK_TO_PLAY_BRIGHTNESS))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--capture", type=Path, required=True)
    parser.add_argument("--globe", type=Path, required=True)
    parser.add_argument("--align", choices=("left", "center"), default="center")
    parser.add_argument("--out", type=Path, default=ROOT / "marketing" / "itch")
    parser.add_argument("--preview", type=Path, default=None)
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    capture = Image.open(args.capture).convert("RGB")
    globe = json.loads(args.globe.read_text(encoding="utf-8"))
    args.out.mkdir(parents=True, exist_ok=True)
    print(f"compose_cover: word on ink {contrast(TEXT_0, INK):.1f}:1, "
          f"subtitle on ink {contrast(TEXT_1, INK):.1f}:1 (itch.md §8.1: ≥ 7:1 for the word)")
    for suffix, subtitle in VARIANTS.items():
        cover = compose(capture, globe, subtitle, args.align)
        big = args.out / f"cover{suffix}_1260x1000.png"
        small = args.out / f"cover{suffix}_630x500.png"
        cover.save(big, optimize=True)
        cover.resize(COVER_SMALL, Image.Resampling.LANCZOS).save(small, optimize=True)
        print(f"compose_cover: {big.name}, {small.name}")
        if args.preview is not None:
            args.preview.mkdir(parents=True, exist_ok=True)
            for size in PREVIEWS:
                name = f"cover{suffix}_{args.align}_{size[0]}x{size[1]}.png"
                cover.resize(size, Image.Resampling.LANCZOS).save(args.preview / name)
    background = args.out / "click_to_play_1280x720.png"
    click_to_play(capture).save(background, optimize=True)
    print(f"compose_cover: {background.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
