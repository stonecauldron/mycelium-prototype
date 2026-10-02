# Exploring a less overwhelming opening

Status: implemented — automated and UI validation complete; pacing and comprehension need playtesting. Learning comes from restricted options and scheduled feature unlocks. No new onboarding text tooltips, hint panels, Guidance button, or contextual-help state. Tutorial practice never gates advancement; a pending Seal choice must be resolved before Battle, with Base management available meanwhile.

## Problem and working hypothesis

Playtesters commonly describe Auto Shrooms as overwhelming. The developer clarified that this persists throughout Runs, is especially pronounced at the beginning, and includes weapon Training. Training is therefore the first focus. We still need to distinguish difficulty with choosing a strategy, finding the next action, reading the interface, and understanding consequences.

The working hypothesis is that the opening asks for too many decisions before players have seen their consequences. A guided opening should reduce the active decision set through feature visibility, then let players explore available actions and observe their results. Explanatory text alone may add to the overload.

## Baseline findings before this work

These historical findings informed the design. The wider-game usability changes have since been implemented separately; the guided Run reuses their inspection UI, previews, and action feedback.

- `StarterChoiceDialog` presents five starter packages. Each previews a dual-trained Adult; `StarterPackages.build_units()` also supplies a Child that the picker does not show. Both are normally placed in the Squad.
- The live modal flow is Starter package, then opening Seal: `_ensure_seal_choice()` waits for a seeded troop. The root AGENTS.md currently describes the reverse order.
- Before the first Battle, the War Chamber builds all five weapon-school Cocoons, the Bench, the next Squad slot purchase, the Composting bin, and Scout.
- The first training arrow points at the starter Child. The Start Combat arrow appears once there is no training-hint Child. Combat is still available without training; this is a coaching sequence rather than a requirement.
- The Nursery unlocks after Battle 1. It exposes planting, the next Plot purchase, Stock, two Fertilizer offers, two Mutation offers, offer locks, and Shop reroll together. Victories subsequently prefer the Nursery tab.
- A fresh Common grow costs 4 biomass and normally takes two day advances. `NurseryData.plant_spore()` already shortens the first planting of each Run to at most one day, before other modifiers. Child Training costs 3 and normally takes one day advance; Adult Training is instant. Starting biomass is 3. These timings matter when scheduling unlocks.
- Existing arrows cover first planting, harvesting, training, and combat. There is a saved `SettingsServer.show_tutorial` preference, but the source search found no gameplay consumers of that setting.
- Training has several distinct rules: a Child becomes an Adult, changes Stats, and leaves the troop for one day; an Adult trains instantly without Stat gains. Two Trainings determine a combo Weapon, including two of the same school. Further Training replaces the oldest of the two active Trainings. These are substantial concepts to encounter together.
- The Child confirmation title says “Pupate” while the header and school UI say “Training.” The Adult confirmation hides the current-side comparison and shows the resulting Unit. Unit detail tooltips already show the active Trainings, so the opportunity is to put that information directly into the decision rather than add another distant reference screen.

Relevant sources: [run state](../../assets/autoload/game_state.gd), [War Chamber](../../assets/base/troop_selection/troop_selection_screen.gd), [starters](../../assets/base/starter_packages.gd), [Nursery](../../assets/base/nursery/nursery_screen.gd), [training](../../assets/base/pupation/weapon_school.gd), [Common grow](../../assets/base/nursery/common_spore.tres).

## Recommended direction

Combine a curated first run with changes that continue to help during ordinary Runs:

1. **Stage the available decisions.** Reveal features according to the Run's day schedule and hide those scheduled for later. Once unlocked, a feature remains available whether or not the player uses it.
2. **Let the available options teach.** Keep later systems hidden and expose a small set of usable choices at each unlock. Add no onboarding text tooltips, hint panels, Guidance button, tutorial arrows, or contextual-help state. Existing shared Unit/item inspection, action previews, and tooltips remain available.
3. **Make results readable.** When the player acts, highlight actual results: biomass earned, Remaining Time decreasing, or the same Child returning as an Adult. Keep the detailed recap available behind an expansion.

This follows the general principles of [progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/) and Microsoft's guidance on [clear objectives and interactive, replayable tutorials](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/109). They support the design approach; they do not establish which change will work best for this game.

A guided Run lasts 15 Days, with three five-Battle chapters introducing combat roles, Formation, and Training; Nursery; then a first Seal, Compost, and lineage. Ordinary Runs retain their current 10-Day length. Reuse the existing Base, combat, and action rules with a feature-unlock schedule. Playtests must cover both players who explore each system and players who skip or use systems later.

## Core rule: tutorial practice is optional; normal Run choices still apply

Feature availability follows the upcoming Day and the existing Battle-win progression. Training, Formation changes, purchases, planting, harvesting, Composting, and lineage use are all optional. A player can reach the final victory with unused features; completing a tutorial checklist is not a condition of Run completion. A pending Seal choice is an explicit exception: the player must choose a Seal before the next Battle, but can hide the chooser and inspect or manage the Base first. Any offered Seal satisfies that normal Run choice; no particular build or recommended option is required.

**Start Battle uses normal gameplay eligibility**, including having a Unit in the Squad and resolving any pending Seal choice. No tutorial flag may disable it because a recommended action is incomplete. No mandatory Next/Continue prompt, spotlight that blocks other controls, forced tab visit, or repeated nagging may substitute for that gate. Normal action rules, costs, confirmation dialogs for chosen actions, and Battle outcomes still apply.

