# Auto Shrooms: Great Sword reel

One review reel following the [shared series spec](../weapon-combo-reels-spec.md).
Recipe: **Sword + Sword = Great Sword**. The weapon uses its real slow sweeping
melee attack, area hitbox, and knockback. Nothing is posted automatically.

## Current Script (V3)

- 0-2.5 s: a sword-holding Child enters the Cocoon; the paper-backed equation
  keeps its question mark.
- 2.5-4 s: split-shell emergence and the shared heavy cork-pop cue. The actual
  Great Sword icon completes the equation, with "Great Sword" beneath it.
- 4-9 s: one Great Sword versus three clustered Rose Thorns, both sides framed
  together so one attack hitting multiple enemies is visible.
- 9-11.3 s: six Adults and three Children, all carrying Great Swords, approach
  and begin attacking 18 Solar Swords. Nine friendlies total.
- 11.3-13.5 s: enemy-side contact shot, showing the sword strikes and knockback.
- 13.5-15.5 s: fixed wider shot with all living units from both sides visible.
- 14-20 s: independently cycling school inputs with a fixed question mark.
  Inputs keep changing to the end; no pair is selected.
- 15.5-17 s: fade combat and its sound effects to black, leaving branding and
  the equation intact.
- 17.15-17.55 s: "Which combo next?" fades in and settles upward into the former
  combat area, then stays readable until the end. Music continues underneath.
- Keep "Weapon combos" as the subtitle throughout. No "Wishlist on Steam" CTA
  appears in this revision.

The title/subtitle use the updated series positions. The light Paper UI strip
backs the whole equation. V1 stretched a 384x80 banner's 44-pixel middle across
247 pixels, enlarging the edge stair steps. Since V2, the reel uses the matching 1220x380
`Paper style 1/paper 12.png`, downsampled with explicit linear filtering and
preserved aspect ratio instead. Its lower edge clears the Great Sword at
the emergence apex. Units retain their authored proportions; camera cuts and
world-space forest scaling provide the changes in framing.

## Battle Setup

Capture seed: `30092026`; army seed: `30092126`. Enemy stat rolls use an explicit
seeded generator. Player units are normally grown with Reinforced Chitin and
trained through the current game resolver, without damage, speed, range, or
cooldown overrides.

Great Sword has 144 world pixels of authored melee reach and 126 pixels of
effective engagement reach. Both fights start at a 306-pixel horizontal front
gap, approximately 308 pixels center-to-center including the authored spawn
height difference. This is engagement reach plus about half a second of the
two sides' relative closing speed. Enemy formation anchors and the stage bound
move with the initial placement, before the first battle tick. No units are
moved for camera transitions.

The final army interleaves Children in slots 1, 4, and 7. They are genuine
Nursery-grown Children inheriting two Sword Trainings through the game's
lineage-spore path, not scaled-down Adults or manually changed life-stage flags.

The solo Rose formation uses a 54-pixel capture-local spacing override before spawning;
the normal Home-slot calculations then maintain the compact formation. Unit
body sizes, collisions, damage, range, and AI remain authored. Damage telemetry
records distinct enemy targets per swing to verify the area attack, not just
several simultaneous damage numbers.

The exported capture metadata records actual hit and swing frames, all enemy
stats, resolved combat settings, camera cuts, and per-frame visibility checks.
The final validation records measured pacing and survivors.

## V3 Gameplay Refresh

V3 keeps V2's script, framing rules, enemy matchup, six-Adult/three-Child roster,
and sound treatment, and recaptures combat using the updated production
`assets/units/unit.gd`. It adds a 0.35-second landing recovery window, prevents
midair relaunches and immediate re-staggering, and advances attack cooldowns
during knockback. The capture does not override any of those mechanics.

The exact gameplay patch is retained in `sources/knockback-v3.patch`; its
source SHA-256 and runtime recovery duration are recorded in the capture and
validation metadata. `sources/knockback-check-v3.json` records four passing
melee/ranged regression cases at 1x and 4x combat speed. Hit sounds are retimed
from the new capture's actual impacts, not copied from V2 timestamps.

V3 export verification:

- 1080x1920, 60 fps, 1200 frames; 20.04-second container, 10.21 MB.
- Full decode, gameplay source hash, age composition, per-frame visibility,
  paper layout, and encoded outro checks passed.
- Audio: stereo 48 kHz, -15.87 LUFS integrated, -4.97 dBTP true peak.
- The solo area hit still occurs at 8.00 s, hitting two Roses for 9 damage each.
  Nine friendlies and three enemies remain when the combat reaches black.
- Clang accents align to picture-relative 5.22, 8.00, 9.60, and 11.63 s.
  No shot timing or staging adjustments were needed. The fixed wide camera
  is recomputed from the updated combat positions at its existing cut.
- Encoded storyboard inspected; subjective audio listening review remains
  outstanding, as with the previous review exports.

## Previous V2 Verification

- 1080x1920, 60 fps, 1200 picture frames; 20.04-second container, 10.20 MB.
- Full H.264/AAC decode passed. Stereo 48 kHz; -15.86 LUFS integrated,
  -4.69 dBTP true peak. The sound mix preserves the encoded picture packets.
