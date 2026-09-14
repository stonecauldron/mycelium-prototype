# Padlock art pass

The updated icon is installed at `assets/base/shop/padlock_locked.png`.
It uses the same bold dark contours and subdued matte shading as the cocoon
pass, with a warm ivory-gray shackle, olive-gray body, and clear black keyhole.

Created with the built-in `image_gen` tool. The exact prompt and generated
source location are recorded in `prompts.json`. The selected source is in
`source/`; the original icon is retained in `before/`.

The user previously authorized programmatic background cleanup in this task.
`prepare.py` removes the generated checkerboard from the exterior and the
enclosed shackle aperture, keeps the keyhole opaque, and removes detached
flecks. It writes the final PNG atomically at the original canvas size and
alpha bounds. It requires Pillow and NumPy.

`validation.json` confirms the original 512 × 512 canvas, bounds
`(125, 67, 387, 420)`, full alpha range, transparent arch aperture, and opaque
keyhole. No runtime scenes or scripts were edited.

Godot 4.7 import and screenshot rendering completed successfully. `preview.png`
was visually checked on light and dark backgrounds. The preview also verifies
the actual TextureRects from the shop, squad-slot, and nursery-plot scenes,
rendering them at their authored 56 / 96 / 96 pixel sizes. The render printed
`PADLOCK PREVIEW: OK · three UI consumers verified` and exited zero. The same
OpenGL shutdown texture-cleanup warnings as the preceding art pass remain.

To rebuild and preview, run from the repository root:

```sh
python3 .scratch/padlock-art-pass/prepare.py
godot --headless --editor --path . --import
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --windowed --resolution 1920x1080 res://.scratch/padlock-art-pass/preview.tscn
```

Run Godot outside the agent sandbox on this macOS host, per AGENTS.md.
