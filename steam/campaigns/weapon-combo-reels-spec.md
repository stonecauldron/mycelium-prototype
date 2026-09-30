# Auto Shrooms: Weapon Combo Reels

Reusable production spec for the "Weapon combos" series. Follow this when
creating a new reel or revising an existing one. The goal is a repeatable,
low-effort format: change the recipe and combat setup, not the visual identity
or story structure. Produce only the reels requested; exporting is not posting.

Reference: [Spore Mortar pilot](2026-09-28-combo-reels/README.md), with the v7
picture and latest v9 sound mix. This spec governs future reels; the pilot's
version history documents earlier experiments, not alternative requirements.

## Shared Script

One combo per reel. Target 20 seconds, portrait 1080x1920, 60 fps. Times below
are picture-relative; audio synchronization must account for container offsets.

| Time | Shot and action | On-screen information |
| --- | --- | --- |
| 0-0.35 s | Establish a Child beside the open Cocoon, holding the first recipe weapon. | Large "Auto Shrooms", subtitle "Weapon combos", centered `A + B = ?` using weapon-school icons and labels. |
| 0.35-0.85 s | Child walks briskly into the Cocoon; it closes. | Keep the mystery equation visible. The Cocoon carries the second school's icon. |
| 0.85-2.5 s | Build anticipation: shell shakes, compresses, and brightens; forest briefly dims. | Preserve the question mark until emergence. |
| 2.5-4 s | Shell splits, sparks release, and the Adult emerges with the combo weapon. | Replace `?` with the real combo weapon icon and its authored display name beneath it. Hold the complete, labeled equation. |
| 4-9 s | Single-unit demonstration: one equipped player unit versus three enemies, both sides in the same shot. Show the actual attack and its consequence. | Replace the equation with the weapon's authored display name. |
| 9-11.3 s | Final battle, player-side shot: nine player units all using this combo weapon versus 18 enemies. Show the attack beginning. | Weapon name remains. |
| 11.3-13.5 s | Hard cut to the enemy side receiving the attack. | Show visible impacts, knockback, blocking, or the relevant real mechanic. |
| 13.5-15.5 s | Hard cut to a wider shot with both sides visible, with room for their continuing movement. | Keep the weapon name until 14 s, then restore the mystery equation with cycling inputs. |
| 14-20 s | The equation's two input slots keep cycling like a slot machine, across the battle fade and through the end. | Keep "Auto Shrooms" and the unchanged "Weapon combos" subtitle above `A + B = ?`. |
| 15.5-17 s | Fade the combat scene to black while its simulation continues normally. | Branding and the cycling equation stay fully visible; do not fade the entire composite. |
| 17.15-17.55 s | After the combat area is black, animate the closing question into that area with a short fade and small upward settle. | "Which combo next?", separate from the subtitle and equation. |
| 17.55-20 s | Hold the question over the black combat area while both input slots keep cycling. | Leave the viewer's choice open. "Wishlist on Steam" is optional per reel, not required on this end card. |

For melee weapons, "attack beginning" means approach, charge, wind-up, or swing,
not a projectile volley. For defensive weapons, choose enemies that visibly
exercise the defense. Keep the same player-side / enemy-side / wide sequence.
Tune setup and spacing to fit these beats first. If a weapon genuinely requires
a timing exception, record it and obtain review instead of silently changing
the series format or game behavior.

## Closing Prompt

- At 14 seconds, hide the featured weapon name and restore the centered equation
  on its Paper UI backing. Keep "Auto Shrooms" and the "Weapon combos" subtitle
  in their existing positions; the closing question must not replace the subtitle.
- Show `A + B = ?`. Rapidly cycle both left-hand input slots through the actual
  weapon-school icons, like two slot-machine reels. Keep `+`, `=`, and the result
  `?` stationary and visible throughout; never reveal an output weapon here.
- Throughout 14-20 seconds, change each input about 5-8 times per second with short
  vertical rolls or crisp swaps. Stagger the slots so they do not always change
  together. Clip motion inside fixed-size input slots: the paper, equation
  spacing, and surrounding layout must not shake, flash, or resize.
