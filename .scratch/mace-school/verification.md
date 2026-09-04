# Mace-school delivery verification

Verified locally on 2026-09-04 with Godot 4.7.stable (macOS, Apple M3). Godot ran outside the agent sandbox per repository guidance. No commit or push was made.

## Results

- Editor import completed without script/resource errors.
- [Regression scene](check_mace_school.gd): **252 checks, 0 failures**.
  - Five stable school IDs, requested display order, all five base weapons and all fifteen distinct unordered combos (including reversed input).
  - Sword-equivalent Mace Child gains; unchanged Adult stats; oldest-school replacement; cost, normal/instant duration, cancellation/refund, and minimum-fighter rule.
  - Breakers: common generation-II Great Hammer Adult with two full Mace gains, plus untrained common generation-I Child.
  - Adult and Child attachments: independent draw order, main-weapon-only swing/hide, body following, mirroring, cleanup when replacing/unequipping.
  - Runtime paired normal outgoing damage, non-blunt mitigation, blunt bypass, knockback reduction, and charge stopping.
  - Actual projectile creation, inherited damage/type, impacts against shield protection, Spear release/recovery, and protection while the Spear is absent.
  - Sling and Crossbow launch velocity agreement; Crossbow non-blunt damage.
  - Five school Cocoons; bin after the purchase control at starting capacity and after the tenth fighting slot at maximum; slot counts and viewport bounds at each intermediate capacity.
  - Squad/Bench drag eligibility, invalid sources/outsiders, confirmation and cancellation, Child payout/no spore, Adult payout with Bank, Mould credit, last-fighter protection, full-Stock FIFO overflow, and Mace-school lineage inheritance.
- [Combat smoke scene](check_combat.gd): **12 scenarios, 0 failures**. Each of the six new weapons fought a durable Solar Sword target for 18 game seconds at both 1× and 4×. Each landed damage; projectile weapons launched; Spear and Shield retained its shield during throws. Engine timing restored after each scene.
- Existing Adult-training portrait-containment scene passed: **0 clipped samples**. Its loops now cover all 15 combos through WeaponSchool.COUNT (its legacy printed summary still says “10 combos”).
- `git diff --check` passed.
- All eight final Imagegen PNGs have genuine alpha. See [artwork provenance and full prompts](artwork.md).

## Visual QA

- [Adult/Child, mirrored, and spear-release weapon gallery](weapon-gallery.png).
- [War Chamber at starting capacity](war-chamber-start.png).
- [War Chamber at maximum capacity](war-chamber-max.png).
- [Five-card starter chooser](starter-packages.png).

Visual inspection led to grounding the bin at the troop baseline and using an existing paper label backing for contrast. The separate shield stays on the other hand, in front of the body and behind the main weapon, and is included in fitted portraits. Generated weapon and bin images are scaled in Godot, not raster-edited.

The maximum-capacity checks exposed a pre-existing refresh edge case: nine positions plus a purchase control had the same visible count as ten positions. The squad refresh now compares slot roles so unlocking the final position correctly removes the purchase control.

## Reproduce

Run from the repository root. On this macOS setup, use an unsandboxed process for Godot.

```sh
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 1000 res://.scratch/mace-school/check_mace_school.tscn
godot --headless --path . --fixed-fps 60 --quit-after 20000 res://.scratch/mace-school/check_combat.tscn
godot --headless --path . res://.scratch/adult-weapon-training/check_portrait_fit.tscn
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 res://.scratch/mace-school/render_weapons.tscn
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 res://.scratch/mace-school/check_mace_school.tscn -- --screenshots
```

These checks establish implementation behavior, not balance. Combat smoke damage totals are not DPS measurements, and matching totals between frame rates is not asserted. No changes were made to existing combat cadence, movement, or projectile physics.

## Artwork revision — 2026-09-04

At the user's request, horizontally flipped the held Warhammer using `Sprite2D.flip_h` and replaced the Sling PNG with a transparent Y-shaped slingshot. The icon and held appearance share the replacement image; weapon names, stats, projectiles, and timing are unchanged. Re-imported successfully, reran all 252 regression checks (0 failures), and reran portrait containment (0 clipped samples). Re-rendered and inspected the weapon gallery on Adult and Child units. The final prompt and generated source are recorded in [artwork provenance](artwork.md).
