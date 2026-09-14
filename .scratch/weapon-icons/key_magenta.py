"""Remove a magenta backdrop without eroding the icon's dark outlines."""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def key_magenta(source: Path) -> Image.Image:
    rgb = np.asarray(Image.open(source).convert("RGB"), dtype=np.float32)
    # Sample the actual generated key color, allowing small compression noise.
    border = np.concatenate((rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]))
    background = np.median(border, axis=0)
    key_chroma = min(background[0], background[2]) - background[1]
    if key_chroma < 200:
        raise ValueError(f"Expected a solid magenta background: {source}")

    chroma = np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - rgb[:, :, 1]
    keyed = chroma > 8
    # Only the near-black outer ink borders the key. Recover edge coverage from
    # its mixture with magenta, retaining antialiasing instead of shrinking it.
    ink_chroma = -7.0
    alpha = np.ones(chroma.shape, dtype=np.float32)
    alpha[keyed] = np.clip(
        (key_chroma - chroma[keyed]) / (key_chroma - ink_chroma), 0, 1
    )
    alpha[chroma >= key_chroma - 12] = 0

    visible_edge = keyed & (alpha > 0)
    coverage = alpha[visible_edge, None]
    rgb[visible_edge] = np.clip(
        (rgb[visible_edge] - (1 - coverage) * background) / coverage, 0, 255
    )
    # Remove residual pink from noisy edge samples; the actual ink is green-black.
    rgb[:, :, 0][visible_edge] = np.minimum(
        rgb[:, :, 0][visible_edge], rgb[:, :, 1][visible_edge]
    )
    rgb[:, :, 2][visible_edge] = np.minimum(
        rgb[:, :, 2][visible_edge], rgb[:, :, 1][visible_edge]
    )
    rgb[alpha == 0] = 0
    rgba = np.dstack((rgb, alpha * 255)).round().astype(np.uint8)
    return Image.fromarray(rgba)


def resize_icon(icon: Image.Image, size: int) -> Image.Image:
    # Resize with premultiplied alpha, then remove any tiny color overshoot from
    # the resampling filter. This leaves the dark contour's coverage intact.
    icon = icon.resize((size, size), Image.Resampling.LANCZOS)
    rgba = np.array(icon)
    rgb = rgba[:, :, :3].astype(np.int16)
    spill = (np.minimum(rgb[:, :, 0], rgb[:, :, 2]) > rgb[:, :, 1]) & (
        rgba[:, :, 3] < 128
    )
    rgba[:, :, 0][spill] = np.minimum(rgba[:, :, 0][spill], rgba[:, :, 1][spill])
    rgba[:, :, 2][spill] = np.minimum(rgba[:, :, 2][spill], rgba[:, :, 1][spill])
    rgba[rgba[:, :, 3] < 4] = 0
    # Lanczos can leave barely visible ringing in otherwise empty canvas margins.
    # Clear that outermost fringe without touching the icon's actual contour.
    for edge in (rgba[0], rgba[-1], rgba[:, 0], rgba[:, -1]):
        edge[edge[:, 3] < 8] = 0
    return Image.fromarray(rgba)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--size", type=int)
    args = parser.parse_args()
    icon = key_magenta(args.source)
    if args.size:
        icon = resize_icon(icon, args.size)
    args.destination.parent.mkdir(parents=True, exist_ok=True)
    icon.save(args.destination)