The schedule below defines opportunities, not an expected sequence of clicks or a required roster. Later unlocks do not wait for earlier features to be used. Players learn by exploring the available schools, troop arrangement, plots, and offers. Shared inspection and previews display the actual Unit or item; there is no scripted instruction sequence or assumed roster.

Curated encounters should support multiple viable preparations. An unlocked tool can make a problem easier, but an encounter must not function as a disguised requirement to perform one exact tutorial action. In particular, Mace is a useful answer to Log rather than the only allowed answer. Validate alternate approaches and retain Battle retries and Change preparation.

## Requested milestones

- Learning is led by unlocks and hiding of features. No new onboarding text or prescribed tutorial action is required for progress.
- Players can restart Battles. Every failed Battle in a guided Run must offer **Restart Battle**, preserving the active Run and earlier completed Days.
- Use Bow as the proposed first Child Training, replacing Shield in the opening, to introduce melee versus ranged roles and a practical reason to change Formation.
- Introduce the daily progression bar before Battle 4.
- Introduce Mace Training before Battle 5; that Battle is elite and includes a Log enemy.
- Unlock the Nursery after winning the Battle on Day 5.
- Introduce the first Seal choice after winning Battle 10, before Battle 11, then continue the normal reward schedule: choices before Battles 12 and 15 within this guided Run. Selection is required before the next Battle; hiding the chooser lets players inspect and manage the War Chamber and Nursery. Mark each receiving Day with a graphical Seal icon and preserve the existing shared Seal inspection tooltip.
- Continue after Day 10 through Day 15, introducing Compost and lineage spores. Day 15 is the guided Run's final elite Battle.
- Let the player choose a guided or ordinary Run when starting a New Run. The guided option starts checked and becomes unchecked after the first guided Run ends; it remains available to choose again.

The delayed Nursery, curated enemies, and staged UI apply to guided Runs. Ordinary Runs keep their current progression. “Before Battle N” means the preparation phase for Day N; “after Battle N” means after its victory and day advancement.

## Shared Training improvements (separate implementation)

These wider-game changes are assumed to be implemented separately. Reuse them; do not expand this guided-run task into a Training UI redesign. The clickable Train entry point was not included in the confirmed shared scope.

Make the training decision answer four questions at a glance: what changes, when the Unit can fight, what it costs, and which school is being added or replaced.

- Use “Train” consistently, including for Children. Explain the resulting adulthood in the preview rather than introducing “Pupate” as a second action name.
- Present the recipe directly: `Sword + Mace → Warhammer`, with a short role description and the actual Unit preview. Also show `Sword + Sword → Great Sword` when relevant, so repeated schools are an intentional choice.
- For a Child, say “Returns after the next Battle” for the default one-day wait and show the Stat changes. For an Adult, say “Ready immediately · Stats unchanged.” Derive these summaries from the actual result, including altered wait durations.
- When two Trainings are already present, show which one will be replaced before confirmation. Do not require players to remember insertion order.
- Keep numeric detail accessible. Lead with Weapon, role, cost, and availability rather than requiring the player to decode all three Stat deltas to understand the action.

Potential implementation touchpoints are [training confirmation](../../assets/base/pupation/pupation_confirm_dialog.gd), [school hover card](../../assets/base/pupation/school_training_detail_card.gd), [existing training display](../../assets/base/unit_detail_card/unit_detail_card_content.gd), and [recipe/preview rules](../../assets/base/pupation/weapon_school.gd). The existing preview functions should remain the source of truth.

## Guided Run unlock schedule

Introduce combat roles, Formation, and Training on Days 1–5, the Nursery on Days 6–10, and the first Seal alongside Compost and lineage from Day 11. Unlocked features stay available. Days without a new feature leave room for exploration; they do not require the player to demonstrate a skill. Squad rearrangement is available from the start, as already specified.

