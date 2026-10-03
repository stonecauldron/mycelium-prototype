# Exploring a less overwhelming opening

Status: the guided Run is implemented with a 10-Day schedule. Optional graphical arrows introduce newly unlocked functionality on its unlock Day and stop when the Run completes. Pacing and comprehension need playtesting. Learning comes from restricted options and scheduled feature unlocks. Add no onboarding text tooltips, hint panels, or Guidance button. Tutorial practice never gates advancement; the pending Day-8 Seal choice must be resolved before Battle, with Base management available meanwhile.

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
2. **Let the available options teach.** Keep later systems hidden and expose a small set of usable choices at each unlock. Optional graphical arrows point out newly unlocked functionality on its unlock Day. Add no onboarding text tooltips, hint panels, or Guidance button. Existing shared Unit/item inspection, action previews, and tooltips remain available throughout the Run.
3. **Make results readable.** When the player acts, highlight actual results: biomass earned, Remaining Time decreasing, or the same Child returning as an Adult. Keep the detailed recap available behind an expansion.

This follows the general principles of [progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/) and Microsoft's guidance on [clear objectives and interactive, replayable tutorials](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/109). They support the design approach; they do not establish which change will work best for this game.

A guided Run lasts 10 Days, introducing combat roles and Training before the Nursery, then Compost, lineage, broader management choices, and one Seal. Its ten authored enemy armies are preserved; guided Battle rewards fund the next Day’s introductions. Ordinary Runs retain their current 10-Day length and progression. Reuse the existing Base, combat, and action rules with a feature-unlock schedule. Playtests must cover both players who explore each system and players who skip or use systems later.

## Core rule: tutorial practice is optional; normal Run choices still apply

Feature availability follows the upcoming Day and the existing Battle-win progression. Training, Formation changes, purchases, planting, harvesting, Composting, and lineage use are all optional. A player can reach the final victory with unused features; completing a tutorial checklist is not a condition of Run completion. A pending Seal choice is an explicit exception: the player must choose a Seal before the next Battle, but can hide the chooser and inspect or manage the Base first. Any offered Seal satisfies that normal Run choice; no particular build or recommended option is required.

**Start Battle uses normal gameplay eligibility**, including having a Unit in the Squad and resolving any pending Seal choice. No tutorial flag may disable it because a recommended action is incomplete. No mandatory Next/Continue prompt, spotlight that blocks other controls, forced tab visit, or repeated nagging may substitute for that gate. Normal action rules, costs, confirmation dialogs for chosen actions, and Battle outcomes still apply.

The schedule below defines opportunities, not an expected sequence of clicks or a required roster. Later unlocks do not wait for earlier features to be used. Players learn by exploring the available schools, troop arrangement, plots, and offers. Arrows introduce only that Day's new functionality using actual state; skipped introductions do not replay later. Shared inspection and previews display the actual Unit or item.

Curated encounters should support multiple viable preparations. An unlocked tool can make a problem easier, but an encounter must not function as a disguised requirement to perform one exact tutorial action. In particular, Mace is a useful answer to Log rather than the only allowed answer. Validate alternate approaches and retain Battle retries and Change preparation.

## Requested milestones

- Learning is led by unlocks and hiding of features. Optional graphical arrows introduce newly unlocked functionality only on its unlock Day and stop after completion. Add no new onboarding text or required tutorial action.
- Players can restart Battles. Every failed Battle in a guided Run must offer **Restart Battle**, preserving the active Run and earlier completed Days.
- Use Bow as the proposed first Child Training, replacing Shield in the opening, to introduce melee versus ranged roles and a practical reason to change Formation.
- Introduce the daily progression bar before Battle 4.
- Introduce Mace Training before Battle 4. Battle 5 remains elite and includes a Log enemy.
- Unlock the Nursery after winning the Battle on Day 4, before Battle 5.
- Unlock Nursery and Quick Growth on Day 5; Squad expansion and Bench on Day 6; Shield Training and Thorny on Day 7; Compost and the second Plot on Day 8; Spear and the full Shop (including paid rerolls and offer locks) on Day 9. Guided Runs allow two total Plots. First fresh Common grows take two Days, with Quick Growth available to shorten the wait.
- Introduce the only Seal choice after winning Battle 7, before Battle 8, using the three introductory offers. Selection is required before Battle 8; hiding the chooser lets players inspect and manage the War Chamber and Nursery. Mark Day 8 with a graphical Seal icon and preserve the existing shared Seal inspection tooltip.
- Winning Battle 10 completes the guided Run and opens Victory directly, without a daily summary, with the subtitle **Try a real run now!**.
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

Introduce combat roles, Formation, Training, and the Nursery on Days 1–5; Squad expansion, Bench, Compost, lineage, and the full Shop on Days 6–9, with the only Seal choice on Day 8. Unlocked features stay available through the final Battle. Squad rearrangement is available from the start, and no optional action is required to demonstrate a skill.

Each weapon-school Cocoon keeps its fixed background socket throughout the Run. Reserve space for locked schools while hiding their Cocoons and controls, so the visible schools do not recenter between sockets as more unlock.

