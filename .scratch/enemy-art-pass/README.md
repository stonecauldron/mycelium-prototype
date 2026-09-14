# Enemy art pass

Ten enemy redraws generated with the built-in `image_gen` tool and integrated
into the game. Bold dark contours and earthy colors now have clearer petal,
leaf, bark, spike, and acorn armor shapes. Stump, Durian, Log, and Acorn Knight
each have a four-frame walking sheet; frame zero also supplies the matching idle.

## Final artwork

The existing PNG paths are replaced, so both combat and scout portraits use
the new artwork without scene or resource changes:

- `assets/units/enemies/solar_sword/solar_sword.png`
- `assets/units/enemies/rose_thorn/rose_thorn.png`
- `assets/units/enemies/peashooter/peashooter.png`
- `assets/units/enemies/stump/stump.png` and `stump_walk.png`
- `assets/units/enemies/solar_cleaver/solar_cleaver.png`
- `assets/units/enemies/durian/durian.png` and `durian_walk.png`
- `assets/units/enemies/log/log.png` and `log_walk.png`
- `assets/units/enemies/canopy/canopy.png`
- `assets/units/enemies/seed_lobber/seed_lobber.png`
- `assets/units/enemies/acorn_knight/acorn_knight.png` and `acorn_knight_walk.png`

All fourteen final PNGs have real transparency. The user explicitly approved
programmatic background removal. Cleanup removed exterior checkerboards,
enclosed background gaps, disconnected speckles, and gray contour fringes.
Source artwork is retained in `source/`.

`prompts.json` contains the complete prompts; `generation.json` records the
built-in image-tool source paths; `source-inspection.json` records alpha checks.

Canopy and Solar Sword use a subsequent matte shading revision. Canopy's bright
leaf rims, eye glints, and golden trunk streaks were removed; Solar Sword's
petal shine, face reflection, and leaf highlight were removed. Broad subdued
shadows preserve the shapes. These two edits used the built-in `image_gen`
tool; exact prompts and generated source paths are in `matte-prompts.json`.
The selected sources are `source/canopy_matte.png` and
`source/solar_sword_matte.png`. `matte-validation.json` verifies their original
sizes, bounds, and alpha and confirms that the other enemy PNGs did not change.
To regenerate just these two, append `--only canopy solar_sword` to `prepare.py`.

## Registration and verification

`prepare.py --remove-background` registers redraws to the original idle bounds
and walk atlas regions, using the baseline commit recorded in `generation.json`.
It writes PNGs atomically so a running Godot editor cannot import partial files.
The runtime diff is fourteen PNGs. Scene nodes, weapon mounts, animation timing,
collisions, and enemy balance retain their authored values.

`preview.png` shows original and updated art at combat scale, plus mirrored
equipped scout portraits. `walk-preview.png` shows all four walk cycles. Both
were rendered by Godot 4.7 and visually inspected for alpha edges, anatomy,
frame consistency, and weapon alignment.

Validation in `validation.json` confirms:

- Fourteen valid RGBA PNGs with transparent and opaque pixels.
- Original canvas sizes, ten idle bounds, and sixteen walk-frame bounds.
- Successful Godot resource import.
- The existing enemy-walk checks: **272 passed, zero failures**.

OpenGL emitted the same three texture-leak warnings at shutdown on the
original-art baseline and updated-art previews. Rendering and checks completed
successfully with exit code zero.

To rerender locally after running `prepare.py`:

```sh
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --windowed --resolution 1920x1080 res://.scratch/enemy-art-pass/preview.tscn
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --windowed --resolution 1920x1080 res://.scratch/enemy-art-pass/walk_preview.tscn -- --screenshot
```

Original comparison textures are recreated by `prepare.py` in
`/tmp/mycelium-enemy-art-before/`. The preview scenes live alongside this file.