- Cycle through valid in-game recipe pairs, including duplicate-school recipes.
  Validate intermediate pairs too. If school labels are visible, update each
  label with its icon so no mismatched name appears. Use a repeatable sequence.
- Keep both inputs cycling right through the end, with `?` unchanged. Do not
  slow down, settle on, hold, or highlight a final pair: the viewers are being
  asked to suggest what they want next, not shown a selection already made.
  After its entrance, keep "Which combo next?" stationary and readable. No winner,
  promised next episode, random gameplay reward, or result/jackpot reveal.
- Keep the final wide battle moving and both sides in frame until it fades out.
  Fade only the combat world and its effects from 15.5 to 17 seconds, reaching
  full black in the combat section. Keep the equation, its paper, branding, and
  any enabled Steam CTA unaffected by this fade.
- Once the combat section is fully black, introduce "Which combo next?" there
  from 17.15 to 17.55 seconds with a brief opacity fade and small upward settle.
  Use a large, high-contrast treatment and then hold it steady through 20 seconds.
  Keep it clear of the equation and any enabled Steam CTA. The end card extends
  the old 16-second format to 20 seconds without retiming the reveal or battle cuts.
- Fade battle sound effects with the combat scene. Let the music continue under
  the cycling equation and question, with a short fade at the end. Do not add a
  spoken question, casino-style win sound, or extra sound for the prompt entrance.
  The visual cycling supplies the slot-machine feel.

## Covers

- Every cover/thumbnail keeps the mystery equation `A + B = ?`, with the two
  input-school icons visible and the question mark in the result slot. Its job
  is to invite playback, not reveal the answer.
- Keep "Auto Shrooms" and "Weapon combos" prominent and the equation centered.
  Do not show the combo weapon's name, result icon, or equipped Adult on the cover.
- Export a clear pre-reveal frame with the Child or closed Cocoon; the pilot
  uses 0.2 seconds. Check the actual frame rather than trusting the timestamp
  if a future reel's timing changes. Keep the equation readable at thumbnail size.
- The cover uses the featured recipe, not a random pair from the closing cycle.
  During playback, show the complete equation with its labeled result at emergence,
  then the standalone weapon name, and return to a mystery equation only for the
  Closing Prompt.

## Presentation Rules

- Reuse the pilot's fonts, title hierarchy, and optional CTA styling, with the
  positioning and equation-contrast adjustments below. Keep text sizes and
  horizontal centering unchanged. The title must be prominent, not a small logo
  in a corner.
- At 1080x1920, move "Auto Shrooms" and "Weapon combos" down 40 pixels together
  relative to the pilot: title box top y=215, subtitle box top y=350. Preserve
  their spacing and apply the same placement to covers. When the Steam CTA is
  included, move its container up 40 pixels to y=1470. Leave gameplay framing
  unchanged.
  These positions supersede the older pilot exports and capture-script defaults.
- Make "Wishlist on Steam" a per-reel option. Omit it entirely when requested
  without removing the closing question; do not leave a visible empty CTA panel.
  Its omission in one reel does not remove it from the whole series.
- Center the entire equation, including symbols and the result slot, at x=540.
  Keep equal visual spacing; the full result must remain centered too.
- Place one light Paper UI backing behind the entire equation, including both
  school labels, symbols, and the result slot. Preferred texture:
  [paper 12.png](</Users/cauldron/Git/mycelium-prototype/assets/asset_packs/Cila - Paper UI stylized/Paper style 1/paper 12.png>)
  (1220x380). An aspect-preserving `TextureRect` with explicit linear filtering
  can downsample this strip into the equation area without stretching its torn
  edges. Set `EXPAND_IGNORE_SIZE` before assigning the texture, then set its
  target dimensions; verify its actual rectangle so Godot's texture minimum
  size cannot silently enlarge the backing. Use a suitably margined
  `StyleBoxTexture` or `NinePatchRect` only when a
  different aspect ratio requires it; a matching high-resolution Paper UI panel
  is acceptable. This is a background layer, not a separate banner beneath the
  equation or individual cards behind each icon.
