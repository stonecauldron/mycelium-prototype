"""Apply the previously authorized background cleanup and preserve icon bounds."""

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
TARGET = ROOT / "assets/base/shop/padlock_locked.png"
source = Image.open(HERE / "source/padlock_locked.png")
original = Image.open(HERE / "before/padlock_locked.png").convert("RGBA")
rgb = np.array(source.convert("RGB"), dtype=np.int16)

# Bright neutral checkerboard is separated from the art by dark ink. Flood
# the exterior and the enclosed arch aperture; the black keyhole stays opaque.
ink = (rgb.max(axis=2) < 95) | (np.ptp(rgb, axis=2) > 26)
mask = Image.new("L", (source.width + 2, source.height + 2))
mask.paste(Image.fromarray(np.uint8(ink) * 255), (1, 1))
ImageDraw.floodfill(mask, (0, 0), 128)
hole = (round(source.width * 0.5) + 1, round(source.height * 0.32) + 1)
assert mask.getpixel(hole) == 0, "The arch cleanup seed must be in background"
ImageDraw.floodfill(mask, hole, 128)
keep = np.asarray(mask)[1:-1, 1:-1] != 128

# Keep the single connected padlock, removing any detached background flecks.
connected = Image.fromarray(np.uint8(keep) * 255).copy()
body = (round(source.width * 0.5), round(source.height * 0.6))
assert connected.getpixel(body) == 255
ImageDraw.floodfill(connected, body, 128)
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
assert final.size == (512, 512)
assert final.getchannel("A").getbbox() == bounds
assert final.getchannel("A").getextrema() == (0, 255)
assert final.getpixel((256, 160))[3] == 0, "Arch aperture must remain transparent"
assert final.getpixel((256, 320))[3] == 255, "Keyhole must remain opaque"
temporary = TARGET.with_suffix(".png.tmp")
final.save(temporary, format="PNG")
temporary.replace(TARGET)
report = {
    "path": str(TARGET.relative_to(ROOT)), "size": final.size,
    "bounds": bounds, "alpha_range": [0, 255],
    "arch_aperture_transparent": True, "keyhole_opaque": True,
    "sha256": hashlib.sha256(TARGET.read_bytes()).hexdigest(),
}
(HERE / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report))
