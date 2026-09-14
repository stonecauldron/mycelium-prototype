# Arrow readability pass

The shared arrow at `assets/weapons/bow/arrow.png` is now 64 × 24 pixels,
reduced from 512 × 512. The redraw removes fletching veins, bindings, facets,
and shaft highlights, using broad teal fins, a tan shaft, an ivory triangular
head, and a heavier dark outline. Its shaft outline reads around 1.6–2 screen
pixels thick at game scale, compared with roughly 0.5 pixels before.

The bow, crossbow, and great-bow projectile scenes now use visual scale 0.8
and offset `(0.25, 0)`. The original arrow's world-space left/right limits
remain exactly `-24.6` and `24.2` pixels from the projectile origin, preserving
its 48.8-pixel length and center. Its broader head and fins occupy 12.8 pixels
vertically. Collisions, trajectories, launch origins, damage, and all other
gameplay settings are unchanged.

## Source and preparation

The built-in `image_gen` tool generated the simplified artwork and its outline
refinement. `prompts.json` records both prompts and source output locations;
the selected source is retained in `source/arrow.png`. Background removal uses
the permission already granted in this conversation. `prepare.py` cleans the
checkerboard, removes detached flecks, and resamples to the small transparent
PNG. It requires Pillow and NumPy and writes the texture atomically.

The preceding arrow and three projectile scenes are retained in `before/`.
This pass supersedes the arrow portion of `../cocoon-projectile-art-pass/`.
If rebuilding that historical pass, run this pass's `prepare.py` afterward to
restore the 64 × 24 texture required by the current projectile scene scales.

## Verification

- PNG dimensions, alpha range, visible bounds, and world-space length checked.
- All three scene diffs checked against the saved baseline: only visual scale
  and offset changed.
- Godot 4.7 import and render completed successfully. The actual three
  projectile scenes were checked against the same forest patches, alongside
  their equipped player units and enemy sprites, at three flight angles.
- `preview.png` was visually inspected at native game scale; it also includes
  a 4× enlarged comparison. The render exited zero and printed
  `ARROW READABILITY PREVIEW: OK · three projectile scenes checked`.
- The same OpenGL shutdown texture-cleanup warnings as the previous art passes
  remain; there were no script parse or resource-load failures.

```sh
python3 .scratch/arrow-readability/prepare.py
godot --headless --editor --path . --import
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --windowed --resolution 1920x1080 res://.scratch/arrow-readability/preview.tscn
```

Run Godot outside the agent sandbox on macOS, as described in AGENTS.md.
