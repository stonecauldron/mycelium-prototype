# Shared Base usability improvements

Implemented the approved ordinary-Run subset of the onboarding exploration:

- Receiving-Day Seal icons and timing tooltips on Days 1, 3, 6, and 9.
- Hide / Select Seal / Start Battle flow, preserving offers, selection, paid rerolls, and Base edits while combat remains gated by the pending choice.
- Training confirmation shows recipes, roles, actual availability, and explicit oldest-Training replacement using the existing preview rules. School hover tooltips retain their original compact presentation.
- Unit details show two Training slots and the resulting Weapon icon in one equation, with visible empty slots.
- Formation title and flag placement. The Rear / Front / Enemies orientation rail was removed following UI review.
- Quiet Nursery-tab count badge for harvest-ready Plots, updated by growth, Fertilizers, Greenhouse, harvesting, and grow removal. The badge hides at zero; harvest details remain in the tooltip.
- Compost preview of parent removal, payout, lineage Child, Generation, Tier, Trainings, Mutations, and saved Stats.

Costs, eligibility, waits, inheritance, combat behavior, and the 10-Day Run remain unchanged. Guided mode, a clickable Train entry point, and Training-return indicators are outside this work.

## Verification

Godot 4.7 editor import/script scan and the focused runtime scenario suite passed. The repository has no configured unit-test framework or full test-suite command. These checks follow the existing `.scratch/` scene-check pattern.

On macOS, run Godot outside the agent sandbox as required by `AGENTS.md`:

```sh
godot --headless --editor --path . --quit
godot --headless --path . res://.scratch/shared-usability/verify.tscn --quit-after 2400
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --windowed --resolution 1280x720 res://.scratch/shared-usability/verify.tscn --quit-after 2400 -- --visual
```

`verify.gd` exercises real Base controls with viewport input, hide/reopen/Escape, both tabs, empty-Squad gating, reroll preservation, immediate Plot readiness, the ordinary reward calendar, icon hover/focus, chapter transitions, and the existing opening flow. `preview_checks.gd` compares Training previews with actual application for Child waits 0/1/2, Adult instant Training, repeat-school recipes, replacement/renewal, and modified/clamped Stats. It also checks Child/Adult Compost and real lineage-spore harvest inheritance.

The visual pass writes `/tmp/usability-*.png` for the Seal chooser, Formation with 4 and 10 slots, Nursery readiness, progression tooltip, Child/Adult Training, school hover, Unit details with zero/one/two Trainings, and Adult Compost. These were inspected for readability and fit at play size. Renderer/resource cleanup diagnostics can appear on engine exit; the scenario checks separately report their failure count.

## Review

Standards and Spec reviews were run independently against starting commit `fbcd5cc96c32e6fba390d42b9f42a3d3bc1ba936`. A missing hover target on the Seal artwork was fixed and covered by the runtime check; duplicate Training role text was consolidated. Final reviews reported no outstanding findings. A focus/hover replacement exposed a stale tooltip lease during chapter rebuild; the lease now tracks the tooltip instance ID so it remains valid after the old Control is freed.
