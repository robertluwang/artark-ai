#!/usr/bin/env python3
"""fit-banner.py — normalise a banner image for social cards.

Social platforms render link previews at roughly 1.91:1 (1200x630). An image
with a different ratio gets centre-cropped by the platform, and you do not get
to choose where the crop lands - titles at the top or bottom edge are the usual
casualties.

Modes:
  crop  Scale to cover 1200x630 and centre-crop. Minimal loss when the source
        ratio is already close (e.g. 16:9), but cuts content when it is not.
  pad   Scale to fit inside 1200x630 and pad with a colour sampled from the
        image border. Loses nothing, adds bars.
  auto  crop when the source ratio is near the target, pad otherwise.
        (default)

Usage:
  ./scripts/fit-banner.py in.png out.png
  ./scripts/fit-banner.py in.png out.png --mode pad
  ./scripts/fit-banner.py banner.png banner.png      # in place
"""

import argparse
import os
import sys

try:
    from PIL import Image, ImageStat
except ImportError:
    sys.exit("ERROR: Pillow is required — pip install pillow")

TARGET_W, TARGET_H = 1200, 630
TARGET_RATIO = TARGET_W / TARGET_H          # 1.905
# Within this much of the target, cropping costs little; beyond it, pad instead.
CROP_TOLERANCE = 0.15


def border_colour(im):
    """Median colour of a thin frame around the image — a good pad colour."""
    w, h = im.size
    edge = max(2, min(w, h) // 50)
    strips = [
        im.crop((0, 0, w, edge)),
        im.crop((0, h - edge, w, h)),
        im.crop((0, 0, edge, h)),
        im.crop((w - edge, 0, w, h)),
    ]
    px = [round(c) for s in strips for c in ImageStat.Stat(s).median[:3]]
    n = len(px) // 3
    return tuple(sum(px[i::3]) // n for i in range(3))


def fit(im, mode, allow_upscale=False):
    ratio = im.size[0] / im.size[1]

    if mode == "auto":
        mode = "crop" if abs(ratio - TARGET_RATIO) <= CROP_TOLERANCE else "pad"

    # Upscaling adds no detail and softens the image. If the source is smaller
    # than 1200x630, keep its resolution and only correct the aspect ratio.
    out_w, out_h = TARGET_W, TARGET_H
    if not allow_upscale and (im.size[0] < TARGET_W or im.size[1] < TARGET_H):
        if mode == "crop":
            out_w = min(im.size[0], round(im.size[1] * TARGET_RATIO))
        else:
            out_w = min(TARGET_W, im.size[0])
        out_h = max(1, round(out_w / TARGET_RATIO))

    if mode == "crop":
        scale = max(out_w / im.size[0], out_h / im.size[1])
        resized = im.resize(
            (max(out_w, round(im.size[0] * scale)),
             max(out_h, round(im.size[1] * scale))),
            Image.LANCZOS,
        )
        left = (resized.size[0] - out_w) // 2
        top = (resized.size[1] - out_h) // 2
        return resized.crop((left, top, left + out_w, top + out_h)), mode

    scale = min(out_w / im.size[0], out_h / im.size[1])
    resized = im.resize(
        (max(1, round(im.size[0] * scale)), max(1, round(im.size[1] * scale))),
        Image.LANCZOS,
    )
    canvas = Image.new("RGB", (out_w, out_h), border_colour(im))
    canvas.paste(
        resized,
        ((out_w - resized.size[0]) // 2, (out_h - resized.size[1]) // 2),
    )
    return canvas, mode


def main():
    ap = argparse.ArgumentParser(description="Fit a banner to 1200x630 for social cards.")
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--mode", choices=("auto", "crop", "pad"), default="auto")
    ap.add_argument("--allow-upscale", action="store_true",
                    help="scale small sources up to 1200x630 (softens them)")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    if not os.path.isfile(args.src):
        sys.exit(f"ERROR: {args.src} not found")

    before_kb = os.path.getsize(args.src) / 1024
    with Image.open(args.src) as im:
        im = im.convert("RGB")
        before = im.size
        out, used = fit(im, args.mode, args.allow_upscale)

    ext = os.path.splitext(args.dst)[1].lower()
    if ext in (".jpg", ".jpeg"):
        out.save(args.dst, quality=88, optimize=True, progressive=True)
    else:
        out.save(args.dst, optimize=True)

    if not args.quiet:
        after_kb = os.path.getsize(args.dst) / 1024
        print(
            f"{before[0]}x{before[1]} {before_kb:.0f}KB "
            f"-> {out.size[0]}x{out.size[1]} {after_kb:.0f}KB  ({used})"
        )


if __name__ == "__main__":
    main()