| Preparation | Feature availability | Available choices and possible result |
| --- | --- | --- |
| Before Battle 1 | Fixed starter and Battle preview | Supply a fixed Sword-trained Adult and a curated enemy army. Show the Squad, Next Battle without reroll, and Start Battle; keep later management features hidden. The player can rearrange the Squad. No starter or Seal choice blocks entry. |
| Before Battle 2 | Bow school and starter Child | Reveal the reserved Child and Bow Training. The existing Training preview shows ranged attacks, the 3 biomass cost, and the selected Unit's actual wait. Any eligible Unit can use the school; the player can also leave it unused. A Child trained now returns before Battle 3. |
| Before Battle 3 | Sword school; melee/ranged Formation choices | Make the familiar Sword school's Training option available. Players with melee and ranged Units can explore their positioning and observe the Battle. They may keep their positions, choose any legal Training, or start Battle immediately. |
| Before Battle 4 | Daily progression bar | Show completed days, the Day-4 marker, and the Day-5 elite skull with its preview. The bar appears whether or not Training or Formation has been used. No new action is requested. |
| Before Battle 5 | Mace school and Log elite | Reveal Mace Training and preview Log's weakness to blunt damage. Show the actual recipe for any selected Unit; Sword + Mace → Warhammer is one possible choice. Winning this Battle unlocks the Nursery, regardless of how it was won. |
| Before Battle 6 | Nursery tab and one Plot | Make the Nursery available after Battle 5; the player chooses whether to visit. Show Plant and the actual cost/wait preview. The first planting takes one day whenever the player chooses to make it. |
| Before Battle 7 | Shop with Quick Growth | Reveal a small Shop with a guaranteed Quick Growth offer, even if the player has not planted. Its existing inspection UI shows the effect on Remaining Time. Shared readiness indicators appear only for actual READY Plots. |
| Before Battle 8 | Mutation offer | Add a guaranteed Thorny offer to the Shop. Preview its combat effect and valid empty/growing Plot targets. Buying and applying it are optional; there is no assumption that a particular grow exists. |
| Before Battle 9 | Squad slot purchase | Reveal the next Squad slot purchase. Rearranging with the Bench or buying a slot are available options. Quick Growth and Thorny remain available without requiring earlier purchases. |
| Before Battle 10 | Elite Battle | Add no new preparation feature. Fight with the chosen troop; victory opens Days 11–15 and the first Seal choice, regardless of Nursery use. Keep the Day-10 skull as the elite marker; the Seal icon belongs to Day 11, when it is received. |
| Before Battle 11 | First Seal choice; Composting bin and lineage information | Offer melee damage, ranged damage, or health for the rest of the Run. The player can hide the chooser to inspect or manage either Base area, then confirm any offered Seal before Battle. Reveal Compost independently; using it remains optional. An Adult can yield biomass and a lineage spore; a spore planted now would be READY before Battle 12. Stock is visible when it contains an item. |
| Before Battle 12 | Next Seal on the normal schedule | Receive another Seal choice and use the same Hide / Select Seal / Start Battle flow. The shared hatch result and Unit inspection show any lineage Child actually harvested. No lineage grow or Training is required. |
| Before Battle 13 | Existing features remain available | If the player inspects Compost for a mutated Adult, show that the Mutation passes to its spore. Mutation inheritance is always part of the real preview, not a rule locked to this Day. No second Compost is requested. |
| Before Battle 14 | Preparation time | Show readiness and availability for the player's actual grows and Units. Players choose whether to grow, train, rearrange, or keep their troop. No descendant is required. |
| Before Battle 15 | Scheduled Seal choice and final elite Battle | Receive the next regular Seal choice before combat. Show both a Seal icon and the elite skull on Day 15. Fight with the chosen troop; final victory completes the guided Run, including when the player never Composted, grew a lineage, or used other optional features. |

Use the existing Unit names, portraits, and result presentations to connect real grow, Child, Cocoon, and Adult states. These reflect actual player choices and timing. A system used several Days after unlocking retains the same shared inspection and action-preview UI; there is no catch-up tutorial sequence.

### Bow, Formation, and early Training

Bow provides a visible contrast between melee and ranged roles. Reuse the shared Formation orientation markers so the player can connect the Base arrangement to Battle. Keep placement entirely under the player's control; add no positioning hint or required swap.

Use the existing slot swap interaction. Player combat Homes preserve War Chamber Squad slot order; slots nearer the Flag bearer are behind those farther forward. Returning Units enter the first free unlocked Squad slot. This may naturally put a newly trained Bow in front of the starter Sword. Do not require a swap, evaluate a mandatory correct answer, or rearrange Units for the player.

A small melee enemy army around Day 3 can make the contrast visible. Bow uses the existing skirmishing behavior and can retreat when enemies approach. Test both arrangements with the same enemies and Stats; the proposed advantage of rear placement needs to be observable under the actual combat rules. Neither placement is a tutorial failure. If the player has no Bow, the Battle and subsequent unlocks still proceed normally.

Day 5 provides a natural opportunity to discover a combo through Mace. Players may discover combos earlier by training an Adult in an available school; do not restrict Training to Children or block a legal combination to preserve an intended reveal. Show the actual Weapon and availability before confirmation. Oldest-Training replacement remains visible in the shared Training preview, regardless of Day.

### Day 4 progression bar

Reveal the existing `CombatProgressTrack` without an introductory callout. The skull preview must show the same authored Log army that will fight on Day 5. After each elite victory, move the track to the next five Days: 6–10, then 11–15. Keep Scout reroll hidden throughout the guided Run. Viewing or hovering the track is never required to start a Battle.

Place a small graphical Seal icon beside or above the **Day on which the player receives the choice**, using the existing Seal artwork (`assets/base/seals/seal.png`). Keep the track itself graphical: no persistent “Seal after victory” caption or sentence. Preserve the day number, current-day marker, and elite skull. When a Seal and elite share a Day, show both icons without obscuring the skull's enemy preview; this occurs on guided Day 15.

The guided icons belong on **Days 11, 12, and 15**. The first choice becomes available after accepting the Battle-10 victory and entering Day-11 preparation, so its icon is on Day 11, not the Day-10 skull. Show the upcoming icons as soon as their five-Day chapter appears; entering Days 11–15 reveals all three. The existing five-Day track does not preview Day 11 during the Days 6–10 chapter. Do not move the icon to an earlier Day to anticipate that chapter transition.

