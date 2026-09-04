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

**Reroll Increase**:
The extra biomass added to each additional reroll's price this Day, derived from the upcoming Day. Minimum of 1.
*Avoid*: wave, materials (other games); treating it as a separate spend

**Seal**:
A lasting run modifier chosen from offered picks. Rotten Thumb discounts the biomass cost of planting a fresh grow on a plot (not Mutation shop prices). Mid-run picks may be rerolled for biomass at a higher base than Shop or Scout; the run-start pick cannot.
*Avoid*: relic, blessing, perk (when you mean a Seal)

**Starter package**:
The run-start offer of an initial Adult (and a hidden Child) the player chooses. The Adult begins at generation II; the Child at generation I. Starters do not begin with Mutations.

### Base

**Base**:
The between-battles hub where the player manages the run between days. Its zones are the War Chamber, which is always available, and the Nursery.
*Avoid*: Riboforge, forge (as a Base zone)

**War Chamber**:
The Base zone for the troop, scouting the enemy army, and starting a battle.

**Nursery**:
The Base zone where spores are grown on plots into Child units. It is not available at the start of a Run; it unlocks after the first Battle.
*Avoid*: treating the Nursery as present for the whole Run

**Spore**:
A plantable Nursery item that grows into Child units. Shop offers are not spores; a lineage spore is still a spore.
*Avoid*: seed, egg

**Lineage spore**:
A spore produced when an Adult is composted or dies in battle, carrying that unit's lineage, current weapon-school Trainings (including those learned as an Adult), and Mutations (not Fertilizers). Mutations are applied on plots only — not prepped onto spores in Stock. Death spores may still snapshot the parent's mutation.
*Avoid*: death spore (code name)

**Plot**:
A Nursery slot where a spore grows. The Nursery has four Plots; they unlock in order. A locked Plot cannot hold a Spore; unlocking one spends biomass. Unlocked plots show blank Mutation and Fertilizer capacity chips that fill when Fertilizers are applied — not Fungicide. An empty Plot with Extra nutrition shows a Fungicide chip.

