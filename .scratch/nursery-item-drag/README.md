# Nursery item drag verification

Run from the project root, outside the agent sandbox on macOS:

```sh
godot --headless --editor --path . --import --quit
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --max-fps 60 res://.scratch/nursery-item-drag/verify.tscn -- --visual
```

The scene boots a seeded live Base and uses native mouse press, motion, and release events. Setup replaces fixture offers and clears plots between cases; every checked purchase, application, sale, or cancellation follows the real UI drop path.

Coverage includes both Fertilizers and Mutations:

- Repeated Shop-boundary crossings preserve the original payload and balance, switch between offer and inventory forms, and create smoke.
- A Stock purchase and a direct Plot purchase each spend once and remove the offer.
- Pointer-outside/icon-overlap Plot and Sell drops agree with the highlighted target and biomass preview. Sell uses the visible paper badge; dropping elsewhere in the Shop preserves the item.
- Ordinary pointer-over-Plot and pointer-over-Sell drops still work. The natural compact icon covers the pointer, so these are ordinary pointer paths rather than a synthetic icon-displaced case.
- Shop items cannot sell. Invalid Stock drops restore the source without spending.
- An icon overlapping adjacent Plots applies to exactly one highlighted target.
- A same-event Shop-boundary crossing and release works without a layout frame in between.
- Pause and tab change cancel the native drag, free its preview/smoke, restore the source, and preserve balance. Whole-scene teardown is exercised at the end, but no separate mid-drag scene-replacement assertion is made.

Visual captures are saved to `/tmp/nursery-item-drag-*.png` when `--visual` is supplied. The latest focused runtime log is `/tmp/nursery-item-drag-runtime.log`. The entry scene exits nonzero on a failed assertion and has a 90-second watchdog.

Latest validation: **106 assertions, 0 failures**, exit code 0. Import and runtime had no script/parse errors. The log contains the existing renderer texture/RID shutdown warnings. The fast boundary-release case passes with both drag forms kept laid out and switched by opacity. Godot was stopped after verification.

Representative inspected captures:

- `/tmp/nursery-item-drag-fertilizer-inventory-puff.png`
- `/tmp/nursery-item-drag-mutation-inventory-puff.png`
- `/tmp/nursery-item-drag-fertilizer-plot-icon-only.png`
- `/tmp/nursery-item-drag-mutation-sell-icon-only.png`
