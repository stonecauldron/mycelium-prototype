# September 16 influencer push — working plan

Prepared September 10, 2026. Proposal for discussion; no gameplay implementation or publishing has been performed.

## Objective and confirmed constraints

Primary campaign outcome: **wishlists for the full game on Steam**. September 16 is the day the game is sent to creators, not a promised date for live coverage. There are **five workdays** available. Give creators a game they can understand, enjoy, and show clearly; give their viewers an appealing Steam page and one obvious next action: wishlist Auto Shrooms.

Plan on four workdays of production and one protected day for validation, fixes, and delivery surprises. No outside art/audio help is assumed. Allocations below are scope caps, not completion estimates. Five workdays before September 16 requires one weekend workday if starting September 10. Choose September 12 or 13; preserve September 15 as the final check day.

Freeze features and art by the end of September 14. On September 16, send the tested game and creator kit. Coverage and wishlist attribution will follow creators' own schedules; do not judge the campaign only by September 16's results.
Success: a first-time player gets through the opening choices, first battle, Nursery unlock, and a useful training/growth decision without developer coaching. The game looks coherent in a small video window, sounds satisfying under commentary, and the delivery/wishlist links work.

## What the repository already tells us

- No audio files or AudioStream/AudioServer wiring found in the game assets searched. Budget for selecting sounds, playback, mixing, persistence, and controls.
- Pause/settings exists in Base and combat; current settings cover fullscreen, with no audio controls. The title has no settings entry. Add access to audio settings before a Run if title music is added.
- Wishlist buttons already exist on title, victory, and game over. Run/Day and wishlist/feedback intent analytics already exist. Verify these rather than rebuilding them. An intent event is a click, not a confirmed Steam wishlist.
- Existing contextual hints cover actions such as starting combat, planting, harvesting, and buying. Watch actual unfamiliar players before deciding how much extra explanation is needed.
- The stored Steam header capsule is a title over environment art, without the mushroom fighters. This is a clear opportunity to communicate the hook. The live Steam page could not be inspected here; local assets are not proof of what is published.
- There are 24 weapon resource files, while the current training resolver names 21 player weapon paths. Do not assume every file needs a redraw for this push.
- The five opening Adult weapons are Great Sword, Great Hammer, Sniper, Halberd, and Great Shield. These, then the five base school weapons, are the sensible art order.
- Local specs and galleries record recent combat, animation, and menu work. They are historical evidence, not a fresh validation of this build.

## Priority and bounded deliverables

### 1. Capsule and store first impression — 0.75 workday

Start the direction immediately. The store is the destination of the campaign, so its first impression is a core deliverable. Check that the short description and first visible media communicate the same hook as the capsule. Give viewers one primary call to action: wishlist the full game. Start especially early if another person will make the art. Choose one composition, finish one reusable master, and adapt it to the required store crops. Do not explore endlessly or redraw the whole environment.

Recommended composition: a small troop led by a prominent mushroom with an oversized, readable weapon; two contrasting roles behind it; plant enemies on the opposing edge. Keep the cave/forest as supporting atmosphere and retain an easily readable title. This communicates mushroom troop building and battle in one glance.

Other directions to compare in quick thumbnails:

- **Tiny army, huge attitude:** the troop is the hero; strongest immediate character appeal. Recommended.
- **Grow your next champion:** a Child/growing mushroom beside a trained Adult; stronger lifecycle message, less instantly combat focused.
- **Mushrooms versus the garden:** opposing silhouettes at a clash; strongest conflict, more risk of clutter at small sizes.