| Preparation | Feature availability | Available choices and possible result |
| --- | --- | --- |
| Before Battle 1 | Fixed starter and Battle preview | Supply a fixed Sword-trained Adult and a curated enemy army. Show the Squad, Next Battle without reroll, and Start Battle; keep later management features hidden. The player can rearrange the Squad. No starter or Seal choice blocks entry. |
| Before Battle 2 | Bow school and starter Child | Reveal the reserved Child and Bow Training. The existing Training preview shows ranged attacks, the 3 biomass cost, and the selected Unit's actual wait. Any eligible Unit can use the school; the player can also leave it unused. A Child trained now returns before Battle 3. |
| Before Battle 3 | Sword school; melee/ranged Formation choices | Make the familiar Sword school's Training option available. Players with melee and ranged Units can explore their positioning and observe the Battle. They may keep their positions, choose any legal Training, or start Battle immediately. |
| Before Battle 4 | Daily progression bar and Mace school | Show completed days, the Day-4 marker, and the Day-5 elite skull with its preview. Reveal Mace Training with the actual recipe for the selected Unit. Neither unlock depends on earlier Training or Formation choices. |
| Before Battle 5 | Nursery with one Plot; Quick Growth Shop offer; Log elite | Reveal Nursery planting/harvesting. A fresh Common grow takes two Days, including the first planting. Quick Growth can reduce its wait by one Day. These actions remain optional. Fight the first elite Log encounter. |
| Before Battle 6 | Squad expansion; Bench | Reveal Bench management and allow purchasing additional Squad slots at normal prices, regardless of Nursery use. |
| Before Battle 7 | Mutation offer and Shield school | Add the guaranteed Thorny offer and reveal Shield Training. Preview actual effects and valid targets without assuming the player has planted or harvested. |
| Before Battle 8 | Only Seal choice; Compost and second Plot purchase | Offer melee damage, ranged damage, or health. Hide the chooser to manage the Base before confirming any offer. Reveal Compost and purchase of a second Plot at ordinary prices. Adults can yield lineage spores; lineage grows retain their normal one-Day duration. Two total Plots is the guided cap. |
| Before Battle 9 | Spear school; full Shop | All weapon-school Cocoons are now available. Open all four Shop slots with normal Fertilizer/Mutation catalogs, paid rerolls, and offer locks. |
| Before Battle 10 | Final elite Battle | Add no new system or Seal choice. Winning the final elite Battle completes the guided Run, including when optional features were unused. |

Use the existing Unit names, portraits, and result presentations to connect real grow, Child, Cocoon, and Adult states. These reflect actual player choices and timing. A system used several Days after unlocking retains the same shared inspection and action-preview UI, without an arrow replaying its introduction.

### Daily summary unlock highlights

After a guided victory, highlight the systems newly available for the next preparation Day with their existing icons and short names under **Unlocked for Day N**. Derive these rows from the same school and feature availability rules used by the Base. For example, the Day-4 victory highlights Nursery and Quick Growth for Day 5; Day 5 highlights Squad expansion and Bench for Day 6; Day 7 highlights the Seal choice alongside Compost and Plot expansion for Day 8. The Squad expansion and Bench messages use only their labels, without icons or reserved icon space. These are result labels, without tutorial explanations, tooltips, or extra actions.

Place the unlock heading and icon/name rows directly on the summary paper above the biomass amount, with dark ink text and no separate background panel.

Omit the highlight on Days without new systems, failed Battles, and the final victory. Child arrivals, growth, and lineage results remain actual event rows rather than scheduled unlock claims. Consume the highlight with the existing summary feed so it cannot survive a retry or appear twice. Ordinary Runs retain their existing Nursery-unlocked message.

The Day-3 result highlights Mace and progression; Day 4 highlights Nursery and Quick Growth; Day 5 highlights Squad expansion and Bench; Day 6 highlights Shield and Thorny; Day 7 highlights Compost, Plot expansion, and Seals; Day 8 highlights Spear and Full Shop. Day 9 has no unlock highlight. Full Shop includes catalogs, rerolls, and locks. The final Day-10 victory skips the daily summary entirely.

Keep the result paper within the screen beside the combat recap. Long result lists scroll while the normal Continue action remains visible. The biomass total belongs to its result row and scrolls/clips with it after the gain animation finishes or is skipped; scrolling during the animation settles the total into that row.

### Optional graphical-arrow guidance

Use the existing floating-arrow presentation only to introduce newly unlocked functionality during that Day's preparation. Show one clear hint at a time, without text, a hint panel, a modal spotlight, or an additional acknowledgement control. The arrow ignores pointer input and never changes gameplay eligibility. Players may follow it, choose another action, or start Battle under the normal rules. No guided arrow appears after Run completion.

Resolve targets from current state instead of assuming a Day-specific roster, grow, or purchase. For a newly introduced drag interaction, point out the actual source and eligible destination in turn: a Unit and its School or Compost bin, or a Stock/Shop item and a suitable Plot. Preserve the normal drag/drop target feedback once a drag begins. Direct actions point at their actual control. Do not move Units, buy items, open confirmations, or apply changes on the player's behalf.

Follow the existing unlock schedule when choosing daily opportunities:

| Days | Graphical guidance opportunities |
| --- | --- |
| 1 | Start the first Battle. |
| 2 | Introduce Bow Training for an eligible Unit. |
| 3 | Introduce Sword Training for an eligible Unit. Dismiss the Day's guidance after the player successfully trains two distinct Units during Day 3; repeat Training of the same Unit counts once. This dismissal survives retries and resets with a new Run. |
| 4 | Point at the Day-5 elite skull until it is clicked or activated, then point directly at the Mace cocoon until one Unit successfully trains with Mace, without an intermediate source-Unit arrow. Hovering or elapsed time does not dismiss either destination arrow. |
| 5 | Introduce Nursery operations using actual Plot and Stock state, then Quick Growth for a compatible grow. |
| 6 | Introduce affordable Squad expansion when more room is needed. The Bench becomes visible the same Day. |
| 7 | Introduce Thorny for a compatible Plot. Shield guidance points only to a Unit from the latest Day-7 harvest that is still in the Troop and eligible for Shield Training, then to the Shield cocoon. Without such a harvest, show no Shield Unit arrow; never substitute a starter or older Unit. Hovering the Shield cocoon immediately dismisses Shield guidance, including its source-Unit arrow; no Training is required. |
| 8 | Introduce the only Seal choice while it is pending. After confirmation, point directly at the unlocked Compost bin without a source-Unit arrow, then introduce affordable second-Plot expansion. Hovering the Compost bin immediately dismisses its guidance; no Compost action is required. |
| 9 | Point directly at the unlocked Spear cocoon without a source-Unit arrow, then introduce compatible full-Shop offers and an available paid Shop reroll. Hovering the Spear cocoon immediately dismisses Spear guidance; no Training is required. |
| 10 | No new introduction or recurring guidance. |