**Growth Time**:
The days a Spore needs on a Plot to become harvestable, counting Greenhouse but not Plot Fertilizers. Unplanted spores show this.
*Avoid*: remaining time, total time (when you mean the spore's authored wait)

**Remaining Time**:
The days left before a planted Plot is harvestable. Wait-changing Fertilizers adjust this in the order they were applied — replayed at plant if prepared on empty dirt — not Growth Time.
*Avoid*: growth time (once planted), total time

**Fertilizer**:
A plot modifier that changes that grow's Remaining Time, hatch stats, or unit-life flags — not identity. Items do not carry onto lineage spores (baked stats may still ride mean stats) and occupy a limited Plot stack except Fungicide.
*Avoid*: using Fertilizer for Boom/Death/Mini-style identity; treating wait-changing Fertilizers as cuts to Growth Time

**Fungicide**:
A Fertilizer that kills the current grow on a Plot and leaves Extra nutrition for the next harvest on that Plot. Applying it does not occupy the Fertilizer stack.
*Avoid*: treating Fungicide as a Mutation; treating it as a stack occupant

**Extra nutrition**:
A flat bonus to all three Stats (Strength, Dexterity, and Constitution) held on a Plot after Fungicide, consumed when the next Child is harvested from that Plot. It is not a Fertilizer stack occupant. While the Plot is empty, a Fungicide chip shows it; once a Spore is planted it shows in tooltips.
*Avoid*: residue, pending stat bonus, Fungicide stack

**Mutation**:
An identity modifier applied in the Nursery on a plot (including empty dirt). It does not change hatch Stats. A Plot holds at most one applied Mutation for now — Body **or** Cap — and an occupied slot cannot be replaced. A harvested unit can carry both when its Plot and lineage supply different slots. Dual Body+Cap plot remix is deferred.
*Avoid*: Fertilizer (when you mean identity), treating Mutation as a Stat source, trait, strain effect (as the item type)

**Body mutation**:
The Mutation slot that sets body-led identity and tints the shared body layer (no silhouette scale). Singular. (Includes forms such as Fat, Rubber, Zombie, Thorny.)

**Cap mutation**:
The Mutation slot that sets specialty combat or lifecycle identity and tints the shared cap layer. Singular. (Includes identities such as Death, Inky, Boom, Wall, Bank, Brood Empress, Mould.)

Player unit art is layered Generalist body + cap sprites (child pair while Child, imago pair while Adult). Mutations tint those layers; empty slots use fixed default layer colors; Tier multiplies both layers. The body layer owns weapon mount and animation; the cap follows.

**Shop**:
Rerollable biomass offers in the Nursery (Fertilizers and Mutations — not spores, not Weapons). Offer rows stay split — Fertilizer slots and Mutation slots — so both show every reroll. Each Mutation slot rolls independently (body or cap); paid rerolls use Reroll Increase per extra this Day.

**Offer lock**:
A flag on a Shop offer that keeps that offer through Shop reroll (paid and daily).
*Avoid*: lock (when you mean a Plot or Squad slot that is not yet unlocked); pin; freeze; locking Stock

**Stock**:
The player's held lineage spores, Fertilizers, and Mutations ready to plant or use.

### Units

**Unit**:
One creature on the player's side — in the roster or in a battle.
*Avoid*: fighter, mushroom (as a type name), troop (for a single creature)

**Stat**:
Strength, Dexterity, or Constitution on a Unit.
*Avoid*: SPD; Speed (as a Stat); cadence; treating Attack interval as a Stat

**Strength**:
The Stat abbreviated STR.

**Dexterity**:
The Stat abbreviated DEX.

**Constitution**:
The Stat abbreviated CON.

**Troop**:
The player's War Chamber roster as a whole (units on the squad and bench).
*Avoid*: army (for the player side), formation (for the roster)

**Squad**:
The units in the troop that will fight the next battle, occupying Squad slots.

**Squad slot**:
A fighting position in the Squad. Slots unlock in order from the flag. A locked slot cannot hold a Unit; unlocking one spends biomass. When every unlocked Squad slot is full, a new Unit goes to the Bench.
*Avoid*: troop slot (when you mean a Squad position)

**Bench**:
The units in the troop held out of the fighting lineup. Bench positions are available for the whole run — they are not Squad slots.

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

**Composting bin**:
The War Chamber's dedicated place for Compost, separate from weapon-school Cocoons. It is not a Squad slot.
*Avoid*: composting cocoon

**Training**:
Putting a Child or Adult through a weapon school to gain that school's fighting identity. A Child emerges as an Adult; an Adult can train again with its Stats unchanged.
*Avoid*: WeaponSchool (code)

**Cocoon**:
The Base slot where a unit sits while Training, out of the troop until it emerges.

**Weapon school**:
Sword, Mace, Shield, Spear, or Bow — the fighting identity Training grants.

**Weapon**:
The fighting tool a Unit uses in battle, set by its weapon-school Trainings. Not bought from the Shop and not freely swapped. Every player Unit has a Weapon.
*Avoid*: loadout (when you mean Training identity); treating Weapon as a Shop item; unarmed, Bare fists (as a player-facing empty slot)

**Blunt damage**:
A damage type that bypasses shield-style damage protection. Explicit blunt resistance can still reduce it.

**Attack interval**:
Seconds between attacks, authored on the Weapon for player Units and on each enemy type's combat profile. Shown as "Attacks every X secs". Seals and some Fertilizers can scale it; it is not a Stat.
*Avoid*: cadence; SPD; Speed (as this label); treating Attack interval as a Stat

**Combo weapon**:
A weapon that comes from two weapon-school trainings on one Adult.

### Battle sides

**Enemy army**:
The set of enemies for a battle, as previewed and optionally rerolled by Scout. Ordered by Range class from rear to front: Ranged, then Mid, then Melee toward the player. Same Range class is shuffled. Not ordered by numeric attack reach.
*Avoid*: formation (for the enemy side), troop (for enemies)

**Scout**:
The Base preview of the upcoming enemy army (with optional biomass-priced reroll when allowed). Type order is the reverse of Enemy army Home order — Melee, then Mid, then Ranged — so it matches what the player faces. Reroll price uses Reroll Increase per extra this Day; Elite Days cannot be rerolled.
*Avoid*: treating Scout order as Home order

**Flag bearer**:
The player's unkillable banner in battle, and the origin of player Homes (player-only; not a Unit).

**Home**:
A unit's rest position in battle, measured from the Flag bearer (player) or the enemy army's matching anchor, by Squad slot.
*Avoid*: formation home, rally point

**Range class**:
A unit's Melee, Mid, or Ranged role in battle.
*Avoid*: formation, FormationLine (code)

### Distribution

**Steam App**:
Auto Shrooms as the full Steam product (4963670).
*Avoid*: using Steam App for the Demo SKU

**Steam Demo**:
The Steam Demo SKU of Auto Shrooms (5112860). A store listing, not a runtime/export flavor.
*Avoid*: demo (as a build flavor — that distinction does not exist yet), treating 5112860 as the Steam App
