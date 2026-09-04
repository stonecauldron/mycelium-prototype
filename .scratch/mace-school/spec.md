# Mace school and Composting bin

Design confirmed by the user, including paired-shield placement. Implemented and verified; see [delivery verification](verification.md) and [artwork provenance](artwork.md).

## Settled direction

- Add Mace as the fifth weapon school, with Mace as its single-school Weapon and a blunt-weapon identity.
- Replace the Composting cocoon in the school row with a weapon-school Cocoon, leaving five school Cocoons.
- Move the existing Compost behavior into a dedicated Composting bin after the visible Squad slots and next-slot purchase control. At maximum Squad capacity it follows the tenth slot. The bin never occupies a fighting position.
- Use Combo weapon for a two-school Weapon; Tier continues to mean unit rarity.
- Show the school Cocoons in this order: Sword, Mace, Shield, Spear, Bow.
- Mace is a slower Sword with blunt damage. Its Child-training Stat profile should mirror Sword rather than use the earlier distinct Mace proposal; Sword's current profile is +3 STR, -1 DEX, +2 CON. Adult Training still leaves Stats unchanged.
- Keep the existing Mace combat profile unchanged. Existing Training costs, durations, Child overrides, cancellation/refund behavior, minimum-fighter rule, and school-history replacement remain unchanged.
- Polehammer and Spear and Shield must support throwing as well as melee.
- Crossbow must no longer deal blunt damage.
- Sling should have a projectile trajectory similar to Crossbow.
- Create missing artwork for this delivery.
- Add the Breakers Great Hammer starter package: one common generation-II Adult trained twice in Mace plus the usual hidden untrained generation-I Child. Apply the same two full school gains as other starters. Fit all five packages in one row using narrower cards.
- Keep existing Compost eligibility, confirmation, biomass rewards, Lineage spore outcomes, Mutation effects, and Stock-overflow behavior unchanged.

## Combo weapon names

- Sword + Sword: Great Sword.
- Shield + Shield: Great Shield.
- Spear + Spear: Halberd.
- Bow + Bow: Sniper.
- Mace + Mace: Great Hammer.
- Sword + Shield: Sword and Shield.
- Sword + Spear: Lance.
- Sword + Bow: Crossbow.
- Mace + Sword: Warhammer.
- Spear + Shield: Spear and Shield.
- Shield + Bow: Umbrella Shield.
- Mace + Shield: Mace and Shield.
- Spear + Bow: Spore Mortar.
- Mace + Spear: Polehammer.
- Mace + Bow: Sling.

Recipes are unordered, as in the existing system. Mace and Shield replaces the earlier Flail proposal.

## Agreed initial combat profiles

- Sword and Shield, Mace and Shield, and Spear and Shield keep their corresponding base weapon's normal damage, scaling, and Attack interval. They take 50% non-blunt damage and 50% knockback and block charges. There is no outgoing damage penalty.
- Paired weapons also keep the base weapon's engagement stance: Sword and Shield and Mace and Shield use formation fighting, not HOLD. Spear and Shield uses Spear's hybrid behavior.
- Spear and Shield retains the base Spear's throw/melee hybrid behavior. Its Shield remains visible and protective while the Spear is thrown.
- Warhammer: single-target blunt STR melee, 8 base damage, 1.75-second interval, 120 reach, 360 knockback.
- Polehammer: single-target blunt FINESSE throw/melee hybrid, 8 base damage, 2.5-second interval, 210 melee reach, 650 throw range, 210 hybrid switch distance, 120 knockback. FINESSE uses the higher of STR and DEX.
- Sling: blunt DEX projectile weapon, 5 base damage, 2-second interval, 1000 range, 200 retreat distance, 80 knockback. Match Crossbow's 12-degree launch angle, 1400 fallback speed, and 3-second lifetime, with stone projectile artwork.
- Crossbow keeps its other values and switches to the existing non-blunt damage type. Do not introduce a new damage-type system.
- Great Hammer retains its existing blunt AoE profile, moving to Mace + Mace. Other existing weapons remain unchanged apart from agreed recipe remapping.
- These are initial balance values, not a claim of playtested balance. Damage/interval is nominal DPS; animation/recovery, movement, hits, and targets affect observed output.

## Pre-implementation design context