- The paper must not look pixelated at export size. Check its source resolution
  against the rendered dimensions, explicitly use smooth/linear filtering, and
  preserve edge detail with aspect-preserving scaling or correct nine-slice
  margins. Do not magnify a tiny texture or use nearest-neighbor filtering for
  this backing. The earlier 384x80 `title 3 10.png` stretched a small center region
  heavily in this layout and is not the default anymore. Inspect the encoded
  equation at 100% as well as phone size.
- Give the equation comfortable interior padding, including space for the
  result-icon pop animation and the result's authored display name. Keep the
  paper's silhouette below the subtitle with a clear gap and above the Cocoon
  action; the equation group may shift slightly downward to accommodate it.
  Keep the centered layout and icon sizes.
- On the light paper, use dark ink for school labels, the result's authored name,
  `+`, `=`, and `?`, with restrained outlines or shadows as needed. Preserve the
  weapon icons' colors.
  The paper should clearly separate the recipe from the moving forest, not be
  so translucent that background detail competes with it. Check at phone size.
- Use the same equation backing on covers, the opening mystery/complete equation,
  and the Closing Prompt. Covers still show `?`; swap only the result slot on
  emergence without resizing the paper. Show the result's name directly beneath
  its icon during the complete equation; wrap long names within that slot without
  overlap or shifting the equation. Remove the backing with the equation when
  the standalone weapon name appears at 4 seconds; restore it for the closing cycle.
- Use the featured weapon's actual recipe, icons, name, appearance, and Training
  resolver in the introduction and demonstrations. Only the Closing Prompt
  cycles other candidate recipes. Duplicate-school recipes still show both
  inputs, such as `Mace + Mace = ?`.
- The entering unit is a Child visibly holding A, not the finished combo weapon.
  The emergence is a staged visual summary of Training, not a random reward:
  use a satisfying loot-reveal feeling without implying a random weapon result.
- Keep entry brisk: 0.5 seconds of walking, with the pilot's 2.1x walk animation.
  Reuse the split shell, warm flash, sparks, 240-pixel hop, brief apex hold,
  and landing at 3.1 seconds. The shadow stays on the floor. Keep the weapon legible.
- Preserve authored Child/Adult proportions and unit transforms. Frame with the
  camera; never resize individual units to fit or slide armies for a new angle.
  Shell and UI-icon animation may scale; unit bodies may not.
- The final nine-player army may mix Adults and Children when requested or when
  that age mix is deliberately featured. All nine still use the featured combo
  weapon. Give Children the game-valid inherited Trainings needed to resolve it;
  do not substitute shrunken Adults or bypass weapon resolution. For example,
  the Great Sword revision uses six Adults and three Children, not nine Adults
  plus extra Children. This exact age split is not required for every reel.
- Use fixed camera shots with hard cuts. The final shot is zoomed out relative
  to the closer shots. Forest scenery must scale with the world camera too.
  Only overlays and the introductory forest may remain screen-fixed.
- Hide gameplay HUD, menus, flag bearer, kill callouts, and battle dialogue.
  Keep visible copy to branding, recipe, weapon name, "Which combo next?", and
  the optional Steam CTA: no "Wait for it" or explanatory captions. Keep text
  clear of units, weapons, and impact areas.
- The solo demonstration and closing wide shot must contain all living units
  on both sides while the combat scene is visible; the closing fade to black is
  the deliberate exception. Frame the nine-unit player shot with enough movement
  room; a tight crop of the enemy-side impact is permitted.

## Enemy Matchup And Formation

- Choose authored enemy types and formation spacing that make the featured
  mechanic clear. The Great Sword revision uses Rose Thorn enemies for the
  one-versus-three demonstration; this is a per-weapon matchup, not a requirement
  for every future reel.
- For area-of-effect weapons, cluster enemies closely enough that one genuine
  attack can hit multiple distinct targets. Keep bodies distinguishable and
  avoid overlapping spawns. Verify actual multi-target damage in the dry run,
  not just a large visual effect or several unrelated simultaneous attacks.
- Formation packing is staging, not a balance change: preserve authored attack
  ranges, damage, collision, movement, and unit sizes. Keep the shared counts of
  one player versus three enemies, then nine players versus 18 enemies.
