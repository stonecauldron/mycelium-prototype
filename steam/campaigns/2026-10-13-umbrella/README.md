# Auto Shrooms: Umbrella Reel

Recipe: **Shield + Bow = Umbrella Shield**. Portrait V3 and landscape V4 use the latest canopy physics:
arrows attach to the moving umbrella and Seed Lobber bombs bounce off its surface.
Bombs now start their fuse on first canopy contact while continuing to fly.
Two separately framed versions follow the
[shared reel script](../weapon-combo-reels-spec.md):
1080x1920 portrait and 1920x1080 landscape for X. Nothing is posted automatically.

## Current Script (Portrait V3 / Landscape V4)

- 0-2.5 s: a Shield-holding Child quickly enters the Bow Cocoon. The equation
  remains `Shield + Bow = ?` on the high-resolution Paper UI backing.
- 2.5-4 s: split-shell emergence, the shared heavy cork-pop, and the actual
  Umbrella Shield icon and name completing the equation. In 16:9, the Adult
  follows one continuous leftward parabola from the Cocoon to the ground.
- 4-9 s: one Umbrella Shield versus three native Seed Lobbers. Both sides remain
  in frame as incoming spore bombs bounce off the canopy.
- 9-11.3 s: player-side shot of six Adults and three Children, all with Umbrellas,
  advancing under fire from nine Peashooters and nine Seed Lobbers.
- 11.3-13.5 s: enemy-side shot of the mixed ranged army firing.
- 13.5-17 s: wide shot showing both armies, fading to black from 15.5 s.
- 14-20 s: the two input schools cycle independently while the result stays `?`.
  Neither input settles into a suggested next combo.
- 17.15-17.55 s: animated "Which combo next?" appears in the former combat area,
  then holds through the ending. "Weapon combos" remains the subtitle.

No Steam CTA, voiceover, explosion on emergence, or Great Sword meme clang.
Both covers use the early mystery equation without revealing the result.

## Capture And Framing

The capture uses the current primary checkout at
`cecf2434672f20505aa7f73f6e0d4594dba22463`, not the older Great Sword render
worktree, plus the user's current uncommitted umbrella-physics changes. The reel
does not edit those production files. Capture seed is `13102026`; army seed is
`13102126`. Versioned `sources/umbrella-{format}-v{version}-source.json` manifests and
`-physics.patch` files preserve the exact source state, without unrelated work.
Hashes are checked before and after capture and against the runtime metadata.

Peashooter's native projectile range is 1300 world pixels; Seed Lobber's is 1200.
Both scenarios begin at a 720-pixel horizontal front gap, allowing shots to reach
the canopies before contact. Initial enemy placement also moves the formation anchor and
stage bound, before combat starts. Combat then runs normally, including the
all-Umbrella army's natural advance and enemy retreat. No forced blocks,
projectile deletion, damage changes, altered cooldowns, or unit movement at cuts.

The final army has nine friendlies: six Adults and three genuine Children in
slots 1, 4, and 7. Children inherit Shield + Bow through the native lineage-spore
and Nursery path. All unit and appearance transforms retain their authored
scales. The intro uses the same 1.65 presentation scale as previous reels.
Portrait retains its 240-pixel hop and original intro placement. Landscape raises the
Child/Cocoon intro grouping by 80 pixels, with a ground line at y=960.

Landscape is a native 1920x1080 render with its own branding, equation, combat,
and closing-question layout, not a crop or letterboxed portrait. Camera cuts
recompute their field of view for each aspect ratio. The world-space forest
scales with the camera. Paper UI uses the 1220x380 source with linear filtering
and preserved aspect ratio. The result label can wrap without overflowing.

The higher landscape intro follows the shared spec's **16:9 Intro Framing**
rule. The Adult's apex and landing must be left of the Cocoon, with the full-size
canopy clear of the centered paper throughout the hop. Keep the original centered
opening composition fixed: Child x=705, Cocoon x=1120, and ground y=960. V4 changes
only the Adult's flight: from 2.5 to 3.1 seconds, it travels at constant horizontal
speed to x=345 along a 120-pixel-high parabola. Its midpoint apex is x=732.5,
y=840. There is no sideways burst, delayed lift, apex hold, reversal, or rebound;
it remains grounded after landing. The shallower arc keeps the full-size canopy
clear of the paper without moving the centered opening or equation.
V1-V3 exports and their metadata remain available for comparison. Portrait V3
is unchanged; the landscape-only correction does not require recapturing it.

Read-only instrumentation distinguishes canopy catches from bomb bounces.
Caught arrows must be spent, have no hit targets, and be attached to the native
blocker. Bombs must remain unspent, identify the native bounced blocker, and have
their fuse armed by the production canopy contact. They can explode in midair;
later bounces and landing do not restart the fuse.
The production handler supplies reflection, velocity retention, arrow attachment,
and fuse behavior; the capture never forces those outcomes. The canopy follows
the authored weapon pose and its silhouette, including while swinging.
Metadata records the defending unit, life stage, projectile, shot, and visibility.

## Audio

The game supplies arrow/bomb launches, canopy catches/bounces, explosions during
combat, and battle music.
Emergence reuses `2026-09-28-combo-reels/exports/cocoon-heavy-pop.wav`, with the
same pre-release mix dip and transient alignment. Combat audio fades with the
battle; music continues under the closing question. The second mix pass copies
the encoded video packets unchanged. Technical loudness and peak measurements
are in the validation reports; subjective listening review is still required.

## Files And Reproduction

