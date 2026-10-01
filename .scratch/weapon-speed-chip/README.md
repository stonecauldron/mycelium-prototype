# Weapon speed chip verification

Run from the project root, outside the agent sandbox on macOS:

```sh
godot --headless --editor --path . --import --quit
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --max-fps 60 res://.scratch/weapon-speed-chip/verify.tscn -- --visual
```

This focused fixture reuses the Cocoon drag fixture's pointer/setup helpers. It checks:

- Sickle and Bow details display `1.5s` and `1.15s` before Base Damage, with no text overlap.
- Child Sickle → Bow displays `−0.35s` in green; Adult Sword → Warhammer displays `+1s` in red.
- Reusing the comparison for Spear → Spear and Shield clears the speed delta and restores neutral color, size, and font.
- Amok plus Wooden Clock preserves the persistent rate in the preview: displayed `0.31s` → `0.73s`, delta `+0.42s`.
- Changed chips use 130% emphasis; baseline chips stay neutral.
- A real hovered Cocoon during an active viewport drag shows the third chip in the result-only preview. Inspection does not spend biomass or train the unit.

Latest result: **43 checks, 0 failures** on 2026-10-01. The saved script is the same script exercised by the temporary runner. Godot exited normally. No script errors occurred; known renderer shutdown texture/RID warnings remained.

Evidence:

- Log: `/tmp/attack-speed-ui-check.log`
- Weapon details: `/tmp/usability-cocoon-drag-speed-weapon-details.png`
- Faster result: `/tmp/usability-cocoon-drag-speed-faster-child.png`
- Slower result: `/tmp/usability-cocoon-drag-speed-slower-adult.png`
- Persistent modifiers: `/tmp/usability-cocoon-drag-speed-persistent-rate.png`
- Passive hover: `/tmp/usability-cocoon-drag-speed-result-only-hover.png`

The captures were inspected at play size. Decimal values remain readable, and the third chip does not clip neighboring content. Subsequent artwork revisions put the values lower to expose the hands, removed the side button, thickened the outline and flattened the face's color and opacity. The stopwatch source is now 128 × 128, with `process/size_limit=0` like the Sword and Heart icons. See [artwork notes](art.md) for the final prompt and cleanup steps.
