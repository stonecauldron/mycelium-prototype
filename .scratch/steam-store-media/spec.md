# Steam store media refresh

Status: Produced and validated on September 20, 2026. Final package: `steam/store assets/2026-09-20-store-refresh/`. Steamworks publishing remains outside scope.

## Requested outcome

Refresh the Auto Shrooms Steam store page with current gameplay media:

- A fast-paced 30-second trailer with frequent cuts and transitions, ending with the game logo and a wishlist call to action.
- Description GIFs showing planting and harvesting, Training, changing the Squad's arrangement, and large-scale Battles.
- Fresh screenshots replacing the outdated gameplay captures.

## Verified starting point

- The September 10 asset refresh reused the existing gameplay screenshots, resized to 1920 × 1080; it did not capture the current game. See [asset README](../../steam/store%20assets/2026-09-10/README.md).
- The project glossary defines Spore, Plot, Child, Training, Cocoon, Weapon school, Troop, Squad, and Battle. Use those concepts accurately in the brief and capture directions.
- Existing trailer: `steam/store assets/videos/Auto Shrooms trailer.mp4`, 17.03 seconds, 1920 × 1080 at approximately 59.94 fps.
- Current transparent wordmark: `steam/store assets/2026-09-10/upload/library/library_logo_transparent_en.png`.
- Growth and Training resolve on Day advances. Their short clips need an intelligible time jump between input and result.
- Changing the Squad's arrangement means moving/swapping Units among Squad slots and the Bench before Battle; it is not live tactical control.
- There are ten Squad slots and four Bench positions. Normal Battles allow up to ten simultaneously living player Units, excluding the Flag bearer. Zombie revival replaces a casualty; inspected effects do not summon additional Units. Enemy numbers depend on the Day's Army budget and chosen types. Establish representative late-Run captures before promising a battle headcount.
- Godot, FFmpeg, FFprobe, ImageMagick, OBS, and iMovie are available locally. A reusable media-production pipeline has not been found.
- The game has screenshot capture, debug setup aids, music, and SFX. Use prepared attainable states and the existing Battle music/SFX as confirmed below.

## Steam constraints checked September 20, 2026

