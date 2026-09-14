# Weapon icons

24 independent, abstract UI icons live in `assets/weapons/icons/`. Each is a
64 × 64 RGBA PNG with transparent padding. The existing `WeaponData.icon`
references select them throughout the UI.

The built-in image_gen tool generated each icon separately, using
`assets/units/generalist/gen_imago_cap.png` as the line-weight and shape reference.
`generation.json` records the exact shared prompt, individual weapon prompts,
source outputs, and final paths. `revisions.json` records the subsequent edits
and selected replacement outputs for the spear, mace, great shield, great sword,
lance, crossbow, and umbrella. The selected outputs all have real alpha.

The initial art was exported to native 64 × 64 with macOS `sips`, preserving
alpha. Godot imports use lossless compression with mipmaps disabled.

For subsequent transparent assets, the user prefers generation on solid magenta
followed by programmatic removal. Do not request or generate checkerboard
patterns. `second-revisions.json` records the built-in image_gen prompts for the
lance, mace, crossbow, and great spear. `key_magenta.py` removes the magenta,
recovers antialiased edge coverage, removes color spill, and exports 64 × 64 RGBA
with Pillow. The full-resolution transparent outputs are in `second-revisions/`.

`preview.tscn` loads every actual weapon resource, checks that its icon is 64 × 64,
and renders it at 28, 36, 56, and 96 logical pixels alongside a character reference.
Run it with Godot from this project to refresh `preview.png`:

```sh
godot --path . --windowed --resolution 1920x1080 res://.scratch/weapon-icons/preview.tscn
```

On macOS, run outside the agent sandbox as required by the repository guidance.

Validation: all 24 resources loaded their new 64 × 64 icons, transparency checks
passed, and the preview was visually inspected at all four display sizes. The
icon integration changes only the icon references. During revision verification,
four empty Resource placeholders (great sword, great shield, great horn, and
spear and shield) were restored to their imported Texture2D references.

The first revisions give the spear a longer shaft, use angular flanges for the mace,
follow the great-shield and great-sword sprite silhouettes, give the lance two
speed lines, add a taut crossbow string, and add the umbrella's pointed ferrule.
Only those seven icon PNGs changed; the other 17 are byte-for-byte unchanged.
The crossbow's string gaps were also checked for transparency. The revision
import completed without errors; the earlier held great-shield import error
is no longer present.

The second revisions add two lower lance motion lines (four in total), restore
heavier outlines on the mace and crossbow, and lengthen the great spear shaft.
Only those four PNGs changed in this pass. Their transparent margins and absence
of magenta spill were checked, and the mace and crossbow have substantially more
solid outline pixels. All 24 weapon resources loaded successfully in Godot, and
the refreshed preview was visually checked at each UI size.

The previews saved successfully and exited with status 0. Godot also reported
texture cleanup errors after capture.

The third revisions give the mortar the weapon sprite's upright flared body,
left handle, and ivory base band, and mirror the lower lance dashes in position
and angle across the lance axis. `third-revisions.json` records the prompts and
selected outputs. Only mortar and lance changed in this pass. Both 64 × 64 RGBA
exports passed transparent-margin and magenta-spill checks; the lance keeps four
separate motion strokes. The complete set loaded and rendered successfully in
the refreshed Godot preview.

The fourth revision replaces the mace icon's fan-shaped head with the weapon
sprite's compact polygonal head, central diamond ridge, and two broad side
flanges. `fourth-revisions.json` records the built-in image_gen edit. Only the
mace icon PNG changed. The transparent 64 × 64 export passed margin and magenta
spill checks, and its appearance was checked in the refreshed Godot preview.

The fifth revision updates all three weapon-and-shield combos from the current
standalone sword, long-shaft spear, and revised mace icons. Each complete weapon
is superposed in front of the shield, across its face. `fifth-revisions.json`
records the built-in image_gen compositing prompts. Only those three combo PNGs
changed; their transparent 64 × 64 exports passed margin and magenta-spill checks,
and the refreshed Godot preview confirmed all 24 resource references and the
foreground weapon placement at 28, 36, 56, and 96 display pixels.

The sixth revision straightens the mace head along the grip in both the
standalone and shield-combo icons. `sixth-revisions.json` records the edits.
Measured central-ridge/grip axis differences fell from 7.51° to 0.58° for the
standalone mace and from 9.24° to 1.32° for the combo. Only those two icon PNGs
changed. Both passed 64 × 64 RGBA, transparent-margin and magenta-spill checks,
and the full icon set loaded successfully in the refreshed Godot preview.

The outline revision slightly thickens existing dark outlines and detail strokes
across all 24 icons, retaining the current silhouettes, long shafts, mace ridges,
strings, motion lines, tips, and foreground weapon placement in shield combos.
`outline-revision.json` records all built-in image_gen edit prompts and outputs;
`outline-revision/` contains the full-resolution transparent sources. Magenta was
removed with `key_magenta.py`, including faint resampling noise at the outermost
canvas margins. `outline-validation.json` records the 64 × 64 RGBA, margin, color
spill, and increased dark-pixel coverage checks. All 24 icons loaded and rendered
successfully in Godot, and `preview.png` was inspected at 28, 36, 56, and 96 pixels.