These are priorities among optional opportunities, not required steps. Skip suggestions whose source is missing, whose action is already complete or unchanged, whose destination is unavailable, or whose cost is unaffordable. If an introductory purchase is already owned on its unlock Day, use the actual owned item where appropriate. Check the same action rules used by normal previews and execution; do not reserve biomass, clear a Plot, or grant a replacement item to make a hint possible. If nothing relevant is available, show no arrow.

Do not add recurring Battle, Formation, Scout, harvest, planting, or empty-Squad reminders. After Day-8 Compost, lineage planting remains available through normal Nursery controls without an arrow: planting was introduced with the Nursery. Skipped introductions do not replay later, and completion suppresses all guided arrows. Feature unlocks, daily summary highlights, and normal action eligibility continue independently.

When a target is on the other Base tab, point to that tab's actual button first. Wait for the player to choose it, then resolve the target in the newly shown screen. Never switch tabs automatically or point at an offscreen control. Hide arrows while the camera moves, a scene transition runs, the game is paused, a drag is active, an action dialog or Seal chooser is visible, or an item inspector/reveal obscures the target. Re-evaluate after that interaction ends so the arrow does not return to a freed, hidden, or obsolete control. Hiding a pending Seal chooser must still leave all ordinary Base management available; an arrow must not reopen it.

Keep only the presentation state needed to avoid repeated hints. Other inspection guidance can count as seen through hover/focus or a brief unobscured display. On Day 4, dismiss progression guidance on elite-skull activation and Mace guidance on one successful Mace Training; the Mace introduction goes directly to its cocoon without a source-Unit phase. Both actions remain optional for starting Battle. Advancing to a new Day leaves skipped hints behind. Reset this state for a new Run, keep it separate from unlocks and completion history, and do not rewind it when retrying a Battle or restoring preparation. A seen hint must never become a condition of progress.

### Bow, Formation, and early Training

Bow provides a visible contrast between melee and ranged roles. Reuse the shared Formation orientation markers so the player can connect the Base arrangement to Battle. Placement remains entirely under the player's control; no Formation arrow or required swap accompanies the Training introduction.

Use the existing slot swap interaction. Player combat Homes preserve War Chamber Squad slot order; slots nearer the Flag bearer are behind those farther forward. Returning Units enter the first free unlocked Squad slot. This may naturally put a newly trained Bow in front of the starter Sword. Do not require a swap, evaluate a mandatory correct answer, or rearrange Units for the player.

A small melee enemy army around Day 3 can make the contrast visible. Bow uses the existing skirmishing behavior and can retreat when enemies approach. Test both arrangements with the same enemies and Stats; the proposed advantage of rear placement needs to be observable under the actual combat rules. Neither placement is a tutorial failure. If the player has no Bow, the Battle and subsequent unlocks still proceed normally.

Day 4 makes Mace available in preparation for the Day-5 Log elite, providing an opportunity to discover a combo. Players may discover combos earlier by training an Adult in an available school; do not restrict Training to Children or block a legal combination to preserve an intended reveal. Show the actual Weapon and availability before confirmation. Oldest-Training replacement remains visible in the shared Training preview, regardless of Day.

### Day 4 progression bar

Reveal the existing `CombatProgressTrack` with an optional graphical arrow pointing specifically at the Day-5 elite skull and no text callout. Clicking or activating that skull dismisses the arrow and opens the normal elite preview; hover or elapsed time alone does not dismiss it. The skull preview must show the same authored Log army that will fight on Day 5. After the Day-5 elite victory, move the track to Days 6–10; Day 10 is the final elite. Keep Scout reroll hidden throughout the guided Run. Viewing, hovering, focusing, or clicking the track is never required to start a Battle.

Place a small graphical Seal icon beside or above the **Day on which the player receives the choice**, using the existing Seal artwork (`assets/base/seals/seal.png`). Keep the track itself graphical: no persistent “Seal after victory” caption or sentence. Preserve the day number, current-day marker, and elite skull. Place the guided Seal icon above Day 8, keeping the Day-10 elite skull and its enemy preview intact.

The guided Seal icon belongs only on **Day 8**. The choice becomes available after the Battle-7 victory and appears when Continue enters Day-8 preparation. Show its upcoming icon as soon as the Days 6–10 chapter appears; do not place it on Days 9 or 10.

Preserve the shared hover/focus Seal inspection tooltip and accessible names; add no onboarding explanation to the track. A subtle outline/filled/check treatment can distinguish upcoming, pending, and claimed choices without relying only on color. Keep the Seal symbol recognizable in every state. Pending choices also drive the Base's Hide / Select Seal button; hovering or focusing the track never claims a reward or becomes a requirement.

Use the same per-mode schedule for awarding choices and drawing icons. Ordinary Runs grant an opening Seal before Battle 1 and later choices before Battles 3, 6, and 9 (after victories 2, 5, and 8), so their icons belong on **Days 1, 3, 6, and 9**. Guided mode suppresses those picks and has only the Day-8 choice. Both modes end on Day 10; ordinary rewards are unchanged.

### The guided Seal on Day 8

Hide the player's Flag bearer in the War Chamber and combat until the first Seal is confirmed. Opening or hiding the pending chooser does not reveal it. Confirmation reveals it immediately; restoring preparation to before the choice hides it again. Keep the combat anchor and Formation behavior intact. Ordinary Runs retain their existing Flag bearer visibility.

