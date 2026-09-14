"""Register generated art to original sprite bounds; cleanup needs explicit opt-in."""

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ASSETS = {
    "cocoon": "assets/base/pupation/cocoon.png",
    "cocoon_open": "assets/base/pupation/cocoon_open.png",
    "arrow": "assets/weapons/bow/arrow.png",
    "spore_bomb_projectile": "assets/weapons/mortar/spore_bomb_projectile.png",
    "horn_projectile": "assets/weapons/giant_horn/horn_projectile.png",
}


def components(candidate):
    """Return four-connected regions as horizontal pixel runs."""
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
    return sorted(groups.values(), key=lambda spans: sum(b - a for _, a, b in spans), reverse=True)


def cutout(source, expected_components):
    rgb = np.array(source.convert("RGB"), dtype=np.int16)
    if source.mode == "RGBA":
        # The generated arrow includes isolated near-transparent flecks.
        alpha = np.array(source.getchannel("A"))
        candidate = alpha > 12
    else:
        # Bright neutral checkerboards sit outside an enclosing dark outline.
        # Filling from outside protects every original interior color.
        ink = (rgb.max(axis=2) < 90) | (np.ptp(rgb, axis=2) > 26)
        flood = Image.new("L", (source.width + 2, source.height + 2))
        flood.paste(Image.fromarray(np.uint8(ink) * 255), (1, 1))
        ImageDraw.floodfill(flood, (0, 0), 128)
        candidate = np.asarray(flood)[1:-1, 1:-1] != 128
        alpha = np.full(candidate.shape, 255, dtype=np.uint8)
    regions = components(candidate)
    if len(regions) < expected_components:
        raise ValueError("Missing a sprite component")
    keep = np.zeros(candidate.shape, dtype=bool)
    for spans in regions[:expected_components]:
        for y, start, end in spans:
            keep[y, start:end] = True
    if source.mode != "RGBA":
        # Clean neutral checkerboard contamination from the ink boundary.
        padded = np.pad(keep, 1)
        interior = (padded[:-2, 1:-1] & padded[2:, 1:-1]
                    & padded[1:-1, :-2] & padded[1:-1, 2:])
        fringe = keep & ~interior & (np.ptp(rgb, axis=2) < 18) & (rgb.max(axis=2) > 40)
        rgb[fringe] = (13, 14, 9)
    alpha[~keep] = 0
    rgb[~keep] = 0
    result = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
    result.putalpha(Image.fromarray(alpha))
    return result


def save(image, path):
    temporary = path.with_suffix(".png.tmp")
    image.save(temporary, format="PNG")
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--remove-background", action="store_true")
    args = parser.parse_args()
    if not args.remove_background:
        parser.error("Pass --remove-background only after user authorization")
    (HERE / "cutouts").mkdir(exist_ok=True)
    report = []
    for name, relative in ASSETS.items():
        original = Image.open(HERE / "before" / (name + ".png")).convert("RGBA")
        source = Image.open(HERE / "source" / (name + ".png"))
        cut = cutout(source, 2 if name == "horn_projectile" else 1)
        save(cut, HERE / "cutouts" / (name + ".png"))
        bounds = original.getchannel("A").getbbox()
        x0, y0, x1, y1 = bounds
        sprite = cut.crop(cut.getchannel("A").getbbox()).resize(
            (x1 - x0, y1 - y0), Image.Resampling.LANCZOS)
        final = Image.new("RGBA", original.size)
        final.paste(sprite, (x0, y0))
        path = ROOT / relative
        save(final, path)
        assert final.size == original.size
        assert final.getchannel("A").getbbox() == bounds
        assert final.getchannel("A").getextrema() == (0, 255)
        visible_regions = components(np.array(final.getchannel("A")) > 127)
        substantial = [r for r in visible_regions if sum(b - a for _, a, b in r) > 20]
        assert len(substantial) == (2 if name == "horn_projectile" else 1)
        report.append({
            "name": name, "path": relative, "size": final.size, "bounds": bounds,
            "source_mode": source.mode, "alpha_range": [0, 255],
            "visible_components": len(substantial),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        })
        print(name, final.size, bounds, "OK")
    (HERE / "validation.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
