# Auto Shrooms: Spore Mortar reel pilot

One portrait reel for critique and format refinement: Spore Mortar. Production
of Umbrella Shield, Great Horn, Great Hammer, and Polehammer is deferred until
the user has reviewed this pilot. The reel uses the current game's recipe
resolver, character art, combat scene, weapon behavior, and sounds.

For new reels or format revisions, follow the shared
[Weapon Combo Reels Spec](../weapon-combo-reels-spec.md). It defines the common
script and range-dependent final-battle spacing; this README records the pilot.

## Current format (v9)

- Larger centered Auto Shrooms heading, with Weapon combos below it.
- 0-2.5 seconds: centered school equation with a question mark. A spear-holding child
  walks into the cocoon from 0.35-0.85 seconds (0.5 seconds, previously 1.05).
  The walk animation also runs at 2.1x speed. The cocoon closes, then shakes,
  compresses, and brightens against a briefly dimmed forest.
- 2.5-4 seconds: the shell snaps into two flying halves with sparks, a warm
  flash, and a layered, full-bodied cork pop over a softened training chime
  (no explosion sound). The adult jumps 240 pixels
  upward, holds briefly at the apex, and lands at 3.1 seconds with a dust puff
  and soft ground cue. The shadow stays on the floor and the unit is not resized.
  The mortar icon pops into the equation in place of the question mark.
- 4-9 seconds: the weapon name replaces the equation. A stationary wide shot
  shows one mortar and all three enemy targets together, from launch to impact.
- 9-11.3 seconds: nine mortar units launch their shots against 18 enemies.
  The enemy formation starts 480 world pixels farther away than in v3 so
  mortar damage can land before the lines reach melee range.
- 11.3-13.5 seconds: cut to the advancing enemy army receiving the bombardment.
- 13.5-16 seconds: end on a zoomed-out shot containing both armies.
- 14-16 seconds: larger, lower Wishlist on Steam over the continuing battle.
- Game music and effects, plus a generated cork-pop attack with a pitched body
  layer and short harmonic thump for emergence. The mix briefly dips before
  release and recovers fully before landing.
  No voiceover or "Wait for it" caption.
- Cover: use the pre-reveal `Spear + Bow = ?` frame, keeping the answer hidden
  until playback. Do not use the completed equation or weapon name as a cover.
- Authored child/adult art retains its natural proportions. Unit transforms are
  unchanged; wider camera framing fits both armies in the single-weapon and
  final shots. Camera position and zoom remain fixed between hard cuts.
- Flag bearer and kill-callout text hidden for clean framing.
- Combat uses the production world's tiled forest sprites, so the background
  scales and moves with the same camera as the units. Only the intro forest,
  titles, and closing CTA are screen-fixed.

Battles are staged showcases with authored enemy types and normally grown and
trained player units. No production gameplay files are modified. The capture
scene changes camera framing and hides the HUD, and uses the existing forest
art in world space during combat. The large fight contains exactly nine player units
and the same 18 enemies as v2.
The animated cocoon entry, shell breakup, and celebratory burst are staged using
the actual game art and effects; the weapon result uses real Training logic.

## Files and reproduction

- `exports/auto-shrooms-spore-mortar-v9.mp4`: current portrait review video.
- `exports/cocoon-heavy-pop.wav`: isolated, layered, level-adjusted reveal effect.
- `sources/cocoon-heavy-pop-generation.json`: generation prompt, model, request,
  source URL, and processing provenance.
- `validation-v9.json`: audio levels, synchronization, impact comparison with v8,
  full decode, and exact
  encoded-picture/timestamp comparison with v7.
- `exports/spore-mortar-cover.jpg`: current mystery cover, extracted at 0.2 s.
  Older versioned covers are historical outputs, not the cover to publish.
- `preview/storyboard-v7.jpg`: ten frames from the encoded revision.
- `preview/reveal-v7.jpg`: eight encoded frames covering the cocoon reveal.
- `sources/spore-mortar-v7.json`: timing, rosters, camera cuts, and combat damage.
- `validation-v7.json`: video/audio, composition, reveal timing, and impact checks.
- Earlier v1-v8 exports and sound effects remain available for comparison.

V9 is an audio-only revision of the approved v7 picture. Reproduce it without
recapturing gameplay or making another generation request:

