# Auto Shrooms: Weapon Combo Reels

Reusable production spec for the "Weapon combos" series. Follow this when
creating a new reel or revising an existing one. The goal is a repeatable,
low-effort format: change the recipe and combat setup, not the visual identity
or story structure. Produce only the reels requested; exporting is not posting.

Reference: [Spore Mortar pilot](2026-09-28-combo-reels/README.md), with the v7
picture and latest v9 sound mix. This spec governs future reels; the pilot's
version history documents earlier experiments, not alternative requirements.

## Shared Script

One combo per reel. Target 16 seconds, portrait 1080x1920, 60 fps. Times below
are picture-relative; audio synchronization must account for container offsets.

| Time | Shot and action | On-screen information |
| --- | --- | --- |
| 0-0.35 s | Establish a Child beside the open Cocoon, holding the first recipe weapon. | Large "Auto Shrooms", subtitle "Weapon combos", centered `A + B = ?` using weapon-school icons and labels. |
| 0.35-0.85 s | Child walks briskly into the Cocoon; it closes. | Keep the mystery equation visible. The Cocoon carries the second school's icon. |
| 0.85-2.5 s | Build anticipation: shell shakes, compresses, and brightens; forest briefly dims. | Preserve the question mark until emergence. |
| 2.5-4 s | Shell splits, sparks release, and the Adult emerges with the combo weapon. | Replace only `?` with the real combo weapon icon. Hold the complete equation before showing the name. |
| 4-9 s | Single-unit demonstration: one equipped player unit versus three enemies, both sides in the same shot. Show the actual attack and its consequence. | Replace the equation with the weapon's authored display name. |
| 9-11.3 s | Final battle, player-side shot: nine player units all using this combo weapon versus 18 enemies. Show the attack beginning. | Weapon name remains. |
| 11.3-13.5 s | Hard cut to the enemy side receiving the attack. | Show visible impacts, knockback, blocking, or the relevant real mechanic. |
| 13.5-16 s | Hard cut to a wider shot with both sides visible, with room for their continuing movement. | Keep the weapon name; add the CTA at 14 s. |
| 14-16 s | Battle continues under the closing prompt. | Large, lower-frame "Wishlist on Steam". |

For melee weapons, "attack beginning" means approach, charge, wind-up, or swing,
not a projectile volley. For defensive weapons, choose enemies that visibly
exercise the defense. Keep the same player-side / enemy-side / wide sequence.
Tune setup and spacing to fit these beats first. If a weapon genuinely requires
a timing exception, record it and obtain review instead of silently changing
the series format or game behavior.

## Covers

- Every cover/thumbnail keeps the mystery equation `A + B = ?`, with the two
  input-school icons visible and the question mark in the result slot. Its job
  is to invite playback, not reveal the answer.
- Keep "Auto Shrooms" and "Weapon combos" prominent and the equation centered.
  Do not show the combo weapon's name, result icon, or equipped Adult on the cover.
- Export a clear pre-reveal frame with the Child or closed Cocoon; the pilot
  uses 0.2 seconds. Check the actual frame rather than trusting the timestamp
  if a future reel's timing changes. Keep the equation readable at thumbnail size.
- This rule applies to the cover only. During playback, retain the complete
  equation at emergence and the weapon name afterward, as specified above.

## Presentation Rules

- Reuse the pilot's fonts, colors, overlay positions, title hierarchy, and CTA.
  The title must be prominent, not a small logo in a corner.
- Center the entire equation, including symbols and the result slot, at x=540.
  Keep equal visual spacing; the full result must remain centered too.
- Use the actual recipe, icons, weapon name, appearance, and Training resolver.
  Duplicate-school recipes still show both inputs, such as `Mace + Mace = ?`.
- The entering unit is a Child visibly holding A, not the finished combo weapon.
  The emergence is a staged visual summary of Training, not a random reward:
  use a satisfying loot-reveal feeling without implying a random weapon result.
- Keep entry brisk: 0.5 seconds of walking, with the pilot's 2.1x walk animation.
  Reuse the split shell, warm flash, sparks, 240-pixel hop, brief apex hold,
  and landing at 3.1 seconds. The shadow stays on the floor. Keep the weapon legible.
- Preserve authored Child/Adult proportions and unit transforms. Frame with the
  camera; never resize individual units to fit or slide armies for a new angle.
  Shell and UI-icon animation may scale; unit bodies may not.
- Use fixed camera shots with hard cuts. The final shot is zoomed out relative
  to the closer shots. Forest scenery must scale with the world camera too.
  Only overlays and the introductory forest may remain screen-fixed.
- Hide gameplay HUD, menus, flag bearer, kill callouts, and battle dialogue.
  Keep visible copy to branding, recipe, weapon name, and CTA: no "Wait for it"
  or explanatory captions. Keep text clear of units, weapons, and impact areas.
- The solo demonstration and closing wide shot must contain all living units
  on both sides throughout the shot. Frame the nine-unit player shot with
  enough movement room; a tight crop of the enemy-side impact is permitted.

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
3. Run the full seven-second final battle with the intended seed, formation,
   and authored enemy types. Measure first action, first effect, and melee
   contact, then adjust the starting gap and recalculate camera framing.
4. Accept the setup only when the player shot shows the attack beginning, the
   enemy shot shows its consequence, and both sides remain visible in the
   closing wide. Do not use distance changes to fake range, travel speed, or damage.

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
- Audition the encoded result, including on small speakers. Level and timing
  checks do not prove subjective impact. Record any inability to audition;
  the latest v9 mix is the reference, not a substitute for listening review.

## Production And Review

1. Record recipe order, resolved weapon, featured mechanic, enemy types, seed,
   starting gap, and camera framing in the reel's capture metadata. Keep edits
   in the capture package; use production art and combat without balance changes.
2. Reuse the template, intro, audio cue, music, and overlays. Change recipe
   assets and per-weapon battle setup. Finish a dry run satisfying the spacing
   checks before doing the full-resolution export.
3. Export H.264/AAC MP4 with fast start at 1080x1920 / 60 fps, stereo 48 kHz.
   Preserve prior revisions. Supply the reel, a cover, sampled frames, and
   validation metadata. For audio-only revisions, copy the approved video stream.
4. Review the encoded output against every item below, then present it for
   critique. Stop at the requested scope; publishing requires authorization.

### Acceptance Checklist

- [ ] Correct centered mystery equation, complete icon equation, then weapon name.
- [ ] Cover retains `A + B = ?` and does not reveal the combo icon or name.
- [ ] Large title, "Weapon combos" subtitle, and large/lower Steam CTA.
- [ ] Child holds A, enters briskly, and emerges with the correct combo weapon.
- [ ] Exciting but readable reveal; fixed unit sizes and grounded shadow.
- [ ] One-versus-three demonstration shows both sides and the defining mechanic.
- [ ] Final battle starts with nine matching player weapons and 18 enemies.
- [ ] Starting gap is recorded and justified by this weapon's range and behavior.
- [ ] Player attack, enemy consequence, and both-sides wide shots occur in order.
- [ ] Applicable melee/ranged/charge/defensive spacing checks pass in actual combat.
- [ ] Camera cuts do not teleport units; background responds to camera zoom.
- [ ] Text and important action stay visible at phone size throughout each shot.
- [ ] Cork-pop sync, audible impact, clean peaks, and landing/battle mix checked.
- [ ] No voiceover, extra captions, or explosion cue at emergence.
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