- The paper's actual rectangle is checked at x=90, y=452, 900x283. Its source
  is 1220x380 with linear filtering; the encoded cover and reveal were inspected.
- The final roster verifies six Adults and three native Children, with inherited
  Sword + Sword Trainings and unchanged unit/appearance scales. All nine fit
  throughout the player-side shot and remain alive until the combat fade ends.
- One solo swing at 8.00 s damages two distinct Rose Thorns, 10 damage each.
  Native melee movement makes their bodies and damage numbers overlap at contact,
  so the multi-target effect is less distinct visually than the telemetry alone
  suggests. No movement or combat overrides were used to separate them mid-fight.
- First final-battle swing: 9.52 s; first hit: 9.60 s. Every frame passes the
  required solo/player-side/wide visibility checks. Six enemies remain at black.
- Four clangs align to actual visible hits at picture-relative 5.22, 8.00, 9.60,
  and 11.63 s, including the solo area hit and a Child's final-battle hit.
- Eighty valid input swaps continue through 19.92 s without revealing a result.
  Encoded pixel checks confirm black before the animated question, a readable
  question afterward, no Steam CTA, and continuing late input changes.
- Encoded storyboard and full-size cover/reveal/ending inspected. Direct
  subjective audio audition remains outstanding; this is a review export.

## Previous V1 Verification

- 1080x1920, 60 fps, 960 picture frames; 16.04-second container, 9.21 MB.
- Full H.264/AAC decode passed. Stereo 48 kHz; -15.30 LUFS integrated,
  -4.76 dBTP true peak. Encoded picture packets are unchanged by the audio mix.
- Clang onsets are scheduled at picture-relative 4.60, 8.23, 10.10, and 11.63 s,
  using actual hit telemetry and accounting for the container's picture offset.
- Final-battle approach takes about 0.52 s; first damage occurs at 9.60 s.
  All nine players and six enemies survive to the last frame. Actual area hits
  and knockback occur without changing weapon behavior.
- Every encoded-frame step passes living-unit visibility checks for the solo
  and final wide shots; all nine players fit throughout the player-side shot.
- The outro makes 27 valid input swaps, with the last change at 15.95 s. The
  result remains `?`, without settling on a proposed next combo.
- Encoded storyboard, mystery cover, reveal apex, enemy-side impacts, and final
  wide/outro reviewed visually. No paper, text, or CTA overlaps the fighting.
- Direct subjective listening was not available. Sound identity and mix impact
  need playback review; source provenance and the rights caveat are below.

## Sound

Music, ordinary combat effects, and the soft landing cue come from the game.
The emergence uses the pilot's `cocoon-heavy-pop.wav`, with the same pre-release
mix dip. No emergence explosion or voiceover is added.

The user-requested Berserk clang is a short third-party meme sample from
[Quick Sounds](https://quicksounds.com/sound/24589/berserk-clang), used on a few
separated, visible hits rather than every swing. The original recording and
source metadata are preserved in `sources/berserk-clang.mp3` and
`sources/berserk-clang-source.json`. The mix preserves its pitch, applies a
short tail fade, aligns its onset to the chosen hit, and leaves peak headroom.

**Rights are unverified:** the source does not establish commercial reuse
rights. This is a review export, not a claim that the sample is royalty-free;
review rights or replace it before public promotional use. File tags are not
reliable provenance. Direct subjective audio audition is still required.

## Files And Reproduction

- `exports/auto-shrooms-great-sword-v3.mp4`: current portrait H.264/AAC review reel.
- `exports/great-sword-cover.jpg`: early mystery-equation cover, without the answer.
- `exports/great-sword-cover-v3.jpg`: versioned current cover; earlier covers are retained.
- `preview/storyboard-v3.jpg`: sampled encoded frames.
- `sources/great-sword-v3.json`: gameplay and framing telemetry.
- `validation-v3.json`: format, decode, composition, and sound checks.
- V1/V2 exports, samples, and validation remain available for comparison.
- `capture.gd` / `capture.tscn`: offline director, adapted from the pilot.
- `render.py`: native portrait capture, encode, sound mix, previews, and checks.

Run from the repository root, outside the agent sandbox on macOS:

```sh
python3 steam/campaigns/2026-09-30-great-sword/render.py --dry-run
python3 steam/campaigns/2026-09-30-great-sword/render.py --capture
```

`--dry-run` uses Movie Maker for deterministic rendering but skips the 7.5 GB raw
portrait buffer. `--remix-only` reuses the encoded base picture in ignored
`work/`. Requirements: Godot 4.7, Python 3, FFmpeg/ffprobe, and ImageMagick.
The pipeline preserves encoded video packets when mixing audio.

The isolated render checkout uses commit
`ae1d20e9674123550b31d71fb0f4dcf38f3c4021` as its base, keeping unrelated work
in the primary workspace out of the capture. V1/V2 used that base unchanged.
V3 adds the exact current knockback script, SHA-256
`bf190b786b5bb4dc5d6f804216125410edb3b2e23669c6ac8de741935386e771`,
along with its regression scene and the capture package. The primary workspace's
gameplay files are not modified by the render. Completed outputs return here.
