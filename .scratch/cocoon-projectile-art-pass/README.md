# Cocoon and projectile art pass

Five generated redraws are installed at their existing game asset paths:

- `assets/base/pupation/cocoon.png` — layered, matte silk wraps.
- `assets/base/pupation/cocoon_open.png` — matching pod with a folded opening rim.
- `assets/weapons/bow/arrow.png` — wooden shaft, teal leaf fletching, ivory arrowhead.
- `assets/weapons/mortar/spore_bomb_projectile.png` — olive spore pores and husk seams.
- `assets/weapons/giant_horn/horn_projectile.png` — connected, ink-outlined terracotta notes.

The bow arrow is shared by bow, crossbow, and great bow. The floating UI arrow
was excluded as requested. No gameplay scenes, collisions, animation code, or
weapon resources were changed by this pass.

## Generation and cleanup

Artwork was created with the built-in `image_gen` tool. `prompts.json` contains
the full prompt set, including the two correction attempts; `generation.json`
records generated output locations. Selected full-resolution originals are
retained in `source/`; the pre-pass sprites are in `before/`.

The generator returned painted checkerboards on four selected sources and real
alpha with stray flecks on the arrow. The user explicitly approved local
background removal. `prepare.py` removes those backgrounds while retaining the
opaque art inside the dark contour, keeps both separate horn-note components,
and removes the arrow's detached flecks. Clean sources are in `cutouts/`.

Each result is registered to the original PNG's canvas and alpha bounds. Writes
are atomic so an open Godot editor cannot import a partially written PNG.

## Verification

`validation.json` confirms all five final assets are RGBA with transparent and
opaque pixels, original dimensions and bounds, and the expected connected
silhouettes. The closed and open cocoons both retain a 512 × 512 canvas and
the same bounds `(99, 0, 427, 504)`.

Godot 4.7 imported the project successfully. `preview.png` was rendered by Godot
and visually checked at game scale and enlarged against light and dark
backgrounds. The bottom row instantiates the five actual projectile scenes at
their authored scales. The render exited successfully and logged
`COCOON PROJECTILE PREVIEW: OK`. The OpenGL shutdown log includes three texture
leaks and associated rendering-server cleanup messages; it contains no script
parse or scene-load errors. Similar texture-leak shutdown warnings are already
documented in the earlier art-pass previews.

Rebuild after the approved cleanup:

```sh
python3 .scratch/cocoon-projectile-art-pass/prepare.py --remove-background
godot --headless --editor --path . --import
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --windowed --resolution 1920x1080 res://.scratch/cocoon-projectile-art-pass/preview.tscn
```

The script needs Pillow and NumPy. On this macOS machine, run Godot outside the
agent sandbox as directed by the repository's AGENTS.md.
