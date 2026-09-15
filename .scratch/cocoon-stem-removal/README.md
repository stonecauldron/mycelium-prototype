# Stemless cocoons

Removed the top stems from both `assets/base/pupation/cocoon.png` and
`assets/base/pupation/cocoon_open.png`, replacing them with rounded crowns.
The closed and open states retain the same 512 × 512 canvases, body widths,
and bottom alignment. Their new shared bounds are `(99, 62, 427, 504)`; the
former stem area is transparent. No runtime scene or script changed.

The built-in `image_gen` tool produced both edits. Exact prompts and source
locations are in `prompts.json`; generated sources and before images are saved
alongside it. `prepare.py` reuses the preceding cocoon art pass's authorized
background-cleanup helpers, then aligns the stemless bodies without stretching
them upward into the removed stem area. It requires Pillow and NumPy.

Godot 4.7 import and preview rendering passed. `preview.png` was visually
checked enlarged and at the actual 128 × 128 cocoon-slot image size. Dimensions,
matching bounds, transparency, and empty stem regions are verified in
`validation.json`. The preview exited zero; the previously observed OpenGL
texture-cleanup warnings still occur at shutdown.