Preserve the shared hover/focus Seal inspection tooltip and accessible names; add no onboarding explanation to the track. A subtle outline/filled/check treatment can distinguish upcoming, pending, and claimed choices without relying only on color. Keep the Seal symbol recognizable in every state. Pending choices also drive the Base's Hide / Select Seal button; hovering or focusing the track never claims a reward or becomes a requirement.

Use the same per-mode schedule for awarding choices and drawing icons. Ordinary Runs currently grant an opening Seal before Battle 1 and later choices before Battles 3, 6, and 9 (after victories 2, 5, and 8), so their icons belong on **Days 1, 3, 6, and 9**. Continuing that regular calendar beyond Day 10 gives choices before Battles 12 and 15. Guided mode suppresses the early picks, introduces Seals before Battle 11, and resumes that existing calendar rather than restarting a three-Day interval from the introduction. Its icons and rewards therefore agree on Days 11, 12, and 15; Day 14 has no Seal reward. Ordinary Runs still end on Day 10 with their existing rewards.

### Seals from Day 11, then the normal schedule

Create the first guided Seal opportunity once when the Day-10 victory is accepted and the Run advances to Day-11 preparation. No Seal is granted on a failed or still-replayable Day-10 attempt. Show the existing chooser once on arrival, with its normal Seal descriptions. The player must confirm one of the offered Seals before Battle 11, but may hide the chooser for as long as they want while preparing. Hiding is not rejecting the reward or choosing a default; the same opportunity remains pending.

After introduction, keep granting Seals on the normal schedule. In this 15-Day Run, accepting the victories on Days 11 and 14 creates the next choices for preparation on Days 12 and 15. These are additional Seals, not replacements for the first one. Each scheduled choice uses the same hide/reopen/confirm interaction and must be resolved before that Day's Battle. No skipped early rewards are granted retroactively, and final victory does not create an unusable post-Run choice.

The baseline hard-coded completed Days 2 / 5 / 8 because ordinary Runs end at Day 10. The extended guided Run must continue the regular every-third-preparation-Day rule after the introductory choice, bounded by its Run length. Keep choice identity separate from chooser visibility so each scheduled Day grants once even across tab changes, retry, or restored preparation.

Use the existing bottom Battle-action position for this state-dependent control:

| State | Main button | Behavior |
| --- | --- | --- |
| Pending choice, chooser visible | **Hide** | Hide the chooser and its dimming/input layer; keep the Seal choice pending. Escape performs the same action. |
| Pending choice, chooser hidden | **Select Seal** | Reopen the same offers and preserve any highlighted card. Available from both the War Chamber and Nursery. |
| No pending choice | **Start Battle** | Start combat when normal Squad requirements are met. Confirming a Seal restores this label; it does not launch combat automatically. |

Keep the Hide button reachable above the chooser's overlay. While hidden, show the full Base normally: tab buttons and shortcuts, Unit inspection, Formation, Training, planting, harvesting, and other unlocked management actions remain usable under their normal rules. Restore the same tab and camera position when hiding; reopening the chooser does not force a trip to the War Chamber. Hide and Select Seal remain enabled even when the Squad currently cannot fight. The chooser retains a separate **Confirm Seal** action for the highlighted card; selecting or highlighting a card alone does not apply its effect.

Preserve the same offers, highlighted choice, and any ordinary-run reroll count/cost across hide/show and tab changes. Hiding is never a free reroll, cancellation, or confirmation. Base edits remain in place, and any state-dependent Seal information refreshes when reopened. Tab changes, HUD refreshes, and other dialogs must not automatically reopen a chooser the player hid. Separate the pending reward from whether its chooser is visible. Apply this inspect-and-return interaction to ordinary Seal choices too, respecting which Base areas are unlocked in that mode.

For the first draft, offer three existing, concrete Seals: **Wooden Sword** (+2 melee damage), **Wooden Bow** (+2 ranged damage), and **Wooden Heart** (+8 health). Show their actual descriptions and effects; they are Run bonuses, not weapon Trainings. All three are available regardless of whether the player trained a Bow, used the Nursery, or bought a Mutation. Use this small curated set without Seal reroll. Keep growth, economy, and conditional Seal effects for ordinary Runs so the first choice does not add exceptions to the newly introduced Nursery rules. Show the confirmed Seal among the Run's active bonuses. Subsequent guided choices reuse this small offer set and the same normal ownership and stacking rules; continuing the reward schedule does not itself reveal the broader catalog or Seal reroll. If the player chooses another copy of a stackable Seal, show the owned count and resulting total bonus. This is a legitimate additional reward, distinct from accidentally applying the same choice twice.

Reuse the shared `pending_seal_choice` combat rule and chooser interaction: hiding leaves the pending flag intact and suppresses automatic reopening, and the Base button selects Hide / Select Seal / Start Battle from actual state. Guard every combat-entry path so none starts Battle with a pending choice. Suppress the ordinary opening and post-Day-2/5/8 picks in guided mode. Create its introductory choice before Battle 11, then resume the normal calendar with choices before Battles 12 and 15. Do not reuse `can_start_combat()` to disable Hide or Select Seal; their availability is independent of combat eligibility.

Include scheduled-choice identity, offers, highlighted choice, visibility, claimed state, owned Seals, and their effects in retry snapshots. On Days 11, 12, and 15, capture preparation after creating that Day's pending opportunity and before its selection. Restart Battle retains all pre-combat Seals exactly once. Change preparation restores the start of that Day: undo its new claim and restore the same pending choice, while preserving all Seals claimed on earlier Days. Track whether each reward was claimed by its scheduled opportunity, not just Seal type, since different rewards may legitimately grant the same stackable Seal. No retry may duplicate a reward, generate new offers, or allow combat while the restored choice is pending.