- Target the full [Auto Shrooms Steam App, 4963670](https://store.steampowered.com/app/4963670/Auto_Shrooms/); the Demo is a separate listing.
- Trailer guidance favors immediate, understandable gameplay, including with sound off. H.264/AAC in MP4 at 1080p and 30 or 60 fps is a supported delivery choice. A custom poster must be an actual trailer frame. Steam automatically samples the first visible trailer to create its microtrailer. [Trailer documentation](https://partner.steamgames.com/doc/store/trailer)
- Supply at least five genuine gameplay screenshots at 1920 × 1080 or higher, 16:9. Screenshot marketing text and concept art do not qualify. [Screenshot documentation](https://partner.steamgames.com/doc/store/assets/standard#screenshots)
- Description animations support GIF, MP4, and WebM, among other formats, and last at most 12 seconds. Steam recommends 1170px width and BT.709 metadata for videos. This package delivers MP4 loops and GIF counterparts. [Extra asset documentation](https://partner.steamgames.com/doc/store/page/assets)
- Description guidance asks for images under 5 MB and recommends keeping combined screenshots/GIFs below 15 MB for loading performance. Native headings and separate text support localization; fake Steam buttons and external-link graphics are disallowed. [Description documentation](https://partner.steamgames.com/doc/store/page/description)

These facts constrain the later production choices; they do not settle the creative questions.

## Design tree

- Main promise → trailer hook, narrative order, emphasis among features.
- Tone → music, cutting rhythm, transition style, text treatment.
- Delivery boundary → package contents, store-description placement, Steamworks work.
- Deadline and spending constraints → production method, audio sourcing, scope.
- Verified gameplay and capture capabilities → representative game states, permissible staging, handling Day advances, meaning of large-scale Battles.
- Verified Steam requirements → trailer format, GIF exports, screenshot set.
- Resolved creative and capture decisions → concrete shot list and acceptance criteria → shared-understanding confirmation.

## Confirmed direction

1. Main promise: grow your mushroom force, opening with big chaotic Battles to hook viewers.
2. Tone: playful and punchy.
3. Delivery: finished media package, editable sources, and GIF placement guide. Steamworks editing and publishing are outside this package.
4. Constraints: no deadline or reference trailer; no spending.
5. Trailer structure and editing: use the six-part timeline below, music-timed cuts, selected impact zooms/match cuts, legible key actions, short GROW/TRAIN/FIGHT overlays, and no voiceover.
6. Capture setup: prepare attainable Run states, then film actual gameplay with debug UI hidden and intelligible growth/Training time jumps.
7. Description media: four 6–10-second loops (Plant & Harvest, Train & Combine Weapons, Arrange Your Squad, Battle), delivered as MP4 plus optimized GIF versions, headings outside images.
8. Screenshots: six fresh shots, using the existing screenshots as the base. Mirror their subjects/compositions in the current game; the confirmed mapping and sixth subject appear below.
9. Audio: existing Battle music edited for the ending, with game SFX emphasizing actions.
10. Supporting English text: headings, one or two sentences per action, and alt text ready to paste into Steamworks.
11. Editable sources: raw captures, audio, logo, timestamped cut list, and a reproducible FFmpeg editing script.
12. Unit variety: aim for approximately 33% Children and 67% Adults in featured player Squads, with visible Mutations on some Units.
13. Combat Formations: order player Units by their actual Range class, with shield-bearing frontline Units ahead of other Melee Units, then Mid and Ranged behind them.
14. Featured weapons: include at least one player Unit with a Great Sword and at least one with a Great Horn, with both clearly visible in the finished footage.
15. Range-class balance: aim for an even split of Melee, Mid, and Ranged Units in featured player Squads, using the nearest practical whole-Unit counts, with at least one frontline Melee shield wielder in each featured combat Squad.
16. Exclude Mortar-equipped Units from all delivered footage and screenshots, including Squad, Bench, and Training previews. Recapture older takes containing a Spore Mortar.

## Unit casting and Formation requirements

Apply these requirements to trailer footage, description loops, and the refreshed screenshots wherever the player Squad is shown.

- Aim for one-third Children: three Children and seven Adults for a full ten-Unit capture Squad, or three Children and six Adults for a nine-Unit Squad. For smaller Squads, use the nearest practical equivalent (for example, two Children and four Adults). This is a starting-lineup composition target, not a percentage of trailer duration or a ratio to maintain after casualties. Individual harvest and Training close-ups can naturally feature one life stage.
- Give both life stages readable screen time and vary weapon identities across the footage. Retain Children in the featured combat lineups instead of showing them only in Nursery shots.
- Include a Great Sword wielder and a Great Horn wielder in the featured player capture roster. Give each a readable action beat in the finished trailer, rather than only including it in unused raw takes. Reuse these takes for the Battle loop where they read clearly. Great Sword is Melee; Great Horn is Mid (its resource directory is named `giant_horn`). Enemy-held weapons do not satisfy these player-Unit requirements.
- Balance the starting Squad across the three Range classes: three Melee, three Mid, and three Ranged for nine Units; four Melee, three Mid, and three Ranged for a full ten-Unit Squad. Include at least one frontline Melee shield wielder in every featured combat Squad. Count frontline Melee shields within Melee, not as a fourth class, and keep the Great Sword/Great Horn within their respective class totals. Shield combos retain their actual weapon's Range class. For other Squad sizes, aim for class counts differing by no more than one. Apply this alongside the one-third-Children target; casualties may change both proportions during combat.
- Include a visible mix of mutated and unmutated Units, with mutated Children and Adults across the package. Show more than one Mutation identity, drawing from Body and Cap Mutations; select the exact mix during capture for visual clarity and attainability. Include a readable Mutation effect in combat as well as the appearance differences.
- Order the starting Formation from the enemy-facing front to the rear: shield-bearing Melee Units → other Melee Units → Mid Units → Ranged Units. Classify every Unit by its actual weapon's Range class, including Children and combo weapons. For example, Spear and Shield belongs with Mid Units despite its shield.
- Preserve this ordering when launching every captured Battle. The Formation loop should end with a correctly ordered Squad; swaps within a Range class or suitable Bench exchanges can demonstrate rearrangement. Let combat movement, charges, knockback, and casualties proceed normally after launch.

Capture setup reference: Squad slot indices increase from the Flag bearer toward the enemy, so ascending slot order is Ranged → Mid → Melee, with frontline shields in the highest occupied Melee slots. See [starter ordering](../../assets/base/starter_packages.gd), [weapon Range classes](../../assets/units/weapon_data.gd), and [combat Homes](../../assets/units/unit.gd). These are media staging requirements, not a change to the game's Formation rules.

## Trailer: confirmed timeline

| Time | Content | Purpose |
| --- | --- | --- |
| 0–4s | Immediate chaotic Battle action; multiple distinct impacts and shots. | Establish spectacle before explanation. |
| 4–9s | Plant a Spore, show growth across a Day jump, harvest a Child. | Show where the fighting force comes from; GROW overlay. |
| 9–14s | Place a Unit in a weapon-school Cocoon, cut across the Training wait, reveal an Adult/combo weapon. | Make Training's input and result visible; TRAIN overlay. |
| 14–17s | Rearrange the Formation with a clear swap. | Show the player's positioning choice. |
| 17–27s | Escalating Battle montage with varied weapons, projectiles, and effects. | Pay off the preparation; FIGHT overlay. |
| 27–30s | Current capsule, “Fungus Vult!”, Steam logo, and “Wishlist on Steam” in Fredoka. | Readable end card with music landing on the reveal. |

Use frequent cuts and a few purposeful transitions. Key interactions need readable input/result holds; rapid battle inserts carry the pace. Retain gameplay UI where it explains the action. Trailer should communicate the loop when muted.

## Description loops: confirmed coverage

| Loop | Capture sequence | Key clarity requirement |
| --- | --- | --- |
| Plant & Harvest | Plant on a Plot → edited growth interval → ready Plot → harvest. | Distinguish growth over Days from immediate feedback. |
| Train & Combine Weapons | Unit enters a weapon-school Cocoon → edited Day advance → emergence with new fighting identity. | Show an attainable additional Training/Combo weapon; avoid implying free Weapon swapping. |
| Arrange Your Squad | A visible Squad-slot swap and/or Bench exchange, followed by a brief view of the result. | Show pre-Battle Formation changes. |
| Battle | A crowded attainable late-Run fight with readable melee and projectile action. | Show actual current combat scale and effects. |

Loops last 6–10 seconds each and remain below Steam's 12-second limit. Keep headings outside the images. Deliver MP4 and GIF versions of each, with concise English copy and alt text in the placement guide.

## Description copy

Place each heading and paragraph immediately above its corresponding loop. Refine alt text against the actual final capture.

### Grow your fighting force

Plant spores, nurture your plots, and harvest new mushroom recruits. Shape each grow with Fertilizers and Mutations to prepare your next fighters.

Alt text: A Spore is planted in the Nursery; after a passage of Days, the ready Plot is harvested to produce a Child.

### Train and combine

Send your mushrooms through weapon schools to develop their fighting style. Train an Adult in a second school to unlock a combo weapon.

Alt text: An Adult enters a weapon-school Cocoon and emerges after Training with a combo weapon.

### Arrange your squad

Choose who joins the fight and who waits on the Bench. Rearrange your Squad before Battle to put your plan into action.

Alt text: Units swap Squad positions and move between the Squad and Bench in the War Chamber.

### Let the chaos begin

Watch your mushroom Squad clash with enemy armies in automatic Battles. Bring your weapons, Mutations, and Formation together against tougher opponents.

Alt text: Mushroom Units exchange melee attacks and projectiles with an enemy army during a crowded Battle.

## Screenshot plan: based on the existing set

Use `steam/store assets/screenshots/1.png` through `5.png` as visual references. Capture every replacement from the current game, retaining useful UI and the original shot's purpose.

| Reference | New capture |
| --- | --- |
| 1 — Battle approach | Mixed Child/Adult Squad (roughly 33% Children), visible Mutations, and Flag bearer on the left/center; enemy army to the right. Show clear silhouettes and the ordered Formation. |
| 2 — Developed War Chamber | Mixed Squad, Bench, Cocoons, and open Scout preview. Reflect the current five weapon schools and separate Composting bin. |
| 3 — Nursery | Stock, Shop offers, and four Plots at varied growth/ready states. Show current Fertilizer and Mutation presentation. |
| 4 — Active Battle | Crowded combat with airborne projectiles and visible impacts; distinctly different from the approach shot. |
| 5 — Day summary | Troop performance, Battle reward, Training emergence, and growth progress on a legitimate later Day. |
| New sixth — Training detail | An Adult's second-school Training confirmation/preview, displaying the resulting Combo weapon with War Chamber context. |

The old summary combines first-Battle Nursery unlock with a ready grow. Mirror its progression theme using a valid current Run state. Put the strongest active-Battle shot first in the delivered gallery, then the other five; preserve original-to-new mappings in the guide.

## Production defaults

- Record the captured build's Git revision and any local changes in the package README so future refreshes can identify outdated footage.
- Prepare real, normally attainable Run states. Hide setup/debug controls before capture and preserve normal gameplay rules, timing, and effects. Use clear Day-change edits for growth and Training.
- Capture at 1920 × 1080, aiming for smooth 60 fps. Export the exactly 30-second trailer as H.264/AAC MP4 at 1080p60, with a high-quality source master and a poster frame selected from actual footage.
- Export description MP4s around 1170px wide, with BT.709 metadata. Optimize GIF counterparts for useful color, readability, frame rate, and file size; retain high-quality source clips. Aim for images below 5 MB each and a lightweight combined store payload.
- Keep screenshot PNG masters and provide six optimized, full-resolution store-ready images with no added marketing text.
- Reuse the existing transparent logo, Battle music, and game SFX. English action overlays and plain “Wishlist on Steam” text; no narration.
- Save the finished bundle under a new dated folder within `steam/store assets/`, retaining the prior media as references.
- Include the four short description sections, alt text, original-to-new screenshot mapping, recommended gallery order, and upload placement guide.

## Acceptance criteria

- Trailer measures 30 seconds, follows the approved time blocks, shows clear gameplay immediately, and ends with a readable three-second logo/CTA.
- The muted trailer still communicates growth, Training, Formation changes, and Battle. Music and SFX do not clip or end abruptly.
- Four distinct loops show their actions and outcomes, each lasting 6–10 seconds. Each has MP4 and GIF delivery files and a clean loop boundary.
- Six genuinely new screenshots match the agreed subjects, current visuals, and attainable mechanics, at 1920 × 1080 or higher.
- Featured capture Squads begin with approximately 33% Children, include visible Mutation variety, and give both Children and Adults readable coverage. Review combat clips against the prepared roster; casualties need not preserve the starting ratio.
- The finished trailer clearly features at least one player Great Sword wielder and one player Great Horn wielder in action. Check the selected shots, not merely the source-roster inventory.
- Delivered footage and screenshots contain no Mortar-equipped Units, including Bench and Training-preview Units.
- Featured combat Squads start with approximately equal Melee/Mid/Ranged counts: 3/3/3 for nine Units or 4/3/3 for ten, with at least one frontline Melee shield wielder. Frontline Melee shields count toward Melee; Great Horn counts as Mid; shield combos use their actual Range class.
- Every captured Battle begins with the player Formation ordered by actual Range class, frontline shields ahead of other Melee Units, Mid behind Melee, and Ranged at the rear. The Formation loop ends in that order.
- No visible debug controls, desktop chrome, cursor accidents, stale UI, or synthetic gameplay. Interaction cursors remain when they help explain actions.
- Watch the complete trailer and loops and inspect all screenshots at full size and at store display size. Verify file dimensions, duration, codecs, frame pacing, and audio playback before handoff.
- Raw sources and the agreed editing materials make future shot replacement practical. The local package includes everything needed for upload; Steamworks publishing is outside scope.

## Planning outcome

Questions 1–12 are resolved. The user confirmed the brief and later authorized production, adding the casting, Range-class, featured-weapon, and Mortar-exclusion requirements above.

## Production result

- [Package README](../../steam/store%20assets/2026-09-20-store-refresh/README.md), [store copy](../../steam/store%20assets/2026-09-20-store-refresh/STORE-COPY.md), and [cut list](../../steam/store%20assets/2026-09-20-store-refresh/CUT-LIST.md).
- Exactly 30 seconds / 1800 frames, 1080p60 H.264/AAC trailer; 25 source shots, five chapter transitions, and the final logo/wishlist card.
- Four MP4/GIF loop pairs: 7.4, 8.0, 7.8, and 8.0 seconds. MP4s are 1170px wide; GIFs use reduced resolution and frame rate for size. The battle loop has a wide crop that retains army coverage while removing HUD/empty margins.
- Six new 1080p screenshots, each supplied as JPG and PNG.
- Three Children / seven Adults; 4 Melee / 3 Mid / 3 Ranged; Great Sword, Great Horn, a frontline Great Shield, and visible Mutations. A real Boom Cap explosion appears at approximately 22.5 seconds. Mortar was replaced with Bow in the capture roster.
- Twelve recorded roster checks passed. All five MP4s decoded completely; formats, timing, and screenshot dimensions passed validation. Combined JPG screenshot/GIF payload is approximately 10.9 MB. Trailer audio measured −16.0 LUFS and −3.0 dBFS true peak.
- Raw takes, action/roster manifests, graphics, audio, fonts, and executable capture/edit/validation scripts are retained. No gameplay source changes, commits, or Steam uploads were made by this production.

## Documentation

The root glossary now defines Formation as the Squad's pre-Battle arrangement. No ADR was created: these media-production choices are reversible and do not establish a costly architectural commitment.

## Production revision requested after review

- Replace compressed sources with lossless RGB MOV captures and lossless editing intermediates; increase capture detail to native 1440p60.
- Use cream paper UI backgrounds and dark ink for higher-contrast action/Day captions. Place them near the bottom left, clear of gameplay controls.
- Change the end-card tagline to **Fungus Vult!**
- Show the current main capsule, an official Steam logo near the wishlist CTA, and Fredoka for the CTA.
- Rebuild trailer and description loops from the new sources, preserving the approved duration, sequence, casting, formations, and Mortar exclusion.

Revision 2 delivered: seven verified lossless 1440p60 source MOVs, lossless editing MOVs and trailer master; all requested caption and end-card updates applied. Trailer and four loop pairs rebuilt and validated.

## Revision 3 — longer ending

The user requested a longer end card so the music can settle. The card now runs from 27–32 seconds, extending the total trailer to 32 seconds / 1920 frames. Music fades smoothly from 29.0–31.8 seconds with a 0.2-second quiet tail. This supersedes the original 30-second runtime and three-second end card; the approved gameplay sequence and other deliverables remain unchanged.

## Revision 4 — gardening steps and lineage

Requested additions: expand the Plant & Harvest description loop to show Fertilizer and Mutation application on a growing Plot, with Plant → Fertilize → Mutate → Harvest step headings; add a separate lineage loop showing an Adult’s death, its spores, planting, harvesting, and the descendant’s updated name suffix. Deliver both as MP4 and GIF, retaining lossless sources and editable cuts. The expanded package has five loops.

Revision 4 delivered and validated: two 10-second action sequences, including real Fertilizer/Mutation drags and a continuous captured Lamarck → lineage spore → Lamarck II chain. All five loop pairs, updated English copy/alt text, source footage, editing script, and packaged exports are retained in the dated media folder.

## Revision 5 — dedicated lineage encounter

The user requested a dedicated battle with a single Sword Unit dying, permitting higher Range classes behind it. Use one Sword Adult with two Bow supporters (one Child, one Adult); this explicitly replaces the earlier crowded Great Shield death for the lineage loop and overrides the main Squad’s role-balance/shield requirements for this dedicated scene. Keep the real death → emitted spore → planting → harvest → name-suffix progression.

Revision 5 delivered and validated: one Sword Adult ahead of two Bow Units, facing a normal Day 2 enemy composition. The real death emits the recorded spore; the same spore is planted and harvested as Sword-wielding Lamarck II. Lossless source, MP4/GIF, edit recipe, store copy, and package are updated.

## Revision 6 — integrate the new loops into the trailer

The user requested both new loops in the trailer. The edit integrates eight-second versions of Plant → Fertilize → Mutate → Harvest and the dedicated Sword Adult → actual spores → Lamarck II sequence. The chosen runtime is 40 seconds so the additions remain readable without dropping Training, Formation changes, the battle-first opening, or the five-second end card. Source holds are shortened at normal playback speed; all Day jumps stay labeled.

Timeline: 0–4s battle hook; 4–12s gardening; 12–17s Training; 17–19s Formation; 19–24s battle; 24–32s Sword lineage; 32–35s combat finale; 35–40s capsule, “Fungus Vult!”, Steam logo and Fredoka wishlist CTA. The original Battle music fades from 37.0–39.8s, followed by the retained 0.2-second quiet tail. This supersedes the prior 32-second runtime. The independent ten-second loops remain available unchanged.

Editable recipes, renderer, cut list, upload guide and package now target the expanded trailer. The prior 32-second export and lossless master are archived locally for comparison. Validation checks the trailer source ranges against the capture event manifests so the fertilizer/mutation applications and complete lineage chain are present in the finished edit.

Revision 6 delivered and validated: 40-second / 2400-frame 1080p60 trailer, updated lossless master, readable cut list and upload ZIP. Both new action chains are confirmed in the final timeline against recorded events. Final-export framing, captions, suffix reveal and end card were reviewed; audio is −16.33 LUFS / −0.99 dBFS true peak with a silent tail.

## Revision 7 — restore original trailer pacing

The user rejected the expanded gardening and lineage sequences inside the trailer because they slow it down. Restore the original 32-second trailer, including the original quick grow sequence at 4–9s and the five-second end card at 27–32s. Keep the two new ten-second loops as standalone store-description assets. This supersedes revision 6's 40-second trailer.

The original verified MP4 and lossless master are restored directly from the archive. The editable chapter recipe, cut list, validation checks, source intermediates and upload guide again target the 32-second cut; the superseded 40-second version is archived locally.

Revision 7 delivered and validated: original 32-second / 1920-frame trailer and lossless master restored byte-for-byte, original grow footage confirmed, source intermediates synchronized, and delivery package updated. All five standalone MP4/GIF loops remain available.

## Portrait social trailer

The user requested an additional portrait reel and verification against official format requirements. Produce a separate 9:16, 1080×1920 / 60 fps, 32-second MP4 from the lossless sources. Preserve the quick original grow sequence, battle-first hook, soundtrack timing, five-second end card, and exclusion of the two extended loops. Reframe individual shots and compose a portrait capsule/tagline/Steam CTA card with room for social controls.

Official requirements were researched September 20, 2026 from Meta's own Reels publishing sample, TikTok's In-Feed specifications, and YouTube Help's Shorts eligibility and upload encoding guidance. Technical scope and the distinction between publishing requirements and advertising recommendations are recorded in `SOCIAL-REEL.md`. Retain editable framing, a lossless portrait master, a cover image, validation, and a separate social ZIP. Leave the landscape trailer unchanged.

Portrait version delivered: 1080×1920 / 60 fps, 32-second picture edit, 24.38 MB social MP4; portrait cover and lossless master; official-source guide, editable framing/render script, validation and separate ZIP. Final framing was reviewed at phone size; original landscape outputs are unchanged.


## Revision 8 — Sword Child Training and landscape end-card background

Requested: replace Training with a Child holding a Sword, train toward a Great Sword, and cut immediately after confirmation without showing emergence. Apply the new sequence to both trailers and the standalone MP4/GIF. Give the landscape end card the same blurred background as the portrait version.

Production: Franklin II is prepared through real lineage inheritance, recorded at native 1440p60 in lossless RGB. UI drag opens the Sword Training comparison; assertions verify Child / Sword, Great Sword preview, confirmation into Sword Cocoon, no Day advance, and no emergence. The standalone loop is 6.5 seconds. Both trailers retain 32-second pacing and replace only the 9–14s Training chapter; the landscape also rebuilds its 27–32s end card with the shared blur/dimming recipe. Portrait retains its layout and copies the revised landscape PCM soundtrack. Previous sources and affected deliverables are archived.

Training screenshot follow-up: replace screenshot 06 with the Child → Adult / Sword → Great Sword preview from frame 270 (4.5 seconds) of the new lossless Training take. Preserve the full gameplay frame and comparison dialog. Update native PNG, 1080p JPG/PNG delivery pair, contact sheet, editable screenshot source mapping, and Steam upload archive.

Store description headers: deliver five 1170×150 PNG images in the supplied order and wording — Grow your units; Fight chlorophyll heathens; Pupate & Train; Arrange your troop; Create powerful lineages. Match existing cream paper ribbons and Spicy Rice font. Provide exact-text JSON recipe, renderer, desktop/mobile previews, header ZIP, and refreshed Steam upload package and placement copy.

Header wording revision: replace the combat heading with the exact singular wording “No mercy for the chlorophyll heathen”. Fit it on one line in the existing 1170×150 paper ribbon, retaining the other four header designs. Refresh the header PNG, previews, placement guide, and both download archives.

Combat header final wording: “Fight the heathen”. Restore the shared 84-point title size; update PNG, previews, copy, and both download archives.
