"""Remove generated mattes and register stemless cocoons at the existing bases."""

import hashlib
import importlib.util
import json
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
helper_spec = importlib.util.spec_from_file_location(
    "cocoon_art_helpers", HERE.parent / "cocoon-projectile-art-pass/prepare.py")
helpers = importlib.util.module_from_spec(helper_spec)
helper_spec.loader.exec_module(helpers)

reports = []
for name in ("cocoon", "cocoon_open"):
    before = Image.open(HERE / "before" / f"{name}.png").convert("RGBA")
    source = Image.open(HERE / "source" / f"{name}.png")
    # Background cleanup was explicitly authorized earlier in this conversation.
    cutout = helpers.cutout(source, 1)
    helpers.save(cutout, HERE / f"{name}_cutout.png")
    old_bounds = before.getchannel("A").getbbox()
    # Preserve the body width and base; leave the former stem area empty.
    bounds = (old_bounds[0], 62, old_bounds[2], old_bounds[3])
    x0, y0, x1, y1 = bounds
    sprite = cutout.crop(cutout.getchannel("A").getbbox()).resize(
        (x1 - x0, y1 - y0), Image.Resampling.LANCZOS)
    final = Image.new("RGBA", before.size)
    final.paste(sprite, (x0, y0))
    assert final.size == before.size == (512, 512)
    assert final.getchannel("A").getbbox() == bounds
    assert final.getchannel("A").getextrema() == (0, 255)
    assert final.crop((0, 0, 512, 62)).getchannel("A").getbbox() is None
    target = ROOT / "assets/base/pupation" / f"{name}.png"
    helpers.save(final, target)
    reports.append({
        "path": str(target.relative_to(ROOT)), "size": final.size,
        "previous_bounds": old_bounds, "bounds": bounds,
        "stem_area_transparent": True, "alpha_range": [0, 255],
        "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
    })
(HERE / "validation.json").write_text(json.dumps(reports, indent=2) + "\n")
print(json.dumps(reports))
