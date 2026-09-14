# Mushroom art pass — final selection

The user kept the new flag/banner and pole, and reverted the mushroom units and
the flag bearer himself. The only remaining runtime change from this pass is the
banner region inside `assets/combat/flag_bearer/flag.png`.

The six child/adult cap, body and walk PNGs and the flag-bearer walk PNG were
restored byte-for-byte from the recorded baseline. The flag bearer's idle pixels
were restored inside the shared flag texture. The new banner pixels are unchanged.
See `selection-validation.json` for verification.

`prepare.py` now rebuilds only the selected banner with the original flag bearer.
It leaves all player art and walk sheets untouched. Scene files, mounts, collision
shapes, animation timing, mutation colors and banner sway remain unchanged.

`prompts.json`, `generation.json`, `source/`, `baseline.json`, `validation.json`
and the `proposed-*.png` images retain the original proposal and its validation
history. The selected result is shown in `comparison.png` and `flag-preview.png`.

To regenerate, run `prepare.py` using a Python environment with Pillow and NumPy,
then import and render with Godot:

```sh
godot --headless --editor --path . --import
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1440x810 res://.scratch/mushroom-art-pass/comparison.tscn
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1440x810 res://.scratch/mushroom-art-pass/flag_preview.tscn -- --screenshot
```

On this macOS host, run Godot outside the agent sandbox as described in AGENTS.md.
The same known OpenGL texture-leak messages occur at shutdown with both original
and updated art; successful checks and screenshot rendering exit zero.