```sh
python3 steam/campaigns/2026-09-28-combo-reels/remix_cocoon.py
```

Use `--version 8` to reproduce the previous, lighter cork-pop mix.

To recapture the underlying v7 picture from the repository root, run outside
the agent sandbox on macOS:

```sh
python3 steam/campaigns/2026-09-28-combo-reels/render.py --capture
```

Godot Movie Maker supplies fixed 60 fps timing and game SFX. The delivered
picture comes from native 1080x1920 RGB pixels read from a dedicated portrait
viewport, not the Movie Maker preview video. FFmpeg mixes the existing battle
music with those SFX and exports H.264/AAC with a fast-start MP4 container.
The renderer uses loudness normalization with -16 LUFS / -1.5 dBTP targets.

`work/` is ignored and contains temporary raw capture data. Re-running the
command recreates it. No posting or publication is part of this pilot.

## Current v9 verification

- H.264, 1080x1920, 60 fps, 960 picture frames, 8.51 MB. Full decode passed.
- Every encoded video packet and its timestamps match v7 exactly.
- AAC stereo, 48 kHz; -13.81 LUFS integrated and -2.15 dBTP true peak.
- New generated attack, parallel 0.8x pitched cork, and a short harmonic body
  form a 0.525-second effect. Its main transient aligns with the shell opening.
- In the first 150 ms after release, full-band energy is 7.14 dB above v8;
  the 120-600 Hz band is 5.89 dB stronger. The effect peaks at -2.2 dBFS.
- A 180 ms pre-release dip makes room for the hit. The original mix is at 7%
  during the pop and returns fully by 3.033 seconds, before the landing cue.
- Audio correlation before the reveal and from landing through the battles
  exceeds 0.9998 against v7. No explosion sound was added.
- Technical synchronization, energy, and headroom checks passed. Playback was
  not directly auditioned in this environment; subjective impact needs review.

## Previous v8 verification

- H.264, 1080x1920, 60 fps, 960 picture frames, 8.51 MB. Full decode passed.
- Every encoded video packet and its timestamps match v7 exactly. No visual,
  animation, camera, or battle changes.
- AAC stereo, 48 kHz; -13.81 LUFS integrated and -1.90 dBTP true peak.
- The generated take contained two hits; only the first is used. Its strongest
  3 ms window aligns with the shell-opening frame at 2.533 seconds, including
  the existing video's 0.033-second presentation offset. The old mix is briefly
  ducked to 22%, returning fully before the landing cue.
- Audio correlations before the reveal and from landing through the battles
  exceed 0.9995 against v7. No explosion sound was added.
- Technical synchronization and level checks passed; playback was not directly
  auditioned in this environment.

## Previous v7 verification

- H.264, 1080x1920, 60 fps, 960 picture frames, 8.51 MB. Full decode passed.
- AAC stereo, 48 kHz; -13.72 LUFS integrated and -1.84 dBTP true peak.
- Reviewed the encoded storyboard and dedicated reveal sequence: compressed
  wind-up, two flying shell halves, sparks, a 240-pixel hop with a 0.1-second
  apex hold, and landing at 3.1 seconds. The shadow remains grounded and unit
  scale stays at 1.65 throughout. No explosion sound accompanies emergence.
- The faster 0.5-second child entry and 2.5-second reveal are retained; combat
  starts at 4 seconds and all camera-cut timings remain unchanged.
- Nine players and 18 initial enemies retained. Wide-shot framing and
  world-space background scaling checks pass. Mortar damage begins at 12.38
  seconds, before melee range at 13.6 seconds.

## Previous v6 verification

- H.264, 1080x1920, 60 fps, 960 picture frames, 8.04 MB. Full decode passed.
- AAC stereo, 48 kHz; -13.78 LUFS integrated and -1.57 dBTP true peak.
- Entry takes 0.5 seconds with 2.1x walk animation; the cocoon closes at 0.85
  seconds. The reveal remains at 2.5 seconds and combat begins at 4 seconds.
- Reviewed the encoded storyboard and 0.9-second frame confirming the child
  is already inside the closed cocoon. Total duration and camera-cut timing
  remain unchanged.
