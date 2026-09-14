# Mushroom shading pass

Apply the supplied `imago_generalist.png` shading reference to the existing
mushroom artwork. Only RGB shading inside existing fills may change. Original
alpha, silhouettes, black linework, poses, canvas sizes, frame coordinates, and
the flag banner/pole are locked.

`before/` contains the exact working-tree sprites at the start of this pass.
`reference.png` is the user-provided shading reference. The adult idle cap/body
already match that reference geometrically, so its shadow pixels can be used
directly. Other shadow placements are sourced from built-in ImageGen edits.
Generated sprites are intermediate shading sources, not replacement silhouettes.

Player child/adult caps, idle bodies, and all walking frames, flag-bearer idle
and walking frames, and the spring mushroom sprite are included. The separate
child-eye texture is unchanged. Gameplay scenes and code are unchanged.

## Saved runtime textures

- `assets/units/generalist/gen_child_cap.png`
- `assets/units/generalist/gen_child_body.png`
- `assets/units/generalist/gen_child_walk.png`
- `assets/units/generalist/gen_imago_cap.png`
- `assets/units/generalist/gen_imago_body.png`
- `assets/units/generalist/gen_imago_walk.png`
- `assets/combat/flag_bearer/flag.png` (mushroom region only)
- `assets/combat/flag_bearer/flag_bearer_walk.png`
- `assets/units/spring/spring_unit.png`

The built-in ImageGen tool was used; the exact prompt set is in `prompts.json`
and generated source paths are in `generation.json`. `apply-shading.cjs` uses
the generated fill shadows as lighting masks and keeps the source pixels and
their original alpha. It rejects changes to solid ink, transparent pixels, or
pixels outside the original atlas regions. The source colors are only darkened.

## Verification

`validation.json` records dimensions, changed pixels, source/result hashes, and
zero changed alpha, solid-ink, transparent, or out-of-region pixels for all nine
assets. The flag banner/pole and the spring cap emblem are protected.

Godot imported the textures and rendered `comparison.png` using the actual
player composition and flag-bearer scenes, including all four walk frames.
Both commands exited zero; the renderer printed `SHADING PREVIEW: OK`.
`preview.log` also contains the already-known OpenGL texture cleanup messages
at shutdown, documented in the previous mushroom art pass.

## Flag-bearer animation correction

The first shading transfer used separately drawn shadows for each frame and
registered them to whole-character bounds. This shifted the cap shadow by up
to 2.226% of cap width between walking frames, with additional idle/walk drift.

All flag-bearer poses now reuse the shadow fields from the first frame of the
existing built-in ImageGen `generated/flag_walk.png`. Cap bounds anchor both
cap and body shadows, so changing leg poses cannot move the shading. Only the
two flag-bearer PNGs were updated in this correction. No additional generation
or sprite redesign was needed, and the original artwork/alpha remain locked.

`check-flag-shading.cjs` measures cap shadow boundaries and compares shading
strength across cap/body samples in idle plus all four walk frames. It fails
on `flag-consistency-before/` and passes on the installed textures. Measured
walking cap-boundary drift is now 0.074% (less than one source pixel).
`flag-consistency-baseline.json` and `flag-consistency-validation.json` hold
the measurements. `flag-cycle.gd` renders the real Godot animation, and
`flag-shading-cycle.gif` shows the original and corrected walk cycles together.
