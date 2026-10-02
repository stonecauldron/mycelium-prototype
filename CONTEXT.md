# Auto Shrooms

A 10-day auto-battler run where you grow mushroom troops, train them, and fight daily enemy armies for biomass, with an optional 15-day guided Run.

Shared presentation guidance: [UI conventions](docs/ui-conventions.md).

## Language

### Run loop

**Run**:
A single playthrough of Auto Shrooms, lasting up to 10 days, or 15 in a guided Run.
*Avoid*: campaign, session (when you mean the playthrough)

**Guided Run**:
An optional Run that introduces systems through scheduled unlocks and restricted choices. It starts with a fixed Sword Adult, makes a Child available before Day 2, and permits free Battle retries or restoring the current Day's preparation. Progress never requires tutorial actions; pending Seal choices still require selection before Battle. The next-Run checkbox turns off after the first guided Run ends, while later manual choices persist.

**Day**:
The primary unit of run progression. A day may or may not include a battle.
*Avoid*: chapter (UI progress-track slice only)

**Elite Day**:
A harder day that falls every fifth Day: 5 and 10 in an ordinary Run, also 15 in a guided Run.

**Battle**:
A combat encounter fought during a day. Not every day necessarily has one.
*Avoid*: using Battle as the name for run progression

**Battle reward**:
Biomass granted for winning a Battle. The amount is set by the Day and that enemy army's difficulty — not by individual kills.
*Avoid*: kill bounty, per-kill biomass, currency drop

**Biomass**:
The Run's spendable resource.
*Avoid*: gold, money, currency (unless speaking generically)

**Reroll Increase**:
The extra biomass added to each additional paid reroll's price within a Day: always 1 biomass.
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

**Base Undo**:
Reversing the latest completed Base action, including its Biomass and other consequences, one action at a time. History lasts for the current Base visit and ends at any paid reroll or the start of a Battle.

**Nursery**:
The Base zone where spores are grown on plots into Child units. It is not available at the start of a Run; it unlocks after the first Battle in an ordinary Run, or after Battle 5 in a guided Run.
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
Rerollable biomass offers in the Nursery (Fertilizers and Mutations — not spores, not Weapons). Fertilizers and Mutations occupy separate offer rows; paid rerolls use Reroll Increase per extra this Day.

**Shop roll**:
The group of new Shop offers generated together on initial fill, a paid reroll, or a daily refresh. Retained locked offers belong to earlier rolls and may match a newly rolled item.
*Avoid*: treating a Shop roll as all currently displayed offers

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

**Formation**:
The ordered placement of the Squad's Units in its slots before a Battle. Rearranging a Formation can include swapping Units with the Bench.
*Avoid*: Troop (the whole roster), Range class, live battle commands

**Squad slot**:
A fighting position in the Squad. Slots unlock in order from the flag. A locked slot cannot hold a Unit; unlocking one spends biomass. When every unlocked Squad slot is full, a new Unit goes to the Bench.
*Avoid*: troop slot (when you mean a Squad position)

**Bench**:
The units in the troop held out of the fighting lineup. Bench positions are available for the whole run — they are not Squad slots.

**Child**:
A unit at the life stage before Evolution into an Adult.
*Avoid*: juvenile (code id)

**Adult**:
A unit at adult life stage — reached through Evolution, or granted by a starter package.
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
Putting a Child or Adult through a weapon school to gain that school's fighting identity. Child Training includes Evolution into an Adult; Adults use **Train** and complete Training instantly on confirmation with their Stats and troop position unchanged.
Trainings retain their chronological order: a third Training replaces the oldest, keeps the newer one, and appends the newly applied school. Adult Training that leaves this ordered pair unchanged is unavailable and costs no Biomass; changing the order of two different schools is meaningful because it changes which one is replaced next.
*Avoid*: WeaponSchool (code)

**Evolution**:
A Child's transition into an Adult through weapon-school Training, started with **Evolve**. Evolution applies the Child's Training and Stat changes when it completes; it does not advance Generation.
*Avoid*: pupate, pupation; using Evolution for an Adult's further Training

**Cocoon**:
The Base slot used to start Training. A Child with a wait stays here out of the Troop until Evolution completes; Adult Training completes instantly.

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

**Bark**:
A brief, purely expressive line of dialogue spoken by a Unit or the Flag bearer during a Battle.
*Avoid*: combat log entry, tooltip (when you mean character dialogue)

**Enemy army**:
The set of enemies for a battle, as previewed and optionally rerolled by Scout. Ordered by Range class from rear to front: Ranged, then Mid, then Melee toward the player. Same Range class is shuffled. Not ordered by numeric attack reach.
*Avoid*: formation (for the enemy side), troop (for enemies)

**Enemy cost**:
The authored estimate of an enemy type's combat strength, expressed in army-budget points. It is not a biomass price or a Battle reward.

**Army budget**:
The allowance of enemy-cost points allocated to an enemy army within its Day's difficulty range. More expensive enemies use more of the allowance, leaving room for fewer enemies.

**Army pattern**:
The intended proportions of enemy types by headcount: One-trick pony, Hybrid, or Generalist. It describes the army's mix, not its Range classes.

**Regular enemy**:
An enemy type in the introductory enemy pool, distinct from Strong enemies.

**Strong enemy**:
An enemy type in the advanced enemy pool: Elite enemy armies contain only Strong enemies, and later non-elite armies may mix them with Regular enemies. This is an enemy category, not a player Tier.

**Scout**:
The Base preview of the upcoming enemy army (with optional biomass-priced reroll when allowed). The chapter's Day markers also let the player inspect each Day's initial army without changing the upcoming Battle. Hover temporarily overrides any pinned preview, then restores it on exit; clicking pins a Day. Hovering the upcoming Day shows its current army, including any paid reroll, while clicking it also clears the pin. Type order is the reverse of Enemy army Home order — Melee, then Mid, then Ranged — so it matches what the player faces. Reroll price uses Reroll Increase per extra this Day; Elite Days cannot be rerolled, and reroll is unavailable while previewing another Day or retaining a pinned Day.
*Avoid*: treating Scout order as Home order

**Flag bearer**:
The player's unkillable banner in battle, and the origin of player Homes (player-only; not a Unit).

**Home**:
A unit's rest position in battle, measured from the Flag bearer (player) or the enemy army's matching anchor, by Squad slot.
*Avoid*: formation home, rally point

**Range class**:
A unit's Melee, Mid, or Ranged role in battle.
*Avoid*: formation, FormationLine (code)

### Audio

**Base music**:
The music featured on the title screen and in the Base. It pauses after fading out for a Battle and resumes from that position starting on the day summary, victory, or game over screen. Starting a new Run restarts it from the beginning.

**Battle music**:
The music featured during Battles. It restarts for each new Battle and fades back to Base music starting on the day summary, victory, or game over screen.

### Distribution

**Steam App**:
Auto Shrooms as the full Steam product (4963670).
*Avoid*: using Steam App for the Demo SKU

**Steam Demo**:
The Steam Demo SKU of Auto Shrooms (5112860). A store listing, not a runtime/export flavor.
*Avoid*: demo (as a build flavor — that distinction does not exist yet), treating 5112860 as the Steam App