Create the only guided Seal opportunity once when the Day-7 victory advances the Run to Day-8 preparation. The chooser appears after Continue returns from the Day-7 victory summary; a failed Battle 7 creates no choice. Show the existing chooser once on arrival, with its normal Seal descriptions. The player must confirm an offered Seal before Battle 8, but may hide the chooser for as long as they want while preparing. Hiding is not rejecting the reward or choosing a default; the same opportunity remains pending.

There is no second guided Seal choice or full-pool unlock. No skipped ordinary rewards are granted retroactively, and final victory does not create a post-Run choice.

Ordinary Runs retain their opening choice and completed Days 2 / 5 / 8 rewards. Keep choice identity separate from chooser visibility so the guided Day-8 opportunity is granted once even across tab changes, retry, or restored preparation.

Use the existing bottom Battle-action position for this state-dependent control:

| State | Main button | Behavior |
| --- | --- | --- |
| Pending choice, chooser visible | **Hide** | Hide the chooser and its dimming/input layer; keep the Seal choice pending. Escape performs the same action. |
| Pending choice, chooser hidden | **Select Seal** | Reopen the same offers and preserve any highlighted card. Available from both the War Chamber and Nursery. |
| No pending choice | **Start Battle** | Start combat when normal Squad requirements are met. Confirming a Seal restores this label; it does not launch combat automatically. |

Keep the Hide button reachable above the chooser's overlay. While hidden, show the full Base normally: tab buttons and shortcuts, Unit inspection, Formation, Training, planting, harvesting, and other unlocked management actions remain usable under their normal rules. Restore the same tab and camera position when hiding; reopening the chooser does not force a trip to the War Chamber. Hide and Select Seal remain enabled even when the Squad currently cannot fight. The chooser retains a separate **Confirm Seal** action for the highlighted card; selecting or highlighting a card alone does not apply its effect.

Preserve the same offers, highlighted choice, and any ordinary-run reroll count/cost across hide/show and tab changes. Hiding is never a free reroll, cancellation, or confirmation. Base edits remain in place, and any state-dependent Seal information refreshes when reopened. Tab changes, HUD refreshes, and other dialogs must not automatically reopen a chooser the player hid. Separate the pending reward from whether its chooser is visible. Apply this inspect-and-return interaction to ordinary Seal choices too, respecting which Base areas are unlocked in that mode.

For the guided choice, offer **Wooden Sword** (+2 melee damage), **Wooden Bow** (+2 ranged damage), and **Wooden Heart** (+8 health), regardless of earlier Training, Nursery, or Mutation choices. Keep these three introductory offers unchanged through hide/show and retry restoration. Seal reroll remains unavailable in guided mode. Show the confirmed Seal among the Run's active bonuses and use its ordinary effect; replaying the same Battle must not apply the choice twice.

Reuse the shared `pending_seal_choice` combat rule and chooser interaction: hiding leaves the pending flag intact and suppresses automatic reopening, and the Base button selects Hide / Select Seal / Start Battle from actual state. Guard every combat-entry path so none starts Battle with a pending choice. Suppress the ordinary opening and post-Day-2/5/8 picks in guided mode; create only the introductory choice before Battle 8. Do not reuse `can_start_combat()` to disable Hide or Select Seal; their availability is independent of combat eligibility.

Include scheduled-choice identity, offers, highlighted choice, visibility, claimed state, owned Seals, and their effects in retry snapshots. On Day 8, capture preparation after creating the pending opportunity and before selection. Restart Battle retains the pre-combat Seal exactly once. Change preparation undoes that claim and restores the same pending choice. No retry may duplicate a reward, generate new offers, or allow combat while the restored choice is pending.

The existing Shop, Compost, and Plot expansion remain available while the Day-8 chooser is hidden. The full Shop unlocks on Day 9. No Compost action or Nursery visit is required to confirm the Seal.

Relevant sources: [Seal schedule and application](../../assets/autoload/game_state.gd), [Base action button and combat gate](../../assets/base/base.gd), [chooser creation and reopen behavior](../../assets/base/troop_selection/troop_selection_screen.gd), [Seal chooser](../../assets/base/seals/seal_choice_dialog.gd), and [progression track](../../assets/base/combat_progress_track/combat_progress_track.gd).

### Day 4 Mace and Day 5 Log

Log's authored profile resists slashing damage, while blunt damage bypasses that protection. Mace therefore offers a useful new answer. If the selected Adult still has `[Sword]`, adding Mace produces `[Sword, Mace]`, a Warhammer, instantly with Stats unchanged. If its Trainings differ, show its real recipe instead. The Bow and the original Sword's unchanged loadout are possible states, not prerequisites.

Use the existing Log data and combat rules. A single Log has an Army cost of 24, below the normal Day-5 budget range of 82–111. This guided encounter is an explicit authored-content exception to procedural budget generation in ADR-0015. Keep it marked elite and use the same cached formation for the skull, Scout, and Battle. Use the guided allowance for the next preparation Day as its Battle reward, and preview that same amount.

Tune the encounter through playtests with multiple preparations, including viable approaches that do not use Mace. The Log should make blunt damage attractive without making one prescribed Training a hidden advancement requirement. No scripted defeat or automatic tutorial equipment change is permitted. Failed Battles offer the existing planned restart choices.

### Nursery availability, offers, and capacity

After the fourth victory, the Nursery tab becomes available. Its appearance and an optional Day-5 graphical arrow expose the new choice without a text prompt. Entering it, planting, and harvesting are optional. Later Days do not repeat Nursery-operation arrows. Its scheduled Shop and Mutation unlocks happen on time even if the player has never visited the tab.