Compost becomes available during this same preparation phase, independently of the Seal confirmation. Its normal action preview remains available when the player inspects the bin. No Compost action or Nursery visit is required to confirm a Seal.

Relevant sources: [Seal schedule and application](../../assets/autoload/game_state.gd), [Base action button and combat gate](../../assets/base/base.gd), [chooser creation and reopen behavior](../../assets/base/troop_selection/troop_selection_screen.gd), [Seal chooser](../../assets/base/seals/seal_choice_dialog.gd), and [progression track](../../assets/base/combat_progress_track/combat_progress_track.gd).

### Day 5 Mace and Log

Log's authored profile resists slashing damage, while blunt damage bypasses that protection. Mace therefore offers a useful new answer. If the selected Adult still has `[Sword]`, adding Mace produces `[Sword, Mace]`, a Warhammer, instantly with Stats unchanged. If its Trainings differ, show its real recipe instead. The Bow and the original Sword's unchanged loadout are possible states, not prerequisites.

Use the existing Log data and combat rules. A single Log has an Army cost of 24, below the normal Day-5 budget range of 82–111. This guided encounter is an explicit authored-content exception to procedural budget generation in ADR-0015. Keep it marked elite and use the same cached formation for the skull, Scout, and Battle. Keep the normal Battle-reward calculation and preview its result.

Tune the encounter through playtests with multiple preparations, including viable approaches that do not use Mace. The Log should make blunt damage attractive without making one prescribed Training a hidden advancement requirement. No scripted defeat or automatic tutorial equipment change is permitted. Failed Battles offer the existing planned restart choices.

### Nursery availability, offers, and capacity

After the fifth victory, the Nursery tab becomes available. Its appearance exposes the new choice without a tutorial prompt. Entering it, planting, and harvesting are optional. Its scheduled Shop and Mutation unlocks happen on time even if the player has never visited the tab.

Offer Quick Growth from Day 7 and Thorny from Day 8, continuing to make these introductory items available through Day 15. Keep the limited catalog stable so someone who explores later can still use it. Purchasing an item does not advance a tutorial step or unlock another category. Support direct Shop-to-Plot use and the existing Stock route. Stock appears whenever it contains an item, including an earlier lineage spore from a fallen Adult; hiding future features must not hide possessions the player already has. Before the Nursery opens, a Stock button in the War Chamber exposes existing spore inspection in a read-only popup. It does not permit planting, selling, or dragging items, and does not unlock the Nursery early.

Use real timing and application rules in previews. The first planting takes one day whenever it occurs; later fresh Common grows normally take two. Quick Growth changes Remaining Time, not Growth Time, following ADR-0007. It may turn a one-day grow READY immediately. Thorny can be applied to an empty or growing Plot; a READY Plot's normal restrictions remain. Do not assume the player has a second grow, an empty Plot, or a mutated Unit on a given Day.

The next Squad slot purchase appears on Day 9. The number of Units is determined by the player's choices; the shared slot and affordability UI reflects current capacity. Benching or swapping Units remains an alternative to buying space. A grow left READY or a Unit kept on the Bench does not prevent Battle launch when normal Squad requirements are met.

Use ordinary costs, spending, and affordability. Do not reserve biomass for a required tutorial purchase, force a refund, or prevent legal spending to reserve a later purchase. The player can postpone a purchase or use Change preparation to revisit the current Day's choices. Balance should provide meaningful opportunities to try available tools without assuming every offer is bought.

The guided catalog introduces Sword, Bow, Mace, Quick Growth, and Thorny, followed by the first Seal choice after Battle 10 and Compost and lineage from Day-11 preparation. Seal rewards then continue on the normal calendar, before Battles 12 and 15. Additional Plots, Shop/Scout/Seal rerolls, offer locks, more item varieties, Shield/Spear, and the broader Seal catalog remain deferred in this draft. These restrictions control feature availability; the pending Seal choice follows the explicit selection requirement above.

### Compost and lineage

Compost becomes available before Battle 11. Its preview explains the selected Unit's removal, actual biomass payout (normally 8 for these Adults), and resulting lineage spore. Only Adults produce lineage spores; the Child preview says that it produces no spore. The player chooses whether to Compost at all, may cancel the confirmation, and may keep every Adult through the final victory.

If a spore is produced, show the named item in Stock with the existing item inspection UI. Planting consumes that spore through the existing path, without charging the fresh-grow price again. Lineage Growth Time is normally one day. No planting deadline is imposed; no Plot is cleared or extra spore granted to keep a scripted schedule on track.

The existing hatch result and Unit/item inspection expose the actual inheritance when a lineage Child is harvested:

- Same lineage name, with Generation increased by one.
- The parent's current Trainings, including ones learned as an Adult, determine its Weapon immediately.
- The parent's Mutations carry through the spore onto the Child.
- It starts as a Child, with Stats rolled around the parent's saved Stats. Generation and Tier are distinct, and the next Generation is not an automatic power increase.

Fertilizer items do not carry onto spores, although baked Stat gains may influence the descendant through the parent's saved Stats. Keep that detail available in the preview without requiring the player to read it.

