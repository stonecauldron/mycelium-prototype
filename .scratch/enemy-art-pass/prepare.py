"""Register approved enemy artwork to the existing PNG and walk-atlas layout.

The user authorized programmatic background removal in this task. Original
geometry comes from the recorded baseline commit; gameplay nodes never move.
"""

import argparse
import io
import json
import re
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BASE_REV = json.loads((HERE / "generation.json").read_text())["baseline_commit"]


def components(candidate):
    """Find connected regions by scanline, without extra dependencies."""
    parents, runs, previous = [], [], []

    def root(index):
        while parents[index] != index:
            parents[index] = parents[parents[index]]
            index = parents[index]
        return index

    for y, row in enumerate(candidate):
        edges = np.diff(np.pad(row.astype(np.int8), (1, 1)))
        current = []
        for start, end in zip(np.where(edges == 1)[0], np.where(edges == -1)[0]):
            label = len(parents)
            parents.append(label)
            for old_start, old_end, old_label in previous:
                if old_start < end and old_end > start:
                    parents[root(label)] = root(old_label)
            current.append((start, end, label))
            runs.append((y, start, end, label))
        previous = current
    groups = {}
    for y, start, end, label in runs:
        groups.setdefault(root(label), []).append((y, start, end))
    return groups.values()


def original(path):
    return Image.open(io.BytesIO(subprocess.check_output(
        ["git", "show", f"{BASE_REV}:{path.relative_to(ROOT)}"], cwd=ROOT
    ))).convert("RGBA")


def cutout(image, allow_removal):
    if image.mode == "RGBA" and image.getchannel("A").getextrema()[0] == 0:
        return image.copy()
    if not allow_removal:
        raise ValueError("Opaque source: background removal requires authorization")
    rgb = np.asarray(image.convert("RGB"), dtype=np.int16)
    # All sprites have a dark enclosing outline; the generated checkerboards
    # are neutral and bright. Fill the outline without touching interior colors.
    ink = (rgb.max(axis=2) < 95) | (np.ptp(rgb, axis=2) > 26)
    mask = Image.fromarray(np.uint8(ink) * 255)
    flood = Image.new("L", (mask.width + 2, mask.height + 2), 0)
    flood.paste(mask, (1, 1))
    ImageDraw.floodfill(flood, (0, 0), 128)
    filled = np.asarray(flood)[1:-1, 1:-1] != 128
    # Enclosed gaps can contain the same checkerboard as the exterior. Identify
    # its alternating neutral values; retain uniform pale eyes and highlights.
    neutral = filled & (np.ptp(rgb, axis=2) < 13) & (rgb.max(axis=2) > 100)
    for spans in components(neutral):
        if sum(end - start for _, start, end in spans) < 12:
            continue
        pixels = np.concatenate([rgb[y, start:end] for y, start, end in spans])
        luminance = pixels.mean(axis=1)
        if np.percentile(luminance, 95) - np.percentile(luminance, 5) > 32:
            for y, start, end in spans:
                filled[y, start:end] = False
    # Suppress disconnected background speckles. These designs are each a
    # single connected character, including the tiny feet and twig tips.
    largest = max(components(filled), key=lambda spans: sum(b - a for _, a, b in spans))
    filled[:] = False
    for y, start, end in largest:
        filled[y, start:end] = True
    # The outer contour is dark ink. Remove gray matte contamination from its
    # boundary before downsampling creates the final antialiased alpha edge.
    padded = np.pad(filled, 1, constant_values=False)
    interior = (padded[:-2, 1:-1] & padded[2:, 1:-1]
                & padded[1:-1, :-2] & padded[1:-1, 2:])
    fringe = filled & ~interior & (np.ptp(rgb, axis=2) < 18) & (rgb.max(axis=2) > 40)
    rgb[fringe] = (13, 12, 8)
    rgb[~filled] = 0
    result = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
    result.putalpha(Image.fromarray(np.uint8(filled) * 255))
    return result


def save_png(image, path):
    # A running Godot editor may watch these files. Never expose a partial PNG.
    temporary = path.with_suffix(".png.tmp")
    image.save(temporary, format="PNG")
    temporary.replace(path)


def trim(image):
    bounds = image.getchannel("A").point(lambda p: 255 if p > 10 else 0).getbbox()
    if bounds is None:
        raise ValueError("Empty sprite")
    return image.crop(bounds)


def register(image, size, bounds):
    result = Image.new("RGBA", size)
    x0, y0, x1, y1 = bounds
    sprite = trim(image).resize((x1 - x0, y1 - y0), Image.Resampling.LANCZOS)
    result.paste(sprite, (x0, y0))
    return result


def main():
    manifest = json.loads((HERE / "sources.json").read_text())
    parser = argparse.ArgumentParser()
    parser.add_argument("--remove-background", action="store_true")
    parser.add_argument("--only", nargs="+", choices=list(manifest))
    args = parser.parse_args()
    before_folder = Path("/tmp/mycelium-enemy-art-before")
    before_folder.mkdir(parents=True, exist_ok=True)
    for name, source in manifest.items():
        if args.only and name not in args.only:
            continue
        folder = ROOT / "assets/units/enemies" / name
        idle_path = folder / f"{name}.png"
        idle_before = original(idle_path)
        save_png(idle_before, before_folder / f"{name}.png")
        image = Image.open(HERE / source)
        walk_path = folder / f"{name}_walk.png"
        if walk_path.exists():
            cells = []
            for row in range(2):
                for col in range(2):
                    cell = image.crop((
                        col * image.width // 2, row * image.height // 2,
                        (col + 1) * image.width // 2, (row + 1) * image.height // 2,
                    ))
                    cells.append(cutout(cell, args.remove_background))
            idle = cells[0]
            scene = (folder / f"{name}_appearance.tscn").read_text()
            regions = [tuple(map(int, values.split(", "))) for values in
                       re.findall(r"region = Rect2\(([^)]+)\)", scene)]
            walk_before = original(walk_path)
            sheet = Image.new("RGBA", walk_before.size)
            for cell, (x, y, width, height) in zip(cells, regions, strict=True):
                previous_frame = walk_before.crop((x, y, x + width, y + height))
                frame = register(cell, previous_frame.size, previous_frame.getbbox())
                sheet.paste(frame, (x, y))
            save_png(sheet, walk_path)
        else:
            idle = cutout(image, args.remove_background)
        save_png(register(idle, idle_before.size, idle_before.getbbox()), idle_path)
        print(name, "idle + four walk frames" if walk_path.exists() else "idle")


if __name__ == "__main__":
    main()
