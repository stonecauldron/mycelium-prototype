# Adding audio

## Music

1. Add your music files under `assets/audio/` (OGG is a good default).
2. Open `assets/autoload/audio.tscn` in Godot and select the root **Audio** node.
3. Assign **Base Music** and **Battle Music** in the Inspector, then save the scene.

The title screen and Base start Base music at full volume. On the first Battle, Base music lowers to 20% and Battle music begins at full volume. Returning to Base or title raises Base music to full volume and lowers Battle music to 20%. Both songs keep playing and looping, so later transitions preserve both playback positions. Volume changes take 0.5 seconds.

Combat, day summary, victory, and game over use the Battle mix. A direct launch into one of these scenes starts both tracks at those levels. Battle music starts only once a Battle/result screen is entered; it is silent on the initial title/Base visit. Empty slots stay silent, while an assigned other track keeps its normal foreground/background level. The Music settings slider scales the entire mix.

`Audio.stop_music()` fades out and stops both songs. The next request starts playback from the beginning; normal scene transitions only change their volumes.

OGG, MP3, and WAV tracks loop automatically. Existing loop offsets/points are preserved; changes apply to a playback copy, so using the same file as an effect does not make the effect loop. Other Godot stream types repeat when they finish; use native loop points for seamless music.

Music and its volume transitions continue while paused and use real time during fast-forward and hitstop.

## Sound effects

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
