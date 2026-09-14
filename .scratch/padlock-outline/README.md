# Padlock outline refinement

Updated `assets/base/shop/padlock_locked.png` with slightly heavier body and
shackle contours. The existing 512 × 512 canvas, alpha bounds, placement,
palette, shading, transparent shackle aperture, and opaque keyhole remain.
No runtime scene or script changed.

The built-in `image_gen` prompt and output location are recorded in
`prompts.json`. The source is in `source/`; the preceding icon is in `before/`.
`prepare.py` applies the previously authorized background cleanup and registers
the result to the existing bounds. It requires Pillow and NumPy.

`validation.json` confirms the dimensions, bounds, and transparency checks.
Godot 4.7 import and rendering passed, and `preview.png` was visually inspected
at the actual 56- and 96-pixel UI sizes. All three UI consumers were checked.
The same previously observed OpenGL texture-cleanup messages occur at shutdown;
the preview exited zero and reported success.
