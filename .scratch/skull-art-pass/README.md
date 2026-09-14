# Elite skull art pass

Updated `assets/base/combat_progress_track/skull.png` with a clearer rounded
skull, large eye sockets, three broad teeth, fuller crossbones, matte ivory
shading, and a stronger consistent dark outline. The final outline refinement
brings the skull closer to the progression track's circle line weight.

The original 128 × 128 canvas and alpha bounds `(0, 3, 128, 120)` are preserved.
Only the runtime PNG changed; progression logic, hover signals, and UI layout
remain untouched.

The built-in `image_gen` tool produced the redraw and outline refinement.
`prompts.json` records both prompts and output locations; the selected source
is `source/skull.png`, and the first draft is `source/skull_initial.png`.
`before/skull.png` retains the original icon.

`prepare.py` uses the programmatic background cleanup already authorized in
this conversation, retaining the opaque skull cavities and clear spaces
between bones. It requires Pillow and NumPy and writes the final PNG atomically.
`validation.json` confirms the size, bounds, and alpha checks.

Godot 4.7 import and final rendering succeeded. `preview.png` was visually
checked enlarged on light and dark backgrounds, on the actual day-5 track at
56 pixels, and on the day-10 track at hover scale. Elite hover signals were
verified. The final render exited zero and reported success. The same OpenGL
shutdown texture-cleanup warnings as earlier art passes remain.

```sh
python3 .scratch/skull-art-pass/prepare.py
godot --headless --editor --path . --import
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --windowed --resolution 1920x1080 res://.scratch/skull-art-pass/preview.tscn
```

On macOS, run Godot outside the agent sandbox as directed in AGENTS.md.