- Adult Training is now supported and leaves Stats unchanged. Child Training retains school Stat gains and penalties; see [Adult weapon Training](../adult-weapon-training/spec.md).
- Existing two-school history and replacement rules remain the basis of weapon identity; see [ADR-0002](../../docs/adr/0002-adult-identity-from-weapon-schools.md).
- The earlier +4 STR, -2 DEX, +2 CON proposal is superseded by matching Sword's training profile.
- Existing Mace is STR-based, single-target blunt melee with 5 base damage, a 1.25-second Attack interval, 96 reach, and 280 knockback. Great Hammer already exists as STR-based blunt AoE with 7 base damage, a 2.5-second interval, 140 reach, and 450 knockback.
- Six new identities lack dedicated resources: Sword and Shield, Spear and Shield, Warhammer, Mace and Shield, Polehammer, and Sling. Paired appearances can compose existing sprites; genuinely missing artwork will be created.
- Current throwing hides the entire held-weapon mount. Spear and Shield therefore needs layered visibility so that throwing the Spear does not hide its Shield. Existing combat data can combine hybrid attacks, damage mitigation, and charge blocking.
- The current row is Compost, Sword, Shield, Spear, Bow. Five schools preserve its five-slot footprint. School presentation order is separate from integer identity: retain existing school IDs and append Mace while displaying Sword, Mace, Shield, Spear, Bow.
- The Squad row contains unlocked positions plus the next unlock purchase slot, up to ten fighting positions. A separate bin fits after the visible row even when all ten positions are open.
- Compost currently opens confirmation, accepts Squad/Bench units, and preserves at least one available fighter. Confirmed Compost is immediate: Child yields 2 biomass, Adult yields 3 and a Lineage spore; existing Bank/Mould effects also apply. Moving the control need not change these rules or the existing Stock-overflow policy.
- Four curated starter packages currently exist. Adding the fifth also requires fitting the picker: five existing 400-pixel cards do not fit the current 1920-wide layout.

## Implementation gate

The user confirmed the shared understanding and independent offhand Shield placement with "yes" on 2026-09-04. Gameplay and artwork implementation may proceed.

## Agreed paired-shield appearance

- Keep the attacking weapon and Shield as independent visuals, not one flattened sprite. The existing WeaponMount is both rotated during melee swings and hidden during throws, so it cannot directly own a Shield that must stay separately carried.
- Give the Shield a separate body-following attachment near the other hand, over the lower-left torso when facing right, with the attacking weapon retaining its forward/right-hand attachment. Draw the Shield over the body but keep the attacking weapon readable in front of it; leave the cap and feet readable.
- Use a smaller paired Shield (0.11 sprite scale, versus 0.15 standalone), with Adult offset (-20, -40) and Child offset (-18, -31) before body scaling. Mirror the whole arrangement when the unit faces the other direction.
- The Shield follows body movement, jumping, and whole-body throwing lean, but does not independently perform the weapon's melee swing or disappear when the Spear is thrown.
- This is visual separation only: the pair remains one Combo weapon and one combat profile. Do not introduce an independent Shield attack or a physical Shield collider.
- Include both pieces in portrait bounds and verify idle, melee, throw/recovery, facing changes, and small UI previews before finalizing the placement.

## Verification scope

- Validate all five single-school outputs and all fifteen unordered Combo weapon recipes, including reversed mixed-school input order.
- Verify Mace Child-training Stat changes match Sword, while Adult Mace Training preserves Stats and existing timing/cost behavior.
- Exercise paired-shield normal outgoing damage, non-blunt mitigation, blunt bypass, charge blocking, and hybrid throw behavior.
- Check all five school Cocoons and starter cards fit the intended viewport; inspect new weapon artwork and portraits for clipping. Confirm only the Spear hides when Spear and Shield throws.
- Check the bin remains after the purchase control as Squad slots unlock, fits at maximum capacity, never occupies a Squad slot, and preserves Compost confirmation/cancellation and outcomes.
- Validate the Breakers Adult's schools, common Tier, generation, and hidden Child against the other starter packages.
- Use existing Godot validation workflows; no unrelated combat-cadence overhaul, new weapon shop, or separate offhand combat system is included.

## Interview record

### Round 1 — 2026-09-04

- Mace should be a slower Sword with blunt damage and matching Sword-training bonuses.
- User wrote "Flail => mace + shield"; interpretation as the resulting weapon name is awaiting confirmation.
- Polehammer and Spear and Shield can throw.
- Crossbow loses blunt damage; Sling uses a similar trajectory to Crossbow.
- School display order is Sword, Mace, Shield, Spear, Bow.
- Create missing artwork and add the Great Hammer package.

### Round 2 — accepted with one change

- User changed paired-shield outgoing damage from the proposed 75% to the weapon's full normal damage, accepting the remaining protection/charge-blocking recommendation.
- User accepted the other recommendations: Mace and Shield naming; Warhammer, Polehammer, and Sling initial profiles; and Breakers starter with a compact five-card row.