Training a descendant is optional and follows the normal Child rules. If it inherited two Trainings, a new one replaces the oldest; show that result before confirmation. Training the oldest school again can preserve the two-school combination while rotating its order. Use the actual Generation-scaled Stat changes and wait. A player may field the Child, bench it, train it later, or continue with the existing troop.

Mutation inheritance is visible in any relevant Compost preview from the moment the feature is available. It is not held back until Day 13, and a second Compost is never requested as a prerequisite. If the player has no mutated Adult or chooses to keep it, there is no missing tutorial objective.

An Adult lost in a won Battle can also produce a lineage spore. Show the actual item when it appears, including before Day 11, and provide access to its Stock inspection. Before the Nursery unlocks, that spore stays available for later planting. Do not manufacture a combat death or treat a spore from death as a reason to demand Composting. Restarting a failed attempt restores the parent and removes that attempt's spore together.

Use the normal Compost eligibility rules; an occupied Plot is not an extra tutorial prohibition on Composting. Show material inventory consequences in the action preview when Stock is full instead of silently clearing the player's items to enforce a scripted sequence. Keep the game and action-feedback rules authoritative.

### Examples of possible timing, not required routes

These examples verify that the unlocked systems can produce visible results within the Run. Shared previews and result presentations use the player's actual dates and state; no example is an expected tutorial route.

| Optional choice | Result under the existing timing rules |
| --- | --- |
| Train the starter Child in Bow before Battle 2 | Bow Adult available before Battle 3. |
| First planting before Battle 6; harvest and train before Battle 7 | New Adult available before Battle 8. |
| Plant and mutate a normal two-day grow before Battle 8; use Quick Growth at one day remaining before Battle 9; harvest and train | Mutated Adult available before Battle 10. |
| Compost an Adult and plant its spore before Battle 11; harvest and train before Battle 12 | Descendant Adult available before Battle 13. |
| Plant a mutated lineage spore before Battle 13; harvest and train before Battle 14 | Mutated descendant Adult available before Battle 15. |

Skipping or delaying any row is valid. The Run still unlocks later features and ends on its normal victory condition.

### Guided Run length and final progression

Day 10 is a chapter victory, and Day 15 is the guided Run victory. Continue normal end-of-day processing after Battle 10, including growth and Training, create the first pending Seal choice for Day 11, and show Days 11–15 on the bar. The guided preference remains active through this transition; automatic unchecking happens only when this 15-Day Run actually ends.

The baseline uses a shared `WIN_DAYS = 10`, and the procedural Army-budget table contains ten entries. The guided implementation uses a Run-specific length and authored guided encounters/budget ranges through Day 15. Do not extend the global constant alone or repeatedly reuse the clamped Day-10 army. Update the day label, progression bar, Scout and elite preview, combat launch and victory checks, reward difficulty lookup, and analytics day handling to use the appropriate mode's length and content. Ordinary Runs still end after Day 10. This extends the guided-content exception described above for ADR-0015; the inheritance behavior itself follows ADR-0003.

Relevant sources: [lineage decision](../../docs/adr/0003-lineage-spores-from-adults.md), [spore snapshot](../../assets/base/nursery/spore_data.gd), [harvest and Stock](../../assets/base/nursery/nursery_data.gd), and [Compost preview](../../assets/base/pupation/compost_confirm_dialog.gd).

## Restarting Battles

Every guided Battle defeat, including elite Battles on Days 5, 10, and 15, shows **Restart Battle** as the primary action. Restarting is free and remains available after repeated failures. The defeat does not advance the Day, end the Run, mark onboarding complete, or uncheck the guided-run preference.

In guided mode, offer two clearly named actions:

- **Restart Battle** restores the snapshot taken immediately before combat and restarts with the same preparation and enemy army. Make it available from the paused Battle menu and the result screen until the player continues to the next Day.
- **Change preparation** restores the start of the same Day's preparation phase and returns to the Base, so the player can choose different Trainings, purchases, or Formation. Offer it alongside Restart Battle after a defeat. Its description says that this Day's preparation will be reset and its spending restored.

Both actions preserve the Run and completed earlier Days. Restore Unit health and life state, troop/Cocoons, biomass, grows, Stock, Shop offers, Seal opportunities and owned bonuses, day counters, and unlock state from the relevant checkpoint. Keep the authored enemy army and its rolled instance Stats stable. Capture these through one Run snapshot mechanism, with checkpoints at preparation start and combat launch, rather than trying to reverse individual combat effects.

Rewards, deaths, lineage spores, Seal bonuses, grow ticks, and day advancement from the discarded attempt must not accumulate. A replayed victory awards the Day once. Clear stale recap/launch data and reset combat engine timing before restarting or returning to the Base. Do not reroll Shop or Seal offers or enemies on retry. Guided attempts and retries do not emit gameplay analytics.

A defeat initially opens the retry choices; it does not automatically end the guided Run. The player can explicitly choose **End Run**. A first loss should lead to an opportunity to change a decision without replaying earlier Days.

## Choosing a guided Run

Place a separate checkbox immediately below the **New Run** button, within the same menu group:

`☑ Guided run`

The checkbox toggles the mode without starting a Run. The New Run button starts the selected mode. Keep it separately focusable and give the entire checkbox label a usable click target. Use the same selector at every New Run entry point, including victory and game-over screens.

