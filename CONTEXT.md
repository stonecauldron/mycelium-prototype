# Auto Shrooms

A 10-day auto-battler run where you grow mushroom troops, train them, and fight daily enemy armies for biomass.

## Language

### Run loop

**Run**:
A single playthrough of Auto Shrooms, lasting up to 10 days.
*Avoid*: campaign, session (when you mean the playthrough)

**Day**:
The primary unit of run progression. A day may or may not include a battle.
*Avoid*: chapter (UI progress-track slice only)

**Elite Day**:
A harder day that falls on days 5 and 10 of the run.

**Battle**:
A combat encounter fought during a day. Not every day necessarily has one.
*Avoid*: using Battle as the name for run progression

**Battle reward**:
Biomass granted for winning a Battle. The amount is set by the Day and that enemy army's difficulty — not by individual kills.
*Avoid*: kill bounty, per-kill biomass, currency drop

**Biomass**:
The run's spendable resource, shown in kg.
*Avoid*: gold, money, currency (unless speaking generically)

**Seal**:
A lasting run modifier chosen from offered picks. Rotten Thumb discounts the biomass cost of planting a fresh grow on a plot (not Mutation shop prices).
*Avoid*: relic, blessing, perk (when you mean a Seal)

**Starter package**:
The run-start offer of an initial Adult (and a hidden Child) the player chooses. The Adult begins at generation II; the Child at generation I. Starters do not begin with Mutations.

### Base

**Base**:
The between-battles hub where the player manages the run between days.

**War Chamber**:
The Base zone for the troop, scouting the enemy army, and starting a battle.

**Nursery**:
The Base zone where spores are grown on plots into Child units.

**Spore**:
A plantable Nursery item that grows into Child units. Shop offers are not spores; a lineage spore is still a spore.
*Avoid*: seed, egg

**Lineage spore**:
A spore produced when an Adult is composted or dies in battle, carrying that unit's lineage, weapon-school Trainings, and Mutations (not Fertilizers). Mutations are applied on plots only — not prepped onto spores in Stock. Death spores may still snapshot the parent's mutation.
*Avoid*: death spore (code name)

**Plot**:
A Nursery slot where a spore grows. Unlocked plots show blank Mutation and Fertilizer capacity chips that fill when items are applied.

**Fertilizer**:
A plot modifier that changes that grow's growth, hatch stats, or unit-life flags — not identity. Fertilizer items do not carry onto lineage spores (baked stats may still ride mean stats).
*Avoid*: using Fertilizer for Boom/Death/Mini-style identity

**Mutation**:
An identity modifier applied in the Nursery on a plot (including empty dirt). Plots and harvested units hold at most one Mutation for now — Body **or** Cap (typed fields remain; the other stays empty). Same-slot replace consumes the previous Mutation. Dual Body+Cap remix is deferred.
*Avoid*: Fertilizer (when you mean identity), trait, strain effect (as the item type)

**Body mutation**:
The Mutation slot that sets body-led identity and tints the shared body layer (no silhouette scale). Singular. (Includes forms such as Fat, Rubber, Zombie, Thorny.)

**Cap mutation**:
The Mutation slot that sets specialty combat or lifecycle identity and tints the shared cap layer. Singular. (Includes identities such as Death, Inky, Boom, Wall, Bank, Brood Empress, Mould.)

Player unit art is layered Generalist body + cap sprites (child pair while Child, imago pair while Adult). Mutations tint those layers; empty slots use fixed default layer colors; Tier multiplies both layers. The body layer owns weapon mount and animation; the cap follows.

**Shop**:
Rerollable biomass offers in the Nursery (Fertilizers and Mutations — not spores). Offer rows stay split — Fertilizer slots and Mutation slots — so both show every reroll. Each Mutation slot rolls independently (body or cap).

**Stock**:
The player's held lineage spores, Fertilizers, Mutations, and similar items ready to plant or use.

### Units

**Unit**:
One creature on the player's side — in the roster or in a battle.
*Avoid*: fighter, mushroom (as a type name), troop (for a single creature)

**Troop**:
The player's War Chamber roster as a whole (units on the squad and bench).
*Avoid*: army (for the player side), formation (for the roster)

**Squad**:
The units in the troop that will fight the next battle.

**Bench**:
The units in the troop held out of the fighting lineup.

**Child**:
A unit that has not yet become an Adult through Training (or a starter package Adult).
*Avoid*: juvenile (code id)

**Adult**:
A unit at adult life stage — reached by Training emerge, or granted by a starter package.
*Avoid*: imago, fully_evolved (code ids)

**Strain**:
Legacy species/archetype package on units (art + optional effect). Player-facing identity is moving to Body mutation + Cap mutation; do not use Strain for new Nursery identity design.
*Avoid*: using Strain when you mean Mutation

**Generation**:
How deep a unit sits in its bloodline (I, II, III, …). Generation I has a bare name; later generations append a Roman suffix. The starter Adult begins at II; fresh non-lineage grows and the starter Child begin at I.
*Avoid*: treating Generation as Tier

**Tier**:
A rarity/power band on player units (e.g. Common through Legendary). Fresh Nursery grows are Common for now; higher tier rides lineage from the parent when present.
*Avoid*: applying Tier to enemies; tiered shop spores (removed direction)

**Compost**:
Voluntarily removing a unit for biomass.

**Training**:
Putting a unit through a weapon school so it emerges as an Adult with that school's fighting identity.
*Avoid*: WeaponSchool (code)

**Cocoon**:
The Base slot where a unit sits while Training, out of the troop until it emerges.

**Weapon school**:
Sword, Shield, Spear, or Bow — the fighting identity Training grants.

**Weapon**:
The equipped fighting tool that drives a unit's combat behavior.

**Combo weapon**:
A weapon that comes from two weapon-school trainings on one Adult.

### Battle sides

**Enemy army**:
The set of enemies for a battle, as previewed and optionally rerolled by Scout.
*Avoid*: formation (for the enemy side), troop (for enemies)

**Scout**:
The Base preview of the upcoming enemy army (with optional biomass-priced reroll when allowed).

**Flag bearer**:
The player's unkillable banner in battle (player-only; not a Unit).

**Range class**:
A unit's Melee, Mid, or Ranged role in battle.
*Avoid*: formation, FormationLine (code)