Offer Quick Growth from Day 5 and Thorny from Day 7, guaranteeing these introductory offers through Day 8. On Day 9, open the normal four-slot Shop and full Fertilizer/Mutation catalogs with paid rerolls and offer locks. Generate the daily roll once, preserve locked offers during rerolls, and keep purchases empty through UI refreshes and retries. Quick Growth and Thorny remain eligible in the normal pools, but are no longer guaranteed. Purchasing an item may retire its graphical suggestion, but never unlocks another category or advances the Day. Support direct Shop-to-Plot use and the existing Stock route. Stock appears whenever it contains an item, including an earlier lineage spore from a fallen Adult; hiding future features must not hide possessions the player already has. Before the Nursery opens, a Stock button in the War Chamber exposes existing spore inspection in a read-only popup. It does not permit planting, selling, or dragging items, and does not unlock the Nursery early.

Use real timing and application rules in previews. Every fresh Common grow in a guided Run normally takes two Days, including the first planting. Ordinary Runs retain their first-grow reduction to one Day; lineage spores retain their authored duration. Quick Growth changes Remaining Time, not Growth Time, following ADR-0007: it reduces the first grow to one Day, or can turn a grow with one Day remaining READY immediately. Thorny can be applied to an empty or growing Plot; a READY Plot retains its normal restrictions.

Squad slot purchases and Bench management become available on Day 6; clicks and drops require both the unlock and a visible Bench. Hidden Bench slots reject drops, while Squad rearrangement remains available. The second Plot purchase appears with Compost on Day 8. Shield is available from Day 7 and Spear from Day 9. After buying the second Plot, hide and reject further Plot purchases without spending biomass. Ordinary Runs retain four total Plots and immediate Bench management.

Use ordinary costs, spending, and affordability. Do not reserve biomass for a required tutorial purchase, force a refund, or prevent legal spending to reserve a later purchase. The player can postpone a purchase or use Change preparation to revisit the current Day's choices. Balance should provide meaningful opportunities to try available tools without assuming every offer is bought.

The guided catalog introduces Bow on Day 2, Sword on Day 3, Mace on Day 4, Nursery/Quick Growth on Day 5, Squad expansion/Bench on Day 6, Thorny/Shield on Day 7, Compost/Plot expansion and the only Seal on Day 8, and Spear/full Shop on Day 9. Scout and Seal rerolls remain hidden. The pending Seal choice follows the explicit selection requirement above.

### Guided biomass allowances

Use the actual normal action prices to grant each preparation Day’s introduction cost plus 30%, rounded up to whole biomass. Grant the **full allowance in addition to savings**, never a balance top-up or reset. Compost and other earned biomass remain additional income. Funding does not require taking the recommended actions or visiting a tab.

| Preparation Day | Funded actions | Action cost | Grant |
| --- | --- | ---: | ---: |
| 1 | Formation and Battle preview (free) | 0 | 0 |
| 2 | One Bow Training | 3 | 4 |
| 3 | Two Trainings | 6 | 8 |
| 4 | One Mace Training; progression inspection is free | 3 | 4 |
| 5 | Fresh planting and Quick Growth | 6 | 8 |
| 6 | One Squad slot; Bench is free | 8 | 11 |
| 7 | Shield Training and Thorny | 7 | 10 |
| 8 | Second Plot; Seal choice, Compost, and lineage planting are free | 8 | 11 |
| 9 | Spear Training, one Fertilizer, one Mutation, and one Shop reroll; offer locking is free | 11 | 15 |
| 10 | No new introductory purchases | 0 | 0 |

The scheduled grants total 71 biomass for 52 biomass of introductory purchases. Day 1 starts with its allowance (zero). Each victory grants the next preparation Day’s allowance through the existing Battle reward and daily summary. Battle 9 grants zero because Day 10 has no new introductory purchases, and final Battle 10 grants zero because there is no next preparation Day. Scout previews use the same per-mode reward calculation as combat, including future-Day previews. Restarts and restored preparation never regrant allowances; debug Day advancement follows the guided reward schedule. Ordinary starting biomass and difficulty-based rewards are unchanged.


### Compost and lineage

Compost becomes available before Battle 8. Its preview explains Unit removal, actual biomass payout, and the resulting lineage spore. Only Adults produce lineage spores; the Child preview shows no spore. Composting is optional, cancellable, and never a condition of final victory.

If a spore is produced, show the named item in Stock with the existing item inspection UI. Planting consumes that spore through the existing path, without charging the fresh-grow price again. Lineage Growth Time is normally one day. No planting deadline is imposed; no Plot is cleared or extra spore granted to keep a scripted schedule on track.

The existing hatch result and Unit/item inspection expose the actual inheritance when a lineage Child is harvested:

- Same lineage name, with Generation increased by one.
- The parent's current Trainings, including ones learned as an Adult, determine its Weapon immediately.
- The parent's Mutations carry through the spore onto the Child.
- It starts as a Child, with Stats rolled around the parent's saved Stats. Generation and Tier are distinct, and the next Generation is not an automatic power increase.

Fertilizer items do not carry onto spores, although baked Stat gains may influence the descendant through the parent's saved Stats. Keep that detail available in the preview without requiring the player to read it.

Training a descendant is optional and follows the normal Child rules. If it inherited two Trainings, a new one replaces the oldest; show that result before confirmation. Training the oldest school again can preserve the two-school combination while rotating its order. Use the actual Generation-scaled Stat changes and wait. A player may field the Child, bench it, train it later, or continue with the existing troop.

Mutation inheritance is visible in any relevant Compost preview as soon as the player has a mutated Adult. A second Compost is never requested as a prerequisite. If the player has no mutated Adult or chooses to keep it, there is no missing tutorial objective.