- First launch: checked by default; the player can uncheck it immediately.
- Store an explicit user choice so returning to the menu does not repeatedly undo it.
- On the first guided Run's terminal end, automatically set the next-Run preference to unchecked. Terminal end means accepting the final victory or an explicit End Run/Return to title; a retryable Battle defeat or a result screen still offering replay is not a terminal end. Closing the app unexpectedly does not mark the learning sequence completed.
- The player can check the option again for another guided Run. The automatic switch happens only once and must not override later deliberate selections.
- Store guided completion/first-end history separately from the next-Run preference and from the active Run's mode. An early end can clear the default without claiming final victory. Winning Day 15 completes the guided Run regardless of optional feature use.
- Starting an ordinary Run uses the existing starter/Seal flow and progression. Starting a guided Run seeds the curated troop and content directly.

Store the active Run mode and day-based unlock schedule separately from the saved next-Run preference and first guided-end history. Feature availability never depends on action-completion flags. No contextual-help or dismissal state is needed.

## Other remedies worth testing

| Observed difficulty | Candidate remedy |
| --- | --- |
| “I don't know what to do next.” | Smaller sets of available options, shared graphical readiness indicators, and a clearer primary action. |
| “I can't judge these choices.” | Fixed opening content, smaller offer sets, and teaching a consequence before asking for an irreversible strategic choice. |
| “There is too much to read.” | Put the next decision's essential facts on the card; move formulas and advanced detail into an expandable view. Test readability at actual play size. |
| “I don't know why I lost.” | Review battle readability and recap usefulness. A longer management tutorial may leave this problem intact. Show factual outcomes; avoid claiming a counterfactual cause the game has not evaluated. |
| “I understood it, then forgot.” | Consistent shared inspection and action previews, plus access to replay the guided Run. |

## Unlock and interaction behavior

- Unlock features on the scheduled Day, independently of earlier tutorial practice. Keep them available afterward; no required Training, purchase, placement, harvest, or Compost action advances the schedule. A pending Seal must be chosen before Battle, but never prevents inspecting or managing the Base, or delays other features scheduled for the same preparation phase.
- Reuse normal authoritative action checks and feedback. Failed drops and unaffordable actions do not consume items or produce success feedback. Successful actions use the existing result feedback and never grant permission to progress.
- Add no onboarding text tooltips, hint panels, Guidance button, or contextual-help state. Suppress existing tutorial coaching arrows during guided Runs. Preserve shared gameplay inspection/tooltips, drag/drop target feedback, and normal confirmation dialogs.
- Shared previews and result feedback reflect actual Units, grows, and successful events. Delayed use needs no forced catch-up actions, replacement items, or prescribed roster.
- Let players opt out when starting a New Run and explicitly end a guided Run to choose another mode. Replaying remains available through the New Run checkbox. Keep victory history, the next-Run preference, and active mode separate.
- Keep underlying costs and waits recognizable. Curated offers, troop composition, and enemy armies are teaching content; altered economy and timing would need separate justification.
- Check loss, Return to title, New Run, screen changes, alternate input paths, and debug behavior when implementing. Guided availability must not leak into ordinary Runs.

## How to judge the experiment

Observe a small group of new players with the current opening and another with the candidate opening. Keep the facilitator from rescuing them immediately. Record where they hesitate and what they think each action will do.

Useful measures are time to first Battle, requests for help, abandoned openings, mistaken predictions about Training, and overload ratings after Days 4, 5, 8, 11, and 12. Observe understanding when players actually encounter a system: melee versus ranged positioning, the selected Unit's Training result and wait, Quick Growth's effect, a Seal's Run-wide bonus, or what a descendant inherits. Ask about an actual choice rather than requiring a specific build or grow on a specific Day. These are playtest observations, never in-game advancement tests. Record voluntary use and delayed use separately from whether players noticed an unlock; skipping a feature is not itself a comprehension failure. Also measure fatigue and drop-off during the longer 15-Day guided Run.

First-Battle completion alone is insufficient; removing decisions can improve that measure without improving understanding or enjoyment. Watch whether players find the available choices sufficient, whether they can proceed using the available controls, and whether they understand outcomes by observing their choices.

Exclude guided Runs from ordinary Run/Day progression, combat, retry, resource, and in-run intent analytics. Record only a guided Run start and a terminal event with the reached Day and whether the player quit or completed it. A replayable result still belongs to its Battle's Day; accepting Continue moves to the next Day. End Run, Return to title, and application quit record one terminal exit; final accepted victory records completion once. A retryable defeat does not end analytics tracking. Ordinary analytics remain unchanged. Comprehension and voluntary feature use are assessed through observed playtests rather than new guided gameplay events.

Before release, verify the schedule and divergent player choices:

