# Adding audio

## Music

1. Add your music files under `assets/audio/` (OGG is a good default).
2. Open `assets/autoload/audio.tscn` in Godot and select the root **Audio** node.
3. Assign **Base Music** and **Battle Music** in the Inspector, then save the scene.

The title screen and Base play Base music at full volume with Battle music silent. Each new Battle restarts Battle music from the beginning and brings it to full volume while Base music lowers to 20%. Returning to Base or title restores Base music to full volume and silences Battle music. Base music keeps its playback position throughout. Volume changes take 0.5 seconds.

Combat, day summary, victory, and game over use the Battle mix. Result screens continue the current Battle music without restarting it. A direct launch into one of these scenes starts both tracks at those levels. Empty slots stay silent, while an assigned other track keeps its usual level; an empty Base slot does not make Battle music audible in Base. The Music settings slider scales the entire mix.

Use `Audio.play_battle_music(true)` when starting a new combat, including rematches. Use `Audio.play_battle_music()` on result screens to preserve playback, and `Audio.play_base_music()` on Base/title entry. `Audio.stop_music()` fades out and stops both songs; the next request starts playback from the beginning.

OGG, MP3, and WAV tracks loop automatically. Existing loop offsets/points are preserved; changes apply to a playback copy, so using the same file as an effect does not make the effect loop. Other Godot stream types repeat when they finish; use native loop points for seamless music.

Music and its volume transitions continue while paused and use real time during fast-forward and hitstop.

## Sound effects

The game ships a [40-effect playful organic pack](sfx/README.md). Its streams,
individual gains, pitch variation, and minimum spacing are authored in `sfx.gd`.
Use the named cue helpers for gameplay and UI events:

```gdscript
Audio.play_cue(Sfx.Cue.HIT_BLUNT)
Audio.play_ui_cue(Sfx.Cue.HARVEST)
```

Each cue has a real-time cooldown, so simultaneous hits and fast-forwarded
battles do not flood the mix. Different cues can overlap. These helpers return
`null` when a cue is rate-limited or gameplay is paused. Most cues use ±10%
pitch variation; musical reward/outcome phrases use fixed pitch.

Buttons, toggles, focus/hover feedback, and volume sliders are wired automatically,
including dynamically created controls. Do not add another generic click handler.
Custom cards and successful actions use explicit semantic cues in their owning UI
controller. Projectiles expose **Launch Cue** in their scenes: throws by default,
with bow/crossbow and horn overrides. New unit types using the shared combat scripts
inherit attack, hit, block, and death feedback.

### Custom streams

Load or export an `AudioStream` on the scene that owns the action, then trigger it where the action occurs:

```gdscript
@export var hit_sound: AudioStream
@export var click_sound: AudioStream

func on_hit() -> void:
	Audio.play_sfx(hit_sound)

func on_button_pressed() -> void:
	Audio.play_ui_sfx(click_sound)
```

Both helpers accept an optional per-effect gain in decibels, for example `Audio.play_sfx(hit_sound, -6.0)`. A missing stream is a silent no-op. Effects are non-positional and share the **SFX** volume control.

Every call chooses a fresh pitch within ±10% of normal (0.9–1.1×), including when reusing a pooled player. The optional third argument changes this fractional variation: `Audio.play_sfx(hit_sound, -6.0, 0.05)` uses ±5%; `Audio.play_ui_sfx(click_sound, 0.0, 0.0)` plays at exactly normal pitch. Variation is clamped to 0–0.99; non-finite values use the default. Pitch variation also changes the effect's playback speed. Music keeps its normal pitch and speed, and audio randomization does not consume gameplay randomness.

- Gameplay effects pause/resume with gameplay; new requests while paused are ignored. They stop when their current scene exits. `Audio.stop_gameplay_sfx()` also clears them explicitly, for example when resetting a battle within the same scene.
- UI effects remain available during pause.
- Pools hold up to 16 gameplay effects and 4 UI effects. A full pool replaces its oldest effect. The returned `AudioStreamPlayer` is pooled: use it only for immediate adjustments, not as a lasting playback handle.

For a scene-owned `AudioStreamPlayer` or animation audio track, set its bus to **SFX** and choose the appropriate process mode. Music uses the persistent Audio service. Both buses feed **Master**.

## Settings

The Base/combat menu exposes SFX and Music sliders from 0–100%. They apply immediately and are saved in the existing `user://settings.cfg`, independently of Run data. Both default to 100%; 0% mutes the corresponding bus. `SettingsServer.sfx_volume` and `SettingsServer.music_volume` use normalized values from 0.0–1.0.

## Verification

Run the focused runtime scene, which creates temporary test tones in memory and restores the preferences file on exit:

```sh
godot --headless --path . res://.scratch/audio-infrastructure/runtime_check.tscn
```

On macOS, launch outside the agent sandbox as required by `AGENTS.md`. For visual verification, replace `--headless` with `--rendering-method gl_compatibility --audio-driver Dummy`. The check writes `/private/tmp/audio-settings.png` and, when preferences already exist, a recovery backup at `/private/tmp/audio-infrastructure-settings.backup`.