- Nine players and 18 initial enemies retained, with all units framed in wide
  shots and world-space forest scaling verified at each camera cut. Mortar
  damage still precedes melee contact by 1.1 seconds.

## Previous v5 verification

- H.264, 1080x1920, 60 fps, 960 picture frames, 8.04 MB. Full decode passed.
- AAC stereo, 48 kHz; -13.84 LUFS integrated and -1.48 dBTP true peak.
- Nine mortar units versus 18 initial enemies. All nine fit throughout the
  sampled player-volley shot, including their advance into firing positions.
- Background sprite screen scale matches its authored 0.5 scale multiplied by
  camera zoom at every cut. The screen-fixed intro forest is hidden in combat.
- First mortar damage occurs at 12.38 seconds, before melee range at 13.48
  seconds. The extra 480-world-pixel enemy spawn distance is retained.
- Encoded storyboard and 10.9-second volley frame reviewed. Both armies remain
  visible in the final wide shot, where the forest zooms out with the units.
- Intro, recipe reveal, titles, sounds, and CTA retain the previous format.
  No production gameplay files are modified.

## Previous v4 verification

- H.264, 1080x1920, 60 fps, 960 picture frames, 7.72 MB. Full decode passed.
- AAC stereo, 48 kHz; -14.75 LUFS integrated and -1.58 dBTP true peak.
- Final battle remains three mortars versus 18 enemies. Only that encounter's
  enemy starting formation and anchor move 480 world pixels farther away.
- First mortar damage occurs at 12.55 seconds, with 285 world pixels of melee
  clearance. Enemies first enter melee range at 14.40 seconds: a 1.85-second lead.
- Encoded storyboard and 12.8-second impact frame reviewed. Both armies remain
  fully framed in the closing wide shot. Intro, recipe, audio cues, and CTA
  retain the v3 format; production gameplay files remain unchanged.

## Previous v3 verification

- H.264, 1080x1920, 60 fps, 960 picture frames (16 seconds), 7.74 MB.
- AAC stereo, 48 kHz. Measured -15.33 LUFS integrated, -1.53 dBTP true peak.
- Full MP4 decode passed. The container is 16.033 seconds due to codec timing.
- Reviewed the encoded storyboard and closing frame: spear-holding child,
  completed icon equation before the name, three-unit volley, enemy impacts,
  both armies in the final wide shot, and the larger/lower Steam prompt.
- Telemetry confirms three players and 18 initial enemies. Every living unit
  remains inside both wide shots, including the retreat at the end. Camera
  framing stays fixed between cuts; the last shot includes room for movement.
- The closing CTA is present throughout the last 1.9 seconds of encoded frames.
- Reveal uses only the training cue; explosion audio remains in combat only.
- No script parse or assertion failures. Godot's usual texture/resource cleanup
  warnings appear after successful capture.

## Previous v2 verification

- H.264, 1080x1920, 60 fps, 960 picture frames (16 seconds), 8.37 MB.
- AAC stereo, 48 kHz. Measured -15.20 LUFS integrated, -1.56 dBTP true peak.
- Full MP4 decode passed. The container is 16.033 seconds due to codec timing.
- Encoded storyboard reviewed: centered mystery equation, larger heading and
  subtitle, cocoon entry and burst, six-unit volley, and enemy-side impacts.
- The equation's center is x=540. Presentation scale stays at 1.65; camera
  framing is fixed between hard cuts. All six players fit in the volley shot.
- Combat telemetry confirms actual mortar damage in both fights and six
  surviving player units at the end of the army sequence.
- Godot reports resource cleanup warnings at shutdown after successful capture;
  no script parse or assertion failures occurred.

## Original v1 verification

- H.264, 1080x1920, 60 fps, 960 picture frames (16 seconds), 9.37 MB.
- AAC stereo, 48 kHz. Measured -14.13 LUFS integrated, -1.53 dBTP true peak.
- Full MP4 decode passed. The container is 16.033 seconds due to codec timing.
- Encoded-frame storyboard reviewed at phone size: recipe, reveal, close
  attack, ten-unit squad, visible explosions, and closing CTA.
- Combat telemetry confirms actual bomb damage during the close shot and
  bombardment; all ten featured units survive the final squad sequence.
- Godot's shutdown reports texture/resource cleanup warnings after successful
  capture. No script parse or assertion failures occurred.