- `exports/auto-shrooms-umbrella-portrait-v3.mp4`: current portrait reel.
- `exports/auto-shrooms-umbrella-landscape-v4.mp4`: current 16:9 X version.
- `exports/umbrella-{format}-cover-v{version}.jpg`: mystery covers.
- `preview/storyboard-umbrella-{format}-v{version}.jpg`: encoded storyboards.
- `sources/umbrella-{format}-v{version}.json`: source hashes, defense events, and framing.
- `validation-{format}-v{version}.json`: decode, timing, audio, composition, and outro checks.
- V1-V3 exports, covers, storyboards, and verification remain unchanged.
- `capture.gd` / `capture.tscn`: offline director using the production scene.
- `render.py`: reproducible capture, encode, sound mix, previews, and verification.

Run from the repository root, outside the agent sandbox on macOS:

```sh
python3 steam/campaigns/2026-10-13-umbrella/render.py --dry-run --format landscape
python3 steam/campaigns/2026-10-13-umbrella/render.py --capture --format landscape
```

The scripts currently produce V4. `--format portrait` processes portrait only;
`--format all` processes both. The latest requested correction is landscape only.
`--dry-run` skips the approximately 7.5 GB raw RGB buffer per format.
`--remix-only` reuses the encoded base picture in ignored `work/`.
Requirements: Godot 4.7, Python 3, FFmpeg/ffprobe, and ImageMagick.

Exports use H.264 High/yuv420p, BT.709, 60 fps, AAC stereo 48 kHz, and MP4
faststart. The landscape resolution and codecs follow
[X's official Media Studio specifications](https://help.x.com/en/using-x/media-studio-faqs).

## Verification

The renderer checks 1200 picture frames, exact dimensions, full decode, source
hashes, true-peak headroom, visible solo bomb bounces, both army defense types,
visible enemy launches, the mixed-age roster, and every-frame required unit
visibility. Landscape also requires the original centered opening coordinates,
every frame of the continuous leftward parabola, and a stationary grounded Adult
after landing. Encoded pixel checks verify black before the question, readable text afterward, no Steam CTA,
and changing input icons near the final frame. Final measurements are retained
in the per-format validation JSON.

### Current Results

| Version | Resolution | File Size | Duration | Integrated Audio | True Peak |
| --- | --- | --- | --- | --- | --- |
| Portrait V3 (unchanged) | 1080x1920 | 10.34 MB | 20.04 s | -15.80 LUFS | -4.83 dBTP |
| Landscape V4 / X | 1920x1080 | 15.79 MB | 20.04 s | -15.80 LUFS | -5.03 dBTP |

Both current exports contain 1200 picture frames at 60 fps and pass full decode,
source-hash, required combat visibility, and encoded outro checks. Each records
24 native bomb deflections with armed fuses and 19 stable arrow attachments.
The portrait export was not regenerated for the landscape-only path correction.

Landscape V4 preserves the centered opening and follows the exact parabola on
all 37 flight samples, with no pause or reversal. The Adult remains on the ground
after frame 186. Minimum conservative alpha-trimmed canopy clearance from the
equation is 21.48 pixels, with no intro visibility failures. Regression checks
also reject an apex hold, landing rebound, shifted opening, or missing flight frame.
The prior landscape V3 used a lateral burst followed by a held hop; it is retained
only for comparison and is superseded by V4.

### Previous V2 Results

V2 predates the first-canopy-contact fuse and uses a rightward landscape emergence.
Its source manifests preserve that earlier physics, not the current checkout.

| Version | Resolution | File Size | Duration | Integrated Audio | True Peak |
| --- | --- | --- | --- | --- | --- |
| Portrait | 1080x1920 | 10.13 MB | 20.04 s | -16.00 LUFS | -5.02 dBTP |
| Landscape / X | 1920x1080 | 15.44 MB | 20.04 s | -16.05 LUFS | -3.90 dBTP |

Both exports contain 1200 picture frames at 60 fps and pass full decode, source
hash, intro clearance, required combat visibility, and encoded outro checks.
The source manifests match each other and the gameplay files captured for V2.
Each capture records 24 distinct bomb deflections and 17 native arrow attachments.
All observed attached arrows remain stable relative to their moving canopy.

The solo shot includes five visible bomb deflections, beginning at 6.03 seconds.
The army's first defense occurs at 10.97 seconds, within the player-side shot;
both defense types are visible there and in the final wide shot. The enemy cut
shows both Peashooters and Seed Lobbers firing. All nine friendlies and all 18
enemies remain alive through the visible final battle. Bomb explosions can still
damage units, preserving the actual defense rather than implying invulnerability.

Encoded storyboards, mystery covers, the first bomb's reflected trajectory, and
the higher landscape intro were visually reviewed. Landscape uses an emergence
apex at x=1540 and retains its y=960 opening ground line; the unit's size, entry
alignment, and landing position are unchanged. Neither format overlaps the
equation during emergence, including conservative alpha-trimmed sprite bounds.

### Previous V1 Results

V1 used three Peashooters for the solo fight and 18 Peashooters for the army,
before the updated attachment/bounce physics and higher landscape intro.

| Version | Resolution | File Size | Duration | Integrated Audio | True Peak |
| --- | --- | --- | --- | --- | --- |
| Portrait | 1080x1920 | 9.31 MB | 20.04 s | -16.74 LUFS | -4.33 dBTP |
| Landscape / X | 1920x1080 | 14.13 MB | 20.04 s | -16.80 LUFS | -4.40 dBTP |

Both have 1200 picture frames at 60 fps and pass full decode, required
every-frame unit visibility, source-hash checks, and encoded outro checks.
Each capture records 34 genuine arrow blocks, including three in the solo fight.
The first solo block occurs at 5.58 s and the first army block at 10.97 s,
within the player-side shot. The enemy-side cut includes visible bow launches.
All nine friendlies remain alive through the fade. No production gameplay files
were changed. Encoded storyboards, mystery covers, reveal clearance, and the
landscape swing framing were visually reviewed.