- Apply the setup before the first combat tick and update Home/formation anchors
  consistently. Never bunch enemies or move combatants manually during the fight.
  Tune inter-army distance separately using the range-dependent rules below.

## Range-Dependent Final-Battle Spacing

**Choose separation for the featured weapon. Do not copy the mortar's distance
into every reel.** Melee matchups start closer; long-range and delayed-impact
matchups get more room. Keep nine players and 18 enemies while tuning distance.

Use the nearest opposing front units' center-to-center distance in world space
as the setup measurement, not army-anchor distance or screen pixels. Validate
actual attacks with the game's range and collision logic.

1. Inspect the resolved combat profile: `attack_style`, `engagement_stance`,
   `melee_range`, `projectile_range`, and `skirmish_distance` where applicable.
   Inspect movement, wind-up, projectile flight, and fuse/impact delay too.
   Range class alone is a formation role, not a numeric measure of reach.
2. Choose an initial gap using the branch below. Start from the minimum space
   needed to show the weapon clearly; avoid an opening spent only walking.
3. Run the final battle from 9 seconds through the end of its fade at 17 seconds
   with the intended seed, formation, and authored enemy types. Measure first
   action, first effect, and melee contact, then adjust the starting gap and
   recalculate camera framing.
4. Accept the setup only when the player shot shows the attack beginning, the
   enemy shot shows its consequence, and both sides remain visible in the
   closing wide before the fade. Do not use distance changes to fake range,
   travel speed, or damage.

| Weapon behavior | Starting-distance rule | Acceptance check |
| --- | --- | --- |
| Melee / short reach | Start just outside effective melee engagement reach, with a short, readable approach. As an initial tuning guide, add about 0.3-0.8 s of measured relative closing movement to that reach. | Contact and a recognizable attack occur during the player shot; no long empty march or overlapping spawn. Combat remains readable at the enemy cut. |
| Charge | Keep enough run-up for the actual charge mechanic to activate and become visible. Do not collapse the gap just because the final hit is melee. | Charge develops on the player shot and contact is visible; use native charge timing and speed. |
| Direct ranged / thrown | Use a gap near a useful firing distance, within range or only a short approach outside it. Leave room for the projectile to land before melee contact. | At least one meaningful ranged hit precedes melee; first launch is visible in the player shot. |
| Lobbed / delayed impact | Allow extra closing-time margin for wind-up, flight, and any fuse. Use a wider gap than a comparable immediate-hit weapon where needed. | The first meaningful impact happens before melee, preferably with about 0.5-1 s of readable separation afterward. The enemy shot catches the impact. |
| Hybrid / defensive | Pick spacing and authored enemies for the featured mechanic: throwing before melee, blocking incoming shots, or absorbing a charge. | The intended mechanic actually occurs in the demonstration and final battle; do not force every weapon to behave like artillery. |

The timing ranges above are initial tuning guides, not game-balance constants.
For ranged weapons, more starting distance does not automatically buy more
post-launch time: a unit outside range may simply walk forward before firing.
Verify the actual gap at launch and the actual first impact. If the constraints
conflict, reconsider formation/enemy type or request a shot-timing exception;
keep authored range, movement, damage, and projectile behavior intact.

The mortar pilot uses an **extra 480-world-pixel enemy offset**, not a universal
480-pixel separation. Its first hit is around 12.38 s and melee contact around
13.6 s. These are reference results for that setup, not targets for melee reels.

Apply spacing once, before the first combat tick. Move enemy Home/formation
anchors and battlefield bounds with the spawn positions so normal AI does not
undo the staging. After battle starts, movement comes from gameplay only.

## Sound

- Reuse the latest pilot's `exports/cocoon-heavy-pop.wav` as the shared emergence
  cue: a sharp cork attack, short low-mid body, and clean pressure-release tail.
  Keep it distinct from battle explosions. Do not regenerate it for every weapon.
- Sync the main transient to the shell-opening frame, not the sound file's start.
  Give it space with a brief pre-release music/chime dip; restore the mix before
  the landing. Retain the soft landing cue and authentic weapon/combat effects.
- Keep emergence free of explosion sounds. Use game music without voiceover or
  spoken battle barks. Preserve peak headroom; do not clip to make a hit stronger.
