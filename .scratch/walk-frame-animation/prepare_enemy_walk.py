"""Bake alpha into the two magenta sheets, as authorized by the user."""
from pathlib import Path
import shutil

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
GENERATED = Path('/Users/cauldron/.codex/generated_images/01a07087-aa78-73c0-930e-7ef9378ac530')
SOURCES = {
    'stump': ('exec-53989d61-65fc-4ea2-88fd-747759f7ee2f.png', False),
    'log': ('exec-b2f42a50-7f4a-42d0-8b77-cf627b537bd4.png', False),
    'durian': ('exec-fbd35285-3ef8-4766-ba4d-aec51f7e7c08.png', True),
    'acorn_knight': ('exec-317b2441-9491-419d-912e-c1d031c1c5e0.png', True),
}

for enemy, (filename, extract) in SOURCES.items():
    target = ROOT / f'assets/units/enemies/{enemy}/{enemy}_walk.png'
    if extract:
        rgb = np.asarray(Image.open(GENERATED / filename).convert('RGB'), dtype=np.float32) / 255.0
        key = np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - rgb[:, :, 1]
        matte = np.clip((key - 0.1) / 0.55, 0.0, 1.0)
        alpha = 1.0 - matte * matte * (3.0 - 2.0 * matte)
        # Suppress magenta spill in the antialiased black outline only.
        spill = key > 0.0
        for channel in (0, 2):
            rgb[:, :, channel] = np.where(spill, np.minimum(rgb[:, :, channel], rgb[:, :, 1] + 0.02), rgb[:, :, channel])
        rgb[alpha == 0.0] = 0.0
        rgba = np.dstack((rgb, alpha))
        Image.fromarray(np.round(rgba * 255.0).astype(np.uint8)).save(target)
    else:
        shutil.copyfile(GENERATED / filename, target)
    image = Image.open(target)
    assert image.mode == 'RGBA'
    print(enemy, image.size, 'alpha', image.getchannel('A').getextrema())
    for row in range(2):
        for col in range(2):
            origin = (col * 627, row * 627)
            cell = image.crop((*origin, origin[0] + 627, origin[1] + 627))
            mask = cell.getchannel('A').point(lambda p: 255 if p > 10 else 0)
            print(row * 2 + col, mask.getbbox(), 'upper', mask.crop((0, 0, 627, 440)).getbbox())
