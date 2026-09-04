# Adult weapon Training

Implemented and reviewed following authorization through the implement skill.

## Settled decisions

- Players did not discover descendants or understand that descendants enabled Combo weapons. Adult Training should make combo progression accessible within one unit's life.
- Adults may enter Cocoons for weapon-school Training with STR, DEX, and CON unchanged: neither school bonuses nor penalties apply. The resulting Weapon can still change combat performance.
- Adult Training uses the same school-history mechanism as descendant Training: retain at most two schools, replacing the oldest on further Training. Same-school pairs remain valid.
- Lineage spores inherit the parent's current Trainings, including schools learned as an Adult.
- Adult Training costs 3 biomass and takes 1 Day, including Adults raised with Cocooning. Child Training keeps its existing Fertilizer behavior.
- Existing Cocoon capacity, cancellation/refund, and minimum-one-fighter rules remain.
- Cocoons continue suspending aging, Stimulants decay, and daily Mutation effects. Repeat Adult Training may reuse this shelter, including when the Weapon stays unchanged.
- Add the visible instruction “Train an Adult again to combine weapon schools.” by the Cocoons, and show “Stats unchanged” in the Adult confirmation.
- Collapse school tooltip Stat changes into one line labeled “Children”, e.g. “Children: +3 STR · −1 DEX · +2 CON” for Sword.
- Include the four Combo weapon recipes for each school in its tooltip. This is provisional: review the space they occupy after implementation.
- Keep the confirmation's existing before/after Weapon presentation. Players do not need an explanation of which school is lost; add no school-replacement information.

## Visual review

- All four school tooltips render at 360 × 383 with the Children Stat changes on one line and all four recipes visible. Local paper padding was reduced to keep the added recipes compact. The normal tooltip overlay and both Child/Adult confirmations were inspected at 1920 × 1080.
- The combo list remains open to user feedback on visual density.

## Behavior before this change

- Training costs 3 biomass and normally takes 1 Day. Each school has one Cocoon; at least one fighter must remain outside. Cancellation refunds the price.
- Training currently rejects Adults. School Stat changes include positive and negative deltas; completion and preview both apply them.
- Cocooning permanently gives a unit a 2-Day Cocoon duration and doubles school Stat changes.
- The confirmation dialog already previews the resulting Weapon; empty-school tooltips emphasize Stat changes.
- Cocoons remove units from the Troop, suspending aging, Stimulants decay, and daily Mutation effects.
- Repeating a school can preserve the immediate Combo weapon while changing school order; repeating Sword on Sword + Sword changes neither.

## Validation

- Godot 4.7 editor import completed without errors. No configured test suite or pre-agreed TDD seams exist; validation used a temporary runtime preview scene, removed after inspection.
- An Adult with STR 10 / DEX 8 / CON 12, doubled school Stats, and a 2-Day Cocoon override trained into Mace in 1 Day with all Stats unchanged, then retrained into Umbrella Shield with all Stats still unchanged.
- Training charged 3 biomass; cancellation refunded all 3. The last remaining fighter could not enter a Cocoon. The Adult did not age or suffer its daily Stat decay while cocooned.
- A Lineage spore inherited the Adult's updated Shield + Bow Trainings.
- A Child with STR/DEX/CON 5, Cocooning, and a pending +1 Adult bonus retained its 2-Day wait and emerged from Sword Training with STR 12 / DEX 4 / CON 10, matching its preview.
- Standards review: 0 actionable findings. Spec review: 0 actionable findings.