- Fade combat effects with the 15.5-17-second world fade, then retain music under
  the black-background question and cycling equation until its short ending fade.
- Audition the encoded result, including on small speakers. Level and timing
  checks do not prove subjective impact. Record any inability to audition;
  the latest v9 mix is the reference, not a substitute for listening review.

## Production And Review

1. Record recipe order, resolved weapon, featured mechanic, enemy types, seed,
   player age composition, starting gap, formation packing, CTA setting, and camera
   framing in the reel's capture metadata. Keep edits in the capture package; use
   production art and combat without balance changes.
2. Reuse the template, intro, audio cue, music, and overlays. Change recipe
   assets and per-weapon battle setup. Finish a dry run satisfying the spacing
   checks before doing the full-resolution export.
3. Export H.264/AAC MP4 with fast start at 1080x1920 / 60 fps, stereo 48 kHz.
   Preserve prior revisions. Supply the reel, a cover, sampled frames, and
   validation metadata. For audio-only revisions, copy the approved video stream.
4. Review the encoded output against every item below, then present it for
   critique. Stop at the requested scope; publishing requires authorization.

### Acceptance Checklist

- [ ] Correct centered mystery equation, complete equation with result icon and
  authored name beneath it, then standalone weapon name.
- [ ] Cover retains `A + B = ?` and does not reveal the combo icon or name.
- [ ] A single Paper UI backing makes the whole equation readable at phone size,
  with clear contrast, padding, no pixelation at encoded 100% view, and no overlap
  with the subtitle, result name, or reveal.
- [ ] Large title and unchanged "Weapon combos" subtitle use the shared lower
  positions. The Steam CTA is present only when enabled, at its specified position.
- [ ] Child holds A, enters briskly, and emerges with the correct combo weapon.
- [ ] Exciting but readable reveal; fixed unit sizes and grounded shadow.
- [ ] One-versus-three demonstration shows both sides and the defining mechanic.
- [ ] Enemy matchup and formation suit the weapon; AoE demonstrations show one
  genuine attack damaging multiple distinct enemies, without overlapping spawns.
- [ ] Final battle starts with nine matching player weapons and 18 enemies.
- [ ] Any requested Child/Adult mix keeps nine players total, uses valid combo
  resolution for every unit, and preserves the actual age-specific proportions.
- [ ] Starting gap is recorded and justified by this weapon's range and behavior.
- [ ] Player attack, enemy consequence, and both-sides wide shots occur in order.
- [ ] Both input slots cycle valid recipes with matching labels from 14-20 seconds
  while `+`, `=`, and `?` stay fixed; the "Weapon combos" subtitle remains unchanged.
- [ ] Closing inputs keep cycling to the end without settling on a pair or
  revealing a result; branding and Paper UI stay fully visible through the world fade.
- [ ] Combat fades to black from 15.5-17 seconds. Only afterward, "Which combo next?"
  enters the former combat area at 17.15-17.55 seconds and holds readable to 20 seconds.
- [ ] Applicable melee/ranged/charge/defensive spacing checks pass in actual combat.
- [ ] Camera cuts do not teleport units; background responds to camera zoom.
- [ ] Text and important action stay visible at phone size throughout each shot.
- [ ] Cork-pop sync, audible impact, clean peaks, and landing/battle mix checked.
- [ ] Battle effects fade with the combat scene; music continues beneath the outro
  and fades at the end without added prompt or slot-machine sound effects.
- [ ] No voiceover, unrequested captions, or explosion cue at emergence.
- [ ] Export fully decodes; resolution, fps, audio, and duration verified.

## Implementation Reference

The [pilot README](2026-09-28-combo-reels/README.md) links its capture script,
rendering workflow, sound sources, exports, and validation history. Its current
capture/verification code is still mortar-specific: fixed spawn offset,
mortar-named telemetry, and provisional alternative-weapon branches are not a
general implementation of this spec. In particular, old shield count overrides
must not silently replace the shared one-versus-three and nine-versus-18 counts.
Future capture changes should make these settings weapon-specific and validate
the applicable behavior, rather than copying mortar assertions unchanged.
