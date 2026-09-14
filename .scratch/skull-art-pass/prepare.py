"""Clean the approved skull redraw and preserve its existing UI registration."""

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
source = Image.open(HERE / "source/skull.png")
original = Image.open(HERE / "before/skull.png").convert("RGBA")
rgb = np.array(source.convert("RGB"), dtype=np.int16)
ink = (rgb.max(axis=2) < 95) | (np.ptp(rgb, axis=2) > 26)
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
bounds = original.getchannel("A").getbbox()
x0, y0, x1, y1 = bounds
sprite = cutout.crop(cutout.getchannel("A").getbbox()).resize(
    (x1 - x0, y1 - y0), Image.Resampling.LANCZOS)
final = Image.new("RGBA", original.size)
final.paste(sprite, (x0, y0))
assert final.size == (128, 128)
assert final.getchannel("A").getbbox() == bounds
assert final.getchannel("A").getextrema() == (0, 255)
for point in ((45, 58), (82, 58), (64, 80)):
    assert final.getpixel(point)[3] == 255, "Skull cavities must stay opaque"
target = ROOT / "assets/base/combat_progress_track/skull.png"
temporary = target.with_suffix(".png.tmp")
final.save(temporary, format="PNG")
temporary.replace(target)
report = {
    "path": str(target.relative_to(ROOT)), "size": final.size,
    "bounds": bounds, "alpha_range": [0, 255], "cavities_opaque": True,
    "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
}
(HERE / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report))