- No new onboarding text tooltips, hint panels, or Guidance button appear. Skip Bow Training and Formation changes, then win: the progression bar still appears before Battle 4, Mace before Battle 5, and the Nursery after its victory. No tutorial action gates normal controls.
- Training an Adult or discovering a combo before Day 5 remains legal within the available schools. Every preview shows the actual result, including oldest-Training replacement and actual wait.
- Never visit the Nursery: Shop and Mutation offers still become available on Days 7 and 8. A READY grow, an unused offer, or a benched Unit never blocks an otherwise eligible Battle.
- Verify the optional timing examples above. Also plant for the first time before Battle 9: that first grow is READY before Battle 10. Delayed planting, Training, and harvesting retain accurate shared previews and result feedback.
- An Adult lost during a won Battle before Day 5 leaves a visible Stock button during the next preparation. The existing spore tooltip works in its read-only popup; dragging and planting remain unavailable until the Nursery opens. The owned item remains unchanged.
- A lineage path consumes the chosen Stock spore once, uses its real Growth Time, preserves inherited Trainings and Mutations, and previews any Training replacement correctly. Compost preview and execution agree on payout and removal. Keeping every Adult and never growing a descendant remains valid through final victory.
- The optional Bow trained before Battle 2 returns before Battle 3. A Squad-slot swap changes its actual combat spawn position. Compare front and rear arrangements with matched Stats/enemies to assess visibility despite skirmishing; neither arrangement gates progress.
- If an Adult still has only Sword Training, adding Mace produces Warhammer instantly without increasing Stats. Validate the authored Log across expected Stat variation and viable preparations without Mace; no exact recipe is required to advance.
- The Days 11–15 track shows graphical Seal icons on receiving Days 11, 12, and 15, with the existing shared inspection tooltip and accessibility labels. Day 10 has no Seal icon. Day 15 preserves both its Seal icon and elite skull, enemy preview, and current-day marker without overlap.
- No first Seal is available before or during Battle 10, or on defeat. Accepting victory creates one pending choice before Battle 11; the accepted victories on Days 11 and 14 create one additional choice each before Battles 12 and 15. No extra choice appears on Day 14, no early rewards are backfilled, and no reward queues after final victory.
- The first pending chooser opens once on entering Day-11 preparation. Hide and Escape expose the Base; Select Seal reopens the same offers and highlighted card from either tab. Tab changes, HUD refreshes, and other action dialogs do not force it open again or reroll its contents.
- While the chooser is hidden, inspect and manage Units, Training, Formation, Nursery grows, Stock, and unlocked offers. Changes persist after reopening. Hide / Select Seal work with an empty Squad; Start Battle returns after Seal confirmation and follows normal Squad eligibility. Confirmation never launches combat automatically.
- Every combat-entry path respects the pending choice. No battle starts before a Seal is confirmed, but other Day-11 unlocks and all legal Base actions remain available. Confirming any offered Seal resolves the choice without a specific tutorial build or prior Nursery action.
- On each Seal Day (11, 12, and 15), all confirmed Seals survive Restart Battle exactly once. Change preparation undoes that Day's new claim and restores the same pending offers, while retaining earlier rewards. Verify both selecting different Seal types and deliberately stacking another copy of the same eligible Seal; retry must not create an additional copy.
- Ordinary Seal icons appear on receiving Days 1, 3, 6, and 9. Guided icons appear on Days 11, 12, and 15. Their schedules match actual choice availability, and ordinary pick timing remains unchanged. Hide/show preserves offers and paid reroll state and still requires a choice before Battle.
- Guided victory at Day 10 continues growth, Training, the day counter, and the progression track through Days 11–15, creating its Seal choice once at the transition. Final victory completes the guided Run even with unused optional Training, Nursery, or lineage features; ordinary completion stays at Day 10. The New Run preference does not switch off at the guided chapter boundary.
- Repeating either retry action restores its checkpoint without duplicate biomass, spore drops, Seal effects, progression, or time ticks. Include replay after victory, returning to preparation after instant Training or Composting, and choices that skipped available features. Restore a removed parent and its spore consistently.
- Lose a regular guided Battle and each guided elite Battle, then lose the retry: Restart Battle remains available and preserves the active guided Run and its preference each time.
- Ordinary Runs still unlock the Nursery after Day 1. Scheduled feature hiding in guided mode applies consistently to UI and shortcuts; once revealed, features require only their normal gameplay eligibility.
- The guided option defaults on, respects an immediate opt-out, switches off after the first terminal guided end, survives app restart, and allows a deliberate later guided replay. Its label is exactly “Guided run”.

## Open questions

- Which part of Training causes the most confusion: starting it, selecting a school, timing, Stat gains, combos, or replacement?
- Are players confused by controls, vocabulary, choices, or battle causality?
- Does Bow positioning produce a clear enough combat difference, and does making Mace available on Day 5 give players room to explore basic roles without restricting earlier combos?
- Does Day 7 offer enough breathing room for players who happen to harvest and inspect the Shop together? Observe late and skipped use as well.
- Is Thorny's combat effect easy enough to notice to serve as the first Mutation, or does it need clearer hit feedback?
- Are the introductory Seal on Day 11 and the next regular reward on Day 12 manageable alongside the Compost unlock? This proximity follows the normal calendar; observe it without silently shifting subsequent rewards to a new cadence. Does hiding and reopening the chooser let players make an informed choice without losing their place? Neither system waits for the other to be used.
- Can players understand inheritance through the preview and their chosen lineage experiments, without a prescribed second Compost cycle?
- Does deferring additional weapon schools and the broader Seal catalog leave an acceptable transition into an ordinary Run, with the same shared inspection and action-preview UI there?

Implementation and validation results are recorded in [validation.md](validation.md). The open questions above remain playtest questions, not progression requirements.