An Adult lost in a won Battle can also produce a lineage spore before Compost unlocks. Show the actual item when it appears and provide access to its Stock inspection. Before the Nursery unlocks, that spore stays available for later planting. Do not manufacture a combat death or treat a spore from death as a reason to demand Composting. Restarting a failed attempt restores the parent and removes that attempt's spore together.

Use the normal Compost eligibility rules; an occupied Plot is not an extra tutorial prohibition on Composting. Show material inventory consequences in the action preview when Stock is full instead of silently clearing the player's items to enforce a scripted sequence. Keep the game and action-feedback rules authoritative.

### Examples of possible timing, not required routes

These examples verify that the unlocked systems can produce visible results within the Run. Shared previews and result presentations use the player's actual dates and state; no example is an expected tutorial route.

| Optional choice | Result under the existing timing rules |
| --- | --- |
| Train the starter Child in Bow before Battle 2 | Bow Adult available before Battle 3. |
| First planting before Battle 5 without Quick Growth; harvest and train before Battle 7 | New Adult available before Battle 8. |
| First planting plus Quick Growth before Battle 5; harvest and train before Battle 6 | New Adult available before Battle 7. |
| Plant and mutate a normal two-day grow before Battle 8; use Quick Growth at one day remaining before Battle 9; harvest and train | Mutated Adult available before Battle 10. |
| Compost an Adult and plant its spore before Battle 8; harvest and train before Battle 9 | Descendant Adult available before Battle 10. |
| Plant a fresh grow and apply Thorny before Battle 7; apply Quick Growth and harvest/train before Battle 8; Compost the resulting Adult and plant its spore before Battle 9 | Mutated lineage Child can be harvested before Battle 10; it may fight the final encounter as a Child. |

Skipping or delaying any row is valid. The Run still unlocks later features and ends on its normal victory condition.

### Guided Run length and final progression

Day 10 is the guided Run victory. After the battle celebration, open Victory directly with the subtitle exactly **Try a real run now!**, without a daily summary or Continue step. Record completion and uncheck the next-Run preference when Victory opens, including on replays. Do not enter another preparation phase, offer another Seal, or show another progression chapter.

Both modes last 10 Days. Guided mode retains its Run-specific length and the existing first ten authored encounters; shortening the schedule does not retune those armies. Day labels, progression, Scout and elite previews, combat victory checks, reward lookup, and analytics use the same completion boundary. Ordinary Run content and completion stay unchanged. Authored guided armies remain the exception described in ADR-0015; inheritance follows ADR-0003.

Relevant sources: [lineage decision](../../docs/adr/0003-lineage-spores-from-adults.md), [spore snapshot](../../assets/base/nursery/spore_data.gd), [harvest and Stock](../../assets/base/nursery/nursery_data.gd), and [Compost preview](../../assets/base/pupation/compost_confirm_dialog.gd).

## Restarting Battles

Every guided Battle defeat, including elite Battles on Days 5 and 10, shows **Restart Battle** as the primary action. Restarting is free and remains available after repeated failures. The defeat does not advance the Day, end the Run, mark onboarding complete, or uncheck the guided-run preference.

In guided mode, offer two clearly named actions:

- **Restart Battle** restores the snapshot taken immediately before combat and restarts with the same preparation and enemy army. Make it available from the paused Battle menu and after defeat.
- **Change preparation** restores the start of the same Day's preparation phase and returns to the Base, so the player can choose different Trainings, purchases, or Formation. Offer it alongside Restart Battle after a defeat, without additional explanatory text.

Both actions preserve the Run and completed earlier Days. Restore Unit health and life state, troop/Cocoons, biomass, grows, Stock, Shop offers, Seal opportunities and owned bonuses, day counters, and unlock state from the relevant checkpoint. Keep the authored enemy army and its rolled instance Stats stable. Capture these through one Run snapshot mechanism, with checkpoints at preparation start and combat launch, rather than trying to reverse individual combat effects.

Rewards, deaths, lineage spores, Seal bonuses, grow ticks, and day advancement from the discarded attempt must not accumulate. A victory after retry awards the Day once. Clear stale recap/launch data and reset combat engine timing before restarting or returning to the Base. Do not reroll Shop or Seal offers or enemies on retry. Guided attempts and retries do not emit gameplay analytics.

Victorious summaries on Days 1–9 show only the normal Continue button. They have no Restart Battle, Change preparation, End Run, or preparation-reset explanation. Continue returns to Base. Winning Day 10 skips the daily summary and opens Victory directly; a Day-10 defeat still offers the guided retry options.

A defeat initially opens the retry choices; it does not automatically end the guided Run. The player can explicitly choose **End Run**. A first loss should lead to an opportunity to change a decision without replaying earlier Days.

## Choosing a guided Run

Place a separate checkbox immediately to the right of the **New Run** button, vertically centered in the same row:

`[New Run]  ☑ Guided run`

The checkbox toggles the mode without starting a Run. The New Run button starts the selected mode. Keep it separately focusable and give the entire checkbox label a usable click target. Use the same selector at every New Run entry point, including victory and game-over screens.

- First launch: checked by default; the player can uncheck it immediately.
- Store an explicit user choice so returning to the menu does not repeatedly undo it.
- On the first guided Run's terminal end, automatically set the next-Run preference to unchecked. Terminal end means reaching the final Victory screen or an explicit End Run/Return to title; a retryable Battle defeat or a non-final victory summary awaiting Continue is not a terminal end. Closing the app unexpectedly does not mark the learning sequence completed.
- The player can check the option again for another guided Run. Every completed guided Run unchecks it again. A deliberate selection made afterward remains selected until another guided completion; revisiting a menu must not reset it.
- Store guided completion/first-end history separately from the next-Run preference and from the active Run's mode. An early end can clear the default without claiming final victory. Winning Day 10 completes the guided Run regardless of optional feature use.
- Starting an ordinary Run uses the existing starter/Seal flow and progression. Starting a guided Run seeds the curated troop and content directly.

