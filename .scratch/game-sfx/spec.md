# Game sound effects

Status: Implemented and verified on 2026-09-15.

## User request

Create SFX for the whole game, including UI actions and combat. The user chose
**playful organic**: paper/wood UI clicks, mushroom pops and growth sounds, and
readable combat impacts. This expands the original infrastructure-only scope in
`.scratch/audio-infrastructure/spec.md`.

## Implementation

- Ship 40 original, locally synthesized one-shot WAV effects. Keep the generator
  so every sound can be reproduced or tuned without a service or download.
- Connect buttons, toggles, keyboard focus, and volume sliders automatically,
  including dynamically rebuilt controls. Add explicit menu and tab navigation,
  custom card selection, and rejection feedback. Hover previews of rejected
  actions stay silent; a rejected action gets a short sound.
- Nursery/War Chamber feedback covers successful purchase, sale, reroll, lock,
  unlock, stock/troop movement, planting, fertilizer, mutation, harvest, starter
  selection, seal selection, training, and composting.
- Combat feedback covers melee/charge attacks, bow/crossbow/throw/horn releases,
  slashing/blunt hits, damage mitigation and projectile blocks, deaths, wall
  destruction, projectile landings, explosions, death spores, revival, acid rain
  onset, battle start/victory, run victory, and run defeat. Shared Unit/Projectile
  hooks cover all current player and enemy unit types.
- Keep cues non-positional, on the existing SFX bus and volume slider. Gameplay
  effects pause and clear when their scene exits or a sandbox battle restarts;
  UI feedback remains available during pause.
- Reuse the built-in randomized pitch helpers. Most cues vary by ±10%; short
  musical reward/outcome phrases use fixed pitch. Use per-cue gain and real-time
  cooldowns with the existing bounded voice pools to limit crowded battles at 4×.
- Preserve the music behavior maintained by the audio infrastructure work.

## Verification seams

Use the already agreed audio playback, settings, and runtime UI seams: load the
bank through the public cue helpers, exercise pause/cooldown/scene cleanup and
actual button input, and run real battles while observing/recording SFX playback.
Check generated WAV duration, format, peaks, silence, and deterministic rebuilds.

## Coverage and authoring

See `assets/audio/README.md` and `assets/audio/sfx/README.md`. This pack contains
short effects and stingers; it adds no spoken barks or ambient loops.

## Verification results

- Godot 4.7 import/parse check: clean.
- Combined audio runtime: 90 assertions passed, no errors or warnings.
- Focused SFX/UI runtime: 43 assertions passed, including keyboard Back feedback.
- Existing settings/combat regression: all 57 assertions passed, with clean
  shutdown after allowing the result stingers and music fade to finish.
- Real combat playback: 7 assertions passed across melee, bow, mortar, and horn
  matchups at 4×. The SFX bus recording is non-silent with approximately 6.8 dB
  peak headroom. The check explicitly stops music before engine shutdown.
- WAV audit: all 40 clips have valid mono PCM format, nonzero RMS, bounded peaks,
  zero-valued endpoints, and durations from 55 ms to 1.5 s. Regeneration preserves
  every WAV's SHA-256 hash.
- Standards review: no findings. Spec review found silent keyboard Back; fixed
  and verified with a runtime assertion. The follow-up review has no findings.
- Playback was verified through Godot's audio mixer and recorded output. A
  listening preview is provided for subjective sound and balance review.

Run the focused checks:

```sh
godot --headless --path . res://.scratch/game-sfx/runtime_check.tscn
godot --headless --path . res://.scratch/game-sfx/combat_check.tscn
```

On macOS run Godot outside the agent sandbox, per `AGENTS.md`. The focused UI
check restores the settings file on exit; the combat check writes only its SFX
recording to `/private/tmp/mycelium-combat-sfx.wav` and does not save preferences.
