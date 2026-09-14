"""Clean the generated arrow and export a small, readable gameplay texture."""

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
source = Image.open(HERE / "source/arrow.png")
rgb = np.array(source.convert("RGB"), dtype=np.int16)
ink = (rgb.max(axis=2) < 90) | (np.ptp(rgb, axis=2) > 26)
mask = Image.new("L", (source.width + 2, source.height + 2))
mask.paste(Image.fromarray(np.uint8(ink) * 255), (1, 1))
ImageDraw.floodfill(mask, (0, 0), 128)
keep = np.asarray(mask)[1:-1, 1:-1] != 128
connected = Image.fromarray(np.uint8(keep) * 255).copy()
seed = (source.width // 2, source.height // 2)
assert connected.getpixel(seed) == 255
ImageDraw.floodfill(connected, seed, 128)
keep = np.asarray(connected) == 128
padded = np.pad(keep, 1)
interior = (padded[:-2, 1:-1] & padded[2:, 1:-1]
            & padded[1:-1, :-2] & padded[1:-1, 2:])
fringe = keep & ~interior & (np.ptp(rgb, axis=2) < 18) & (rgb.max(axis=2) > 40)
rgb[fringe] = (13, 14, 9)
rgb[~keep] = 0
cutout = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
cutout.putalpha(Image.fromarray(np.uint8(keep) * 255))
cutout.save(HERE / "cutout.png")
sprite = cutout.crop(cutout.getchannel("A").getbbox()).resize((61, 16), Image.Resampling.LANCZOS)
final = Image.new("RGBA", (64, 24))
final.paste(sprite, (1, 4))
assert final.getchannel("A").getbbox() == (1, 4, 62, 20)
assert final.getchannel("A").getextrema() == (0, 255)
target = ROOT / "assets/weapons/bow/arrow.png"
temporary = target.with_suffix(".png.tmp")
final.save(temporary, format="PNG")
temporary.replace(target)
report = {
    "path": str(target.relative_to(ROOT)), "size": final.size,
    "bounds": final.getchannel("A").getbbox(), "render_scale": 0.8,
    "visual_offset": [0.25, 0.0], "world_length": 48.8,
    "world_height": 12.8, "alpha_range": [0, 255],
    "previous_size": [512, 512], "pixel_count_reduction_percent": 99.4140625,
}
(HERE / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report))