Store the active Run mode and day-based unlock schedule separately from the saved next-Run preference and first guided-end history. Feature availability never depends on action-completion flags. Minimal per-Run arrow/inspection state controls presentation only; it is separate from gameplay checkpoints and does not affect Run completion or saved mode preferences.

## Other remedies worth testing

| Observed difficulty | Candidate remedy |
| --- | --- |
| “I don't know what to do next.” | Smaller sets of available options, optional arrows on introductory unlock Days, shared graphical readiness indicators, and a clearer primary action. |
| “I can't judge these choices.” | Fixed opening content, smaller offer sets, and teaching a consequence before asking for an irreversible strategic choice. |
| “There is too much to read.” | Put the next decision's essential facts on the card; move formulas and advanced detail into an expandable view. Test readability at actual play size. |
| “I don't know why I lost.” | Review battle readability and recap usefulness. A longer management tutorial may leave this problem intact. Show factual outcomes; avoid claiming a counterfactual cause the game has not evaluated. |
| “I understood it, then forgot.” | Consistent shared inspection and action previews, plus access to replay the guided Run. |

## Unlock and interaction behavior

- Unlock features on the scheduled Day, independently of earlier tutorial practice. Keep them available afterward; no required Training, purchase, placement, harvest, or Compost action advances the schedule. A pending Seal must be chosen before Battle, but never prevents inspecting or managing the Base, or delays other features scheduled for the same preparation phase.
- Reuse normal authoritative action checks and feedback. Failed drops and unaffordable actions do not consume items or produce success feedback. Successful actions use the existing result feedback and never grant permission to progress.
- Add no onboarding text tooltips, hint panels, or Guidance button. Coordinate optional guided arrows through one presentation sequence, limited to that Day's new functionality and stopped after completion. Keep older independent coaching arrows suppressed throughout guided Runs, including Days without a guided arrow. Preserve shared gameplay inspection/tooltips, drag/drop target feedback, and normal confirmation dialogs.
- Shared previews and result feedback reflect actual Units, grows, and successful events. Delayed use needs no forced catch-up actions, replacement items, or prescribed roster.
- Let players opt out when starting a New Run and explicitly end a guided Run to choose another mode. Replaying remains available through the New Run checkbox. Keep victory history, the next-Run preference, and active mode separate.
- Keep underlying costs and waits recognizable. Curated offers, troop composition, and enemy armies are teaching content; altered economy and timing would need separate justification.
- Check loss, Return to title, New Run, screen changes, alternate input paths, and debug behavior when implementing. Guided availability must not leak into ordinary Runs.

## How to judge the experiment

Observe a small group of new players with the current opening and another with the candidate opening. Keep the facilitator from rescuing them immediately. Record where they hesitate and what they think each action will do.

Useful measures are time to first Battle, requests for help, abandoned openings, mistaken predictions about Training, and overload ratings after Days 4, 5, 7, 8, 9, and 10. Observe understanding when players actually encounter a system: melee versus ranged positioning, the selected Unit's Training result and wait, Quick Growth's effect, a Seal's Run-wide bonus, or what a descendant inherits. Ask about an actual choice rather than requiring a specific build or grow on a specific Day. These are playtest observations, never in-game advancement tests. Record voluntary use and delayed use separately from whether players noticed an unlock; skipping a feature is not itself a comprehension failure. Also measure fatigue, drop-off, and whether players choose an ordinary Run after the 10-Day guided Run.

First-Battle completion alone is insufficient; removing decisions can improve that measure without improving understanding or enjoyment. Watch whether players find the available choices sufficient, whether they can proceed using the available controls, and whether they understand outcomes by observing their choices.

Exclude guided Runs from ordinary Run/Day progression, combat, retry, resource, and in-run intent analytics. Record only a guided Run start and a terminal event with the reached Day and whether the player quit or completed it. A non-final result awaiting Continue still belongs to its Battle's Day; accepting Continue moves to the next Day. Final Day-10 victory goes directly to the Victory screen and records completion once. End Run, Return to title, and application quit record one terminal exit. A retryable defeat does not end analytics tracking. Ordinary analytics remain unchanged. Comprehension and voluntary feature use are assessed through observed playtests rather than new guided gameplay events.

Before release, verify the schedule and divergent player choices:

