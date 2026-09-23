# Adult weapon Training

Implemented and reviewed following authorization through the implement skill.

## Settled decisions

- Players did not discover descendants or understand that descendants enabled Combo weapons. Adult Training should make combo progression accessible within one unit's life.
- Adults may enter Cocoons for weapon-school Training with STR, DEX, and CON unchanged: neither school bonuses nor penalties apply. The resulting Weapon can still change combat performance.
- Adult Training uses the same school-history mechanism as descendant Training: retain at most two schools, replacing the oldest on further Training. Same-school pairs remain valid.
- Lineage spores inherit the parent's current Trainings, including schools learned as an Adult.
- Adult Training costs 3 biomass and completes instantly on confirmation, including Adults raised with Cocooning. The Adult stays in its original Squad or Bench slot. Child Training keeps its existing Fertilizer behavior.
- Existing Cocoon capacity remains. Cancellation/refund and minimum-one-fighter rules apply to Training with a wait; the last Adult can train instantly.
- Cocoons continue suspending aging, Stimulants decay, and daily Mutation effects for Children. Adults remain in the troop and cannot use Training as shelter.
- Show “Stats unchanged” in the Adult confirmation. Omit the training hint below the Cocoons.
- School tooltips use a Child tag followed by school Stat changes and the default duration hourglass, retaining the existing Stat icons and signed gain/loss colors. A second row uses an Adult tag followed by “no stats gains” and “instant”.
- School tooltips show the school icon, title, and the biomass price in the bottom-right corner using the Shop price style. Omit Combo weapon recipes: visual review found them too cluttered.
- Adult confirmations show only the final result in a centered card, with duration, “Stats unchanged”, and the confirmation price. Children retain the before/after comparison. Add no school-replacement information.
- The confirmation title says “Train [unit name]” for Adults and “Pupate [unit name]” for Children.

## Visual review

- Training tooltip follow-up: rendered all five school cards in Godot at 1920 × 1080. Each fits at 400 × 424 with Child/Adult tags, signed school Stats followed by the one-Day hourglass, “no stats gains · instant”, and the 3-biomass price at bottom right. No clipped content in the rendered cards.
- Text recipes and then icon recipes were tried in the tooltips; the user chose to remove the recipe section after reviewing the clutter. The single Children row retains Stat icons and signed gain/loss colors.
- Adult final-result and Child comparison layouts were inspected at 1920 × 1080, including reusing the dialog Adult → Child → Adult. The Adult panel centers the result and retains duration, unchanged-Stats text, and price; the Child comparison is restored correctly. The tooltip without recipes and removal of the Cocoon hint were also visually checked.

## Behavior before this change

- Training costs 3 biomass and normally takes 1 Day. Each school has one Cocoon; at least one fighter must remain outside. Cancellation refunds the price.
- Training currently rejects Adults. School Stat changes include positive and negative deltas; completion and preview both apply them.
- Cocooning permanently gives a unit a 2-Day Cocoon duration and doubles school Stat changes.
- The confirmation dialog already previews the resulting Weapon; empty-school tooltips emphasize Stat changes.
- Cocoons remove units from the Troop, suspending aging, Stimulants decay, and daily Mutation effects.
- Repeating a school can preserve the immediate Combo weapon while changing school order; repeating Sword on Sword + Sword changes neither.

## Validation

- Instant Training follow-up: a temporary Godot 4.7 runtime scene passed 22 checks, including the actual confirmation-button signal, preview/cancel without mutation, immediate combo updates, unchanged Adult Stats, exact biomass charge, preserved Squad/Bench positions, last-Adult eligibility, repeat Training, insufficient funds, and occupied Cocoons. Normal Child emergence, Cocooning's two-Day wait, cancellation/refund, and the last-Child restriction also passed. The temporary scene was removed after verification.

The original one-Day Adult Training checks below describe the earlier implementation; instant Adult Training supersedes its wait, cancellation, and shelter behavior.

- Godot 4.7 editor import completed without errors. No configured test suite or pre-agreed TDD seams exist; validation used a temporary runtime preview scene, removed after inspection.
- An Adult with STR 10 / DEX 8 / CON 12, doubled school Stats, and a 2-Day Cocoon override trained into Mace in 1 Day with all Stats unchanged, then retrained into Umbrella Shield with all Stats still unchanged.
- Training charged 3 biomass; cancellation refunded all 3. The last remaining fighter could not enter a Cocoon. The Adult did not age or suffer its daily Stat decay while cocooned.
- A Lineage spore inherited the Adult's updated Shield + Bow Trainings.
- A Child with STR/DEX/CON 5, Cocooning, and a pending +1 Adult bonus retained its 2-Day wait and emerged from Sword Training with STR 12 / DEX 4 / CON 10, matching its preview.
- Standards review: 0 actionable findings. Spec review: 0 actionable findings.
- Large-weapon clipping was reproduced with Umbrella Shield: the full artwork extended above the 140-pixel portrait host on all 60 sampled frames. The confirmation hosts were not opting into the existing weapon-aware portrait-fit helper; enabling it for both portraits fixes the clipping without changing other portrait views.
- Regression scene `check_portrait_fit.tscn` exercises the actual confirmation with all 10 combo weapons in Adult and Child layouts, sampling 60 points across the idle animation for each visible portrait. It passes with zero clipped samples. Run from the project root with `godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --windowed .scratch/adult-weapon-training/check_portrait_fit.tscn` (outside the agent sandbox on macOS).
