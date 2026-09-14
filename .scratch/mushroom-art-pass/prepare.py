"""Clean approved ImageGen art and register it to existing mushroom atlas regions.

Semantic artwork comes from ImageGen. Code only removes the baked background,
resizes and positions layers; user authorized transparent-asset cleanup in this
conversation. Scenes, animations, mounts and mutation tinting stay unchanged.
"""
import io
import json
import re
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BASELINE = json.loads((HERE / 'baseline.json').read_text())


def original(path):
    data = subprocess.check_output(['git', 'show', f"{BASELINE['commit']}:{path.relative_to(ROOT)}"], cwd=ROOT)
    return Image.open(io.BytesIO(data)).convert('RGBA')


def components(candidate):
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
            for a, b, previous_label in previous:
                if a < end and b > start:
                    parents[root(label)] = root(previous_label)
            current.append((start, end, label))
            runs.append((y, start, end, label))
        previous = current
    groups = {}
    for y, start, end, label in runs:
        groups.setdefault(root(label), []).append((y, start, end))
    return groups.values()


def cutout(image):
    if image.mode == 'RGBA' and image.getchannel('A').getextrema()[0] == 0:
        return image.copy()
    rgb = np.asarray(image.convert('RGB'), dtype=np.int16).copy()
    # Enclosed light-gray areas are intentional tintable flesh and cap shading.
    # Remove only exterior background, never threshold the interior white fill.
    ink = (rgb.max(axis=2) < 100) | (np.ptp(rgb, axis=2) > 26)
    flood = Image.new('L', (image.width + 2, image.height + 2), 0)
    flood.paste(Image.fromarray(np.uint8(ink) * 255), (1, 1))
    ImageDraw.floodfill(flood, (0, 0), 128)
    filled = np.asarray(flood)[1:-1, 1:-1] != 128
    largest = max(components(filled), key=lambda spans: sum(b - a for _, a, b in spans))
    filled[:] = False
    for y, a, b in largest:
        filled[y, a:b] = True
    padded = np.pad(filled, 1, constant_values=False)
    interior = padded[:-2, 1:-1] & padded[2:, 1:-1] & padded[1:-1, :-2] & padded[1:-1, 2:]
    fringe = filled & ~interior & (np.ptp(rgb, axis=2) < 18) & (rgb.max(axis=2) > 40)
    rgb[fringe] = (10, 10, 8)
    rgb[~filled] = 0
    result = Image.fromarray(rgb.astype(np.uint8)).convert('RGBA')
    result.putalpha(Image.fromarray(np.uint8(filled) * 255))
    return result


def register(image, size, bounds):
    crop = image.getchannel('A').point(lambda value: 255 if value > 10 else 0).getbbox()
    if crop is None:
        raise ValueError('Empty sprite')
    x0, y0, x1, y1 = bounds
    sprite = image.crop(crop).resize((x1 - x0, y1 - y0), Image.Resampling.LANCZOS)
    result = Image.new('RGBA', size)
    result.paste(sprite, (x0, y0))
    return result


def save(image, path):
    temporary = path.with_suffix('.png.tmp')
    image.save(temporary, format='PNG')
    temporary.replace(path)


def region_box(region):
    x, y, w, h = region
    return (x, y, x + w, y + h)


def load_source(name):
    return Image.open(HERE / 'source' / f'{name}.png')


def sheet_frames(name, scene_path, target_path):
    image = load_source(name)
    regions = [tuple(map(int, values.split(', '))) for values in
               re.findall(r'region = Rect2\(([^)]+)\)', scene_path.read_text())]
    before = original(target_path)
    sheet = Image.new('RGBA', before.size)
    cells = []
    for i, region in enumerate(regions):
        column, row = i % 2, i // 2
        cell = cutout(image.crop((column * image.width // 2, row * image.height // 2,
                                 (column + 1) * image.width // 2, (row + 1) * image.height // 2)))
        cells.append(cell)
        frame_before = before.crop(region_box(region))
        frame = register(cell, frame_before.size, frame_before.getbbox())
        sheet.paste(frame, region[:2])
    save(sheet, target_path)
    return cells


def main():
    before_folder = Path('/tmp/mycelium-mushroom-art-before')
    before_folder.mkdir(parents=True, exist_ok=True)
    for relative_path in BASELINE['assets']:
        path = ROOT / relative_path
        save(original(path), before_folder / path.name)
    # Final user selection: keep only the banner/pole art. Mushroom units and
    # the flag bearer's idle body and walk sheet use the original artwork.
    folder = ROOT / 'assets/combat/flag_bearer'
    idle_path = folder / 'flag.png'
    before = original(idle_path)
    result = before.copy()
    region = (138, 26, 220, 619)
    previous = before.crop(region_box(region))
    result.paste(register(cutout(load_source('banner')), previous.size, previous.getbbox()), region[:2])
    save(result, idle_path)
    print('new banner/pole with the original flag bearer')


if __name__ == '__main__':
    main()