Done: chosen composition reads at small size; crops are deliberately composed; logo remains readable; files meet Steam dimensions. Preview the smallest generated capsule sizes, not just the large export. Current store sizes are Header 920×430, Small 462×174, Main 1232×706, and Vertical 748×896. Base capsule text is limited to game name and any official subtitle alongside artwork. Sources: [Steam store assets](https://partner.steamgames.com/doc/store/assets/standard), [asset rules](https://partner.steamgames.com/doc/store/assets/rules).

### 2. Complete a small audio pass — 1 workday

This assumes existing/licensable music and a small coherent sound palette, not commissioning a bespoke album in this window. Confirm permission for game distribution and creator videos/streams, and keep the source/license records with the assets.

- Music: one Base/menu loop, one battle loop, and short victory/defeat stings. Reuse a musical motif. If time slips, one good loop and the essential SFX is the fallback.
- Combat families: slash, blunt impact, projectile release/impact, shield block, death/spore release. Add signature explosion audio only if the core mix is ready.
- Management events: confirm/buy, invalid action, plant, harvest, training emerge, battle start/reward. Reuse sounds where the meaning is the same.
- Controls: independent Music and SFX volumes with mute and saved preferences; title access if music starts there. A separate complicated streamer mode is unnecessary if the music can be muted independently.
- Mix: small variations, limit simultaneous/repeated impacts, keep background music below foreground feedback. Music should not restart on every Base tab change.

Direction to try: **a tiny woodland war band** — plucked wood/strings, soft hand percussion, breathy reeds, an earthy bass pulse, and tactile little pops. Gentle curiosity in Base; mischievous momentum in battle. No vocals so the track leaves room for creator commentary. Alternatives: more eerie fungal ambience, or brighter toy-soldier percussion.

Done: intentional sound through a normal run; clear loop joins and scene transitions; settings persist; pause/resume works; 1×/2×/4× combat does not produce harsh impact spam; music playback remains natural during fast-forward and hitstop. Test on laptop speakers and headphones. If web is a campaign target, check playback after the first user gesture in the exported browser build.

### 3. Focus the art pass on recognition — 1 workday

Do a cohesion/readability pass, with a deliberately small redraw list. The cap is for a modest pass and integration, not 21 bespoke weapon illustrations.

Order:

1. Great Sword, Great Hammer, Sniper, Halberd, Great Shield: all opening packages get coherent, readable silhouettes.
2. Sword, Mace, Shield, Spear, Bow: core schools and training language match the starting weapons.
3. Essential icons: weapon schools, biomass, train, compost, scout/reroll, plant/harvest, Body/Cap mutation distinction. Improve repeated action/category recognition before committing to unique art for every Seal/Fertilizer.
4. Remaining combo weapons only within leftover time; shared palette/outline cleanup is cheaper than complete redesign.

Art language: chunky readable shapes, consistent dark outlines and light direction, shared grip/material treatment. Consider root-wrapped handles, seedpod blunt weapons, and shell/bark shields where they support the established world. Keep the weapon's fighting role obvious. Judge icons at their real UI size and battle weapons in motion, against the real background and at a small video viewing size.

Preserve weapon mount positions, mirroring, projectile origins, and collision behavior during asset replacement. New Body/Cap silhouettes, animation sets, and backgrounds are later work unless a very small replacement is already finished and validated.

Done: opening weapons match one another; school icons and held weapons agree; icons differ by shape as well as tint; no clipping/mounting regressions; readability survives reduced video size.

### 4. Test the opening and fix small friction — 0.25 workday

Run a short unfamiliar-player test early, before the week is spent on polish. The opening presents a Seal choice and a starter package before the first battle, so check whether players understand either decision. Ask them to say what they expect, then watch without explaining.

Proposed acceptance checks: understand the objective, select a starter, start battle, find the Nursery after its unlock, plant/harvest, and recognise why training changes their troop. Treat these as targets to validate, not existing measured results.

Use short contextual prompts at the moment an action becomes relevant. Prefer an actionable next step and a readable result preview over a new tutorial system. Candidate small wins: a clear Nursery-unlocked cue after Battle 1; explicit Training → weapon result; a harvest-ready cue; understandable reasons for rejected actions.

If the test reveals a crash, softlock, broken core action, or major misunderstanding, it takes priority over remaining optional art. Avoid changing the opening economy or game systems without evidence.

### 5. Store media and creator delivery — 1 workday

- Capture five current gameplay screenshots after the visible/audio pass. Steam requires at least five gameplay screenshots; use at least 1920×1080 and 16:9. Keep them representative of the delivered build. Source: [Steam store assets](https://partner.steamgames.com/doc/store/assets/standard).
- Record one short clip showing a satisfying decision and its combat consequence. Upgrade the existing trailer only if it no longer represents the build or the required capture is cheap; a full new trailer is outside the minimum scope.
- Prepare a compact creator kit: accurate one-sentence pitch, tested demo access, controls, approximate run length measured in the actual build, three mechanics worth showing, screenshots/logo, and a support contact.
- Suggested pitch: “Grow mushroom troops, combine weapon schools, and turn fallen champions into the next generation.” Adjust to the build actually delivered.
- Suggested moments: a second Training producing a combo weapon; a lineage spore becoming a new recruit; a dramatic elite battle. Do not add mechanics solely to manufacture a clip.
- Prepare a separate full-game Steam UTM link for each creator. Track actual Steam wishlist additions separately from game-side wishlist intent. Steam attributes eligible conversions within 72 hours and finalizes conversions four days after the visit. Source: [Steam UTM Analytics](https://partner.steamgames.com/doc/marketing/utm_analytics).

Verify public demo access and Steam approval status on September 10. If initial approval is still needed, the deadline has an external dependency: Valve says initial store review typically takes 3–5 business days and recommends allowing at least 7 business days. Already-approved games can be updated without repeating that review. Source: [Steam review process](https://partner.steamgames.com/doc/store/review_process). Do not assume the local Steam depot scripts establish current approval or visibility.

This plan prepares delivery; it does not authorize contacting creators or publishing builds.

### 6. Testing and contingency — protect 1 workday

Reserve this rather than allocating every available hour to production. Include playtests, export testing, fixes, and delivery surprises. Check the installed/downloaded build through the same route creators will use, not just the editor.

Release checks:

- First launch, New Run, opening choices, Battle 1, Nursery unlock, planting/harvest, training and a combo, normal/elite battle, victory and defeat/restart paths.
- Full run coverage plus targeted scenarios for end states that ordinary runs do not reach. Verify the five starting choices with focused checks.
- Music/SFX settings persist; pause/resume and 1×/2×/4× behave; leaving combat restores normal speed.
- No reproducible crash, softlock, or broken progression found in the tested paths.
- Wishlist/feedback links open the intended destination from the distributed build; the parent Steam app is 4963670 and the Demo SKU is 5112860.
- Platform coverage follows the actual outreach promise: prioritize Windows Steam if that is the target; verify macOS/web if offered. Do not expand supported platforms for this push.
- Capture/reference the final build identifier and keep the previous working build available for rollback.

## Five-workday schedule — finish September 15

- **Day 1 · Thu September 10:** spend the first quarter-day checking demo/store access and watching one cold opening; fix only small observed friction. Use the remaining three quarters to finish the capsule direction/master/crops and check the store's message. Lock the audio shortlist before finishing.
- **Day 2 · Fri September 11:** implement the bounded music/SFX pass, saved volume controls, and mix. Check pause, transitions, and 1×/2×/4×. Stop at essential coverage if the timebox gets tight.
- **Day 3 · September 12 or 13:** complete the starter-weapon and essential-icon pass. Extend to base school weapons only after the opening set is coherent.
- **Day 4 · Mon September 14:** capture current screenshots and a short clip; update store-media drafts and assemble the creator kit and per-creator links. Integrate small remaining fixes. Freeze features/art by end of day. Publishing and sending remain separate user actions.
- **Day 5 · Tue September 15:** test the exported/distributed candidate and actual access route, fix blockers, verify wishlist links and the full-game destination, and retain a rollback build. No feature expansion.
- **Wed September 16:** send the game to creators, handle access questions, and log replies/coverage dates. Give creators usable access and one clear wishlist destination for their audiences.

If a workday overruns, reduce remaining art breadth or optional media embellishment. Do not silently consume the final validation day. The 0.25-day opening allocation covers observation and small changes; a serious blocker displaces other production work.

## Brainstorm backlog — attractive but optional

- A short training-emerge flourish and sound: a strong before/after moment with limited scope.
- A distinct block spark/sound and a heavier blunt hit: help viewers understand combat interactions.
- A satisfying biomass reward count-up, if the existing presentation needs it.
- One signature Boom/lineage effect polished for recognition, provided that mutation is likely to appear in a normal playthrough.
- A tiny in-game help panel covering grow → train → fight → inherit, only if the existing prompts prove insufficient.
- Later: bespoke cap/body silhouettes for the full mutation set, unique icons for every offer, battle damage breakdowns, new enemies/schools/Seals, save/load, metaprogression, a rebuilt tutorial, and broad balance redesign.

These are options, not additional commitments. Choose one small celebration only after the audio, capsule, opening readability, and release checks are secure.

## Scope cuts and success measures

First cuts: additional combo-weapon redraws, unique icons for every offer, extra music tracks, and a rebuilt trailer. Preserve a readable capsule with the troop, core SFX plus music/controls, coherent opening weapons, working demo access, and the final validation day. A dedicated artist could extend the capsule/art work, but help is not assumed.

Use a single creator-facing kit with a campaign wishlist link; do not make Discord, feedback, and newsletter subscriptions compete with the Steam wishlist request. The existing in-game feedback route can remain useful for playtest reports.

Before outreach, record the full game's wishlist baseline and usual daily additions if available. After outreach, separate: creators contacted/replied/covered; tagged store visits and eligible wishlist conversions; overall wishlist additions. Game-side intent clicks and run/day progression help diagnose interest and playability but are not verified wishlist conversions. Review against actual publication dates, allowing Steam's reporting window; avoid inventing a wishlist target without audience size and baseline data.

## Source pointers

- `assets/base/starter_packages.gd`: the five opening packages.
- `assets/base/pupation/weapon_school.gd`: current school and combo resolver.
- `assets/autoload/settings_server.gd`, `.scratch/settings-menu/spec.md`: current settings and previous verification.
- `assets/ui/external_links.gd`, `docs/adr/0009-gameanalytics-event-map.md`: conversion links and telemetry contract.
- `steam/store assets/store_capsule_header_en.png`: inspected local capsule.
- `.scratch/mace-school/weapon-gallery.png`: inspected local weapon/mount gallery.

This is source and local-art review, not a fresh playtest or analytics analysis. Update priorities from the first cold playtest and creator feedback and actual coverage dates.