- No new onboarding text tooltips, hint panels, or Guidance button appear. Skip Bow Training and Formation changes, then win: the progression bar still appears before Battle 4, Mace before Battle 4, and the Nursery after the Day-4 victory. No tutorial action gates normal controls.
- Follow and ignore arrows on the scheduled introductory Days through Day 10. Check actual source/destination targets, missing Units, completed or unchanged Training, purchased offers, occupied/READY Plots, and insufficient biomass. No arrow points at an unavailable action or changes normal eligibility. Verify skipped introductions never replay on a later Day.
- Verify there are no arrows after completion or recurring reminders for previously introduced actions. Day 5 introduces Quick Growth after planting; Day 8 introduces the Seal, Compost, and Plot expansion; Day 9 introduces Spear/full Shop; Day 10 adds no new introduction. Legacy coaching remains suppressed.
- On Day 4, the progression arrow targets the elite skull and retires on its activation; the Mace arrow retires after one successful Mace Training, even if that Training happened before inspecting the skull. Hover/time, other schools, failed Training, or non-elite clicks do not complete these introductions. Other-tab hints point at the correct visible tab button and wait for a voluntary tab change. Modal dialogs, the Seal chooser, Stock inspection, active drags, pause, reveals, and camera/scene transitions hide the arrow; dismissal restores only a still-relevant target. Retried Battles do not reset seen inspection hints.
- Training an Adult or discovering a combo before Day 5 remains legal within the available schools. Every preview shows the actual result, including oldest-Training replacement and actual wait.
- Never visit the Nursery: Shop and Mutation offers still become available on Days 7 and 8. A READY grow, an unused offer, or a benched Unit never blocks an otherwise eligible Battle.
- Squad expansion rejects purchases before Day 6, Bench management before Day 6, and Plot expansion before Day 8. Purchases use normal prices; guided Plots cap at two. Shield appears alongside Thorny on Day 7, and Spear completes the schools on Day 9.
- Day 9 fills all four Shop slots from the normal catalogs. Paid rerolls retain locked offers; refreshes and retries preserve purchases, rolled items, prices, and locks. Day 8 offers the three introductory Seals without Seal reroll.
- Verify the optional timing examples. A first fresh grow planted before Battle 8 is READY before Battle 10 without Quick Growth, or before Battle 9 with Quick Growth. A Day-5 first planting follows the same two-Day duration. Ordinary first planting still takes one Day, and lineage spores retain normal timing.
- An Adult lost during a won Battle before Day 4 leaves a visible Stock button during the next preparation. The existing spore tooltip works in its read-only popup; dragging and planting remain unavailable until the Nursery opens. The owned item remains unchanged.
- A lineage path consumes the chosen Stock spore once, uses its real Growth Time, preserves inherited Trainings and Mutations, and previews any Training replacement correctly. Compost preview and execution agree on payout and removal. Keeping every Adult and never growing a descendant remains valid through final victory.
- The optional Bow trained before Battle 2 returns before Battle 3. A Squad-slot swap changes its actual combat spawn position. Compare front and rear arrangements with matched Stats/enemies to assess visibility despite skirmishing; neither arrangement gates progress.
- If an Adult still has only Sword Training, adding Mace produces Warhammer instantly without increasing Stats. Validate the authored Log across expected Stat variation and viable preparations without Mace; no exact recipe is required to advance.
- The Days 6–10 track shows a graphical Seal icon only on receiving Day 8, with the existing shared inspection tooltip and accessibility label. Preserve its elite skull, enemy preview, day number, and current-day marker without overlap.
- No Seal is available before winning Battle 7, or on defeat. Accepting that victory creates one pending choice before Battle 8. No early rewards are backfilled and no additional reward queues on Days 9 or 10 or after final victory.
- The pending chooser opens once on entering Day-8 preparation. Hide and Escape expose the Base; Select Seal reopens the same offers and highlighted card from either tab. Tab changes, HUD refreshes, and other action dialogs do not force it open again or reroll its contents.
- While the chooser is hidden, inspect and manage Units, Training, Formation, Nursery grows, Stock, and unlocked offers. Changes persist after reopening. Hide / Select Seal work with an empty Squad; Start Battle returns after Seal confirmation and follows normal Squad eligibility. Confirmation never launches combat automatically.
- Every combat-entry path respects the pending choice. No Battle starts before a Seal is confirmed, but the existing Shop, Compost, Plot expansion, and all legal Base actions remain available during Day-8 preparation. Confirming any offered Seal resolves the choice without a specific tutorial build or prior Nursery action.
- On Day 8, the confirmed Seal survives Restart Battle exactly once. Change preparation undoes its claim and restores the same pending offers. Verify each of the three choices and switching choices after restoring preparation; retry must not duplicate a Seal or its effects.
- Ordinary Seal icons appear on receiving Days 1, 3, 6, and 9; the guided icon appears only on Day 8. Their schedules match actual choice availability, and ordinary pick timing remains unchanged. Hide/show preserves offers and any ordinary paid reroll state, and still requires a choice before Battle.
- Guided victory at Day 10 skips the daily summary and opens Victory directly with the subtitle exactly “Try a real run now!”, records completion, and unchecks the next-Run preference without an additional click. No further preparation, Seal, or progression chapter appears. Unused optional features do not block completion, and ordinary completion remains unchanged.
- Repeating either retry action restores its checkpoint without duplicate biomass, spore drops, Seal effects, progression, or time ticks. Include retries from paused combat and defeat, returning to preparation after instant Training or Composting, and choices that skipped available features. Restore a removed parent and its spore consistently.
- Lose a regular guided Battle and each guided elite Battle, then lose the retry: Restart Battle remains available and preserves the active guided Run and its preference each time.
- Ordinary Runs still unlock the Nursery after Day 1. Scheduled feature hiding in guided mode applies consistently to UI and shortcuts; once revealed, features require only their normal gameplay eligibility.
- The guided option defaults on, respects an immediate opt-out, switches off after the first terminal guided end and every guided victory, survives app restart, and allows a deliberate later guided replay. Its label is exactly “Guided run”.

## Open questions

- Which part of Training causes the most confusion: starting it, selecting a school, timing, Stat gains, combos, or replacement?
- Are players confused by controls, vocabulary, choices, or battle causality?
- Does Bow positioning produce a clear enough combat difference, and does making Mace available on Day 4 give players room to explore basic roles without restricting earlier combos?
- Does Day 5 leave enough room to explore planting and Quick Growth alongside the first elite Battle? Observe late and skipped use as well.
- Is Thorny's combat effect easy enough to notice to serve as the first Mutation, or does it need clearer hit feedback?
- Does introducing the Seal alongside Compost and Plot expansion on Day 8 leave enough room for an informed choice? Does hiding the chooser help players inspect their troop without losing their place?
- Can players understand inheritance through the preview and their chosen lineage experiments, without a prescribed second Compost cycle?
- Do all Cocoons and the full Shop on Day 9 prepare players for an ordinary Run without overwhelming them?

Implementation and validation results are recorded in [validation.md](validation.md). The open questions above remain playtest questions, not progression requirements.
