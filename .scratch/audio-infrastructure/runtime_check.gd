extends Node

var _failures: int = 0
var _had_settings: bool = false
var _settings_backup: PackedByteArray


func _ready() -> void:
	_had_settings = FileAccess.file_exists(SettingsServer.PATH)
	if _had_settings:
		_settings_backup = FileAccess.get_file_as_bytes(SettingsServer.PATH)
		var backup := FileAccess.open("/private/tmp/audio-infrastructure-settings.backup", FileAccess.WRITE)
		backup.store_buffer(_settings_backup)
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func() -> void: get_tree().quit(2))
	_run.call_deferred()


func _exit_tree() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if _had_settings:
		var file := FileAccess.open(SettingsServer.PATH, FileAccess.WRITE)
		file.store_buffer(_settings_backup)
	else:
		DirAccess.remove_absolute(SettingsServer.PATH)


func _check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		_failures += 1


func _run() -> void:
	# Keep this driver alive alongside the actual scenes under test.
	get_tree().current_scene = null
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	var music_bus := AudioServer.get_bus_index(&"Music")
	_check(sfx_bus > 0 and music_bus > 0, "SFX and Music have their own authored buses")
	if sfx_bus < 0 or music_bus < 0:
		get_tree().quit(1)
		return
	_check(AudioServer.get_bus_send(sfx_bus) == &"Master" and AudioServer.get_bus_send(music_bus) == &"Master", "Both groups route to Master")
	SettingsServer.set("sfx_volume", 0.25)
	SettingsServer.set("music_volume", 0.75)
	_check(is_equal_approx(AudioServer.get_bus_volume_linear(sfx_bus), 0.25), "SFX volume applies immediately")
	_check(is_equal_approx(AudioServer.get_bus_volume_linear(music_bus), 0.75), "Music volume is independent")
	SettingsServer.set("sfx_volume", 0.0)
	_check(AudioServer.is_bus_mute(sfx_bus) and not AudioServer.is_bus_mute(music_bus), "Zero mutes only SFX")
	SettingsServer.set("sfx_volume", 0.4)
	_check(not AudioServer.is_bus_mute(sfx_bus), "Raising volume unmutes SFX")
	var restored: Node = load("res://assets/autoload/settings_server.gd").new()
	add_child(restored)
	_check(restored.get("sfx_volume") == 0.4 and restored.get("music_volume") == 0.75, "Saved volumes load into a fresh settings instance")
	restored.free()
	_check_volume_defaults()
	_check(Audio.has_method("play_cue") and Audio.has_method("play_ui_cue"), "Named game cues are available through the audio helpers")
	await _check_sfx()
	await _check_cues()
	await _check_empty_music_start()
	await _check_music()
	await _check_scenes_and_menu()
	await _check_new_runs()
	await _wait()
	get_tree().quit(1 if _failures else 0)


func _wait(seconds: float = 0.1) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _check_cues() -> void:
	var valid_pack := true
	for cue in Sfx.Cue.values():
		var sound: Dictionary = Sfx.SOUNDS[cue]
		var stream := sound.stream as AudioStreamWAV
		var max_length := 1.5
		if cue in [Sfx.Cue.BATTLE_START, Sfx.Cue.BATTLE_WIN, Sfx.Cue.RUN_WIN, Sfx.Cue.RUN_LOSS]:
			max_length = 4.0
		elif cue == Sfx.Cue.HARVEST:
			max_length = 2.0
		valid_pack = valid_pack and stream != null and stream.get_length() > 0.0 and stream.get_length() <= max_length
		valid_pack = valid_pack and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED
	_check(valid_pack, "Every named cue loads a short, non-looping sound")
	Audio.stop_gameplay_sfx()
	var hit := Audio.play_cue(Sfx.Cue.HIT_BLUNT)
	_check(hit != null and hit.bus == &"SFX" and hit.playing, "Combat cues play through the SFX group")
	_check(Audio.play_cue(Sfx.Cue.HIT_BLUNT) == null, "Repeated simultaneous impacts are limited")
	_check(Audio.play_cue(Sfx.Cue.BLOCK) != null, "Different combat cues can overlap")
	Engine.time_scale = 4.0
	await _wait(0.1)
	_check(Audio.play_cue(Sfx.Cue.HIT_BLUNT) != null, "Impact spacing expires in real time during fast-forward")
	Engine.time_scale = 1.0
	get_tree().paused = true
	_check(Audio.play_cue(Sfx.Cue.REVIVE) == null, "New gameplay cues are ignored while paused")
	var ui := Audio.play_ui_cue(Sfx.Cue.SELECT)
	_check(ui != null and ui.bus == &"SFX" and ui.playing, "UI cues remain available while paused")
	get_tree().paused = false
	_check(Audio.play_cue(Sfx.Cue.REVIVE) != null, "An ignored paused request does not consume a cue's cooldown")
	Audio.stop_gameplay_sfx()
	_check(Audio.play_cue(Sfx.Cue.REVIVE) != null, "Resetting gameplay effects clears old scene cooldowns")
	Audio.stop_gameplay_sfx()
	# Dynamic controls use the same automatic wiring as rebuilt Shop/menu buttons.
	var button := Button.new()
	button.text = "Audio check"
	button.position = Vector2(30, 30)
	button.size = Vector2(160, 60)
	add_child(button)
	await _click(button)
	var click_played := false
	for node in Audio.get_children():
		if node is AudioStreamPlayer and node.stream == Sfx.SOUNDS[Sfx.Cue.UI_CLICK].stream:
			click_played = true
	_check(click_played, "A mouse click on a dynamically created button triggers UI audio")
	button.queue_free()
	await _wait(0.2)


func _check_volume_defaults() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SettingsServer.PATH)
	cfg.erase_section("audio")
	cfg.save(SettingsServer.PATH)
	var defaults: Node = load("res://assets/autoload/settings_server.gd").new()
	add_child(defaults)
	_check(defaults.get("sfx_volume") == 1.0 and defaults.get("music_volume") == 1.0, "Existing settings without audio keys default both groups to 100 percent")
	defaults.free()
	cfg.set_value("audio", "sfx_volume", "invalid")
	cfg.set_value("audio", "music_volume", -3.0)
	cfg.save(SettingsServer.PATH)
	var repaired: Node = load("res://assets/autoload/settings_server.gd").new()
	add_child(repaired)
	_check(repaired.get("sfx_volume") == 1.0 and repaired.get("music_volume") == 0.0, "Malformed preferences default safely and negative volume clamps to mute")
	repaired.set("music_volume", 3.0)
	_check(repaired.get("music_volume") == 1.0, "Volume cannot exceed 100 percent")
	repaired.free()
	SettingsServer.set("sfx_volume", 0.4)
	SettingsServer.set("music_volume", 0.75)


func _tone(seconds: float = 2.0) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(int(seconds * stream.mix_rate) * 2)
	for i in int(seconds * stream.mix_rate):
		samples.encode_s16(i * 2, int(sin(TAU * 220.0 * i / stream.mix_rate) * 2000))
	stream.data = samples
	return stream


func _check_sfx() -> void:
	var audio := get_node_or_null("/root/Audio")
	_check(audio != null and audio.has_method("play_sfx"), "Persistent audio service can play SFX")
	if audio == null:
		return
	var clip := _tone()
	var first: AudioStreamPlayer = audio.call("play_sfx", clip)
	var second: AudioStreamPlayer = audio.call("play_sfx", clip)
	await _wait()
	_check(first != second and first.playing and second.playing, "Two gameplay effects overlap")
	_check(first.bus == &"SFX" and second.bus == &"SFX", "Gameplay effects route through SFX volume")
	get_tree().paused = true
	await _wait()
	var ui: AudioStreamPlayer = audio.call("play_ui_sfx", clip)
	await _wait()
	_check(first.stream_paused and second.stream_paused, "Gameplay effects pause with gameplay")
	_check(ui.playing and not ui.stream_paused and ui.bus == &"SFX", "UI effects play through the same volume group while paused")
	_check(audio.call("play_sfx", clip) == null, "Paused gameplay cannot start a new effect")
	get_tree().paused = false
	await _wait()
	_check(not first.stream_paused and first.playing, "Gameplay effects resume")
	var voices: Array[AudioStreamPlayer] = []
	for i in 40:
		var voice: AudioStreamPlayer = audio.call("play_sfx", clip)
		if voice not in voices:
			voices.append(voice)
	_check(voices.size() <= 16, "Burst of gameplay effects uses at most 16 reusable voices")
	audio.call("stop_gameplay_sfx")
	_check(not first.playing and not second.playing, "Gameplay effects can be cleared without stopping UI audio")
	_check(ui.playing, "UI effect survives gameplay clear")
	ui.stop()
	_check_sfx_pitch(audio, clip)
	# Let the mixer finish this deliberately large burst before testing music.
	await _wait()


func _check_sfx_pitch(audio: Node, clip: AudioStream) -> void:
	for helper in [&"play_sfx", &"play_ui_sfx"]:
		var pitches: Array[float] = []
		var in_range := true
		var players: Array[AudioStreamPlayer] = []
		seed(7341)
		var expected_random := randf()
		seed(7341)
		for i in 32:
			var player: AudioStreamPlayer = audio.call(helper, clip)
			pitches.append(player.pitch_scale)
			in_range = in_range and player.pitch_scale >= 0.9 and player.pitch_scale <= 1.1
			if player not in players:
				players.append(player)
		_check(in_range and pitches.min() < pitches.max(), "%s randomizes every playback within 10 percent of normal pitch" % helper)
		_check(randf() == expected_random, "%s pitch randomness leaves gameplay RNG unchanged" % helper)
		var custom_in_range := true
		var fixed_pitch := true
		for i in 32:
			var custom: AudioStreamPlayer = audio.call(helper, clip, 0.0, 0.02)
			custom_in_range = custom_in_range and custom.pitch_scale >= 0.98 and custom.pitch_scale <= 1.02
		for i in 32:
			var fixed: AudioStreamPlayer = audio.call(helper, clip, 0.0, 0.0)
			fixed_pitch = fixed_pitch and fixed.pitch_scale == 1.0
		_check(custom_in_range, "%s accepts a custom pitch variation" % helper)
		_check(fixed_pitch, "%s zero variation resets reused voices to normal pitch" % helper)
		var safe_pitch := true
		for variation in [-1.0, 5.0, NAN, INF]:
			var player: AudioStreamPlayer = audio.call(helper, clip, 0.0, variation)
			safe_pitch = safe_pitch and is_finite(player.pitch_scale) and player.pitch_scale > 0.0 and player.pitch_scale <= 1.99
		_check(safe_pitch, "%s keeps pitch valid for out-of-range variation" % helper)
		for player in players:
			player.stop()


func _check_empty_music_start() -> void:
	Audio.base_music = null
	Audio.battle_music = _tone(20.0)
	_check(Audio.play_base_music() == null, "An initial empty Base slot stays silent")
	var battle := Audio.play_battle_music(true)
	await _wait(0.65)
	_check(is_equal_approx(battle.volume_db, -7.0), "First audible Battle music fades in at minus 7 dB")
	Audio.play_battle_music(true)
	await _wait(1.0)
	_check(battle.volume_linear > 0.18 and battle.volume_linear < 0.27, "A rematch still uses two seconds when Base has never played")
	Audio.stop_music()
	await _wait(0.6)


func _check_music() -> void:
	var base_clip := _tone(0.2)
	Audio.base_music = base_clip
	Audio.battle_music = _tone(60.0)
	var base := Audio.play_base_music()
	await _wait(0.65)
	_check(base.playing and base.bus == &"Music", "Base music loops and routes through the Music volume control")
	_check(is_equal_approx(base.volume_linear, 1.0), "Initial playback fades in from silence")
	_check(base_clip.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Music looping leaves the authored stream unchanged")
	_check(Audio.play_base_music() == base and is_equal_approx(base.volume_linear, 1.0), "Selecting the current track preserves playback without another fade")
	Audio.stop_music()
	await _wait(0.6)
	Audio.base_music = _tone(60.0)
	base = Audio.play_base_music()
	await _wait(0.6)
	var base_position := base.get_playback_position()
	get_tree().paused = true
	Engine.time_scale = 0.05
	var battle := Audio.play_battle_music(true)
	await _wait(1.0)
	_check(base.volume_linear > 0.4 and base.volume_linear < 0.6 and battle.volume_linear > 0.18 and battle.volume_linear < 0.27, "Base-to-Battle crossfade is halfway through after one real-time second")
	await _wait(1.15)
	_check(base.stream_paused and is_zero_approx(base.volume_linear) and is_equal_approx(battle.volume_db, -7.0), "After two seconds only Battle is audible and Base is paused")
	_check(base.get_playback_position() > base_position, "Base continues playing until its fade-out completes")
	base_position = base.get_playback_position()
	await _wait(0.3)
	_check(absf(base.get_playback_position() - base_position) < 0.05, "Base playback position stays fixed while Battle plays")
	_check(not battle.stream_paused and battle.pitch_scale == 1.0, "Music remains unpaused at normal pitch during gameplay pause and hitstop")
	Engine.time_scale = 4.0
	var before := battle.get_playback_position()
	await _wait(0.2)
	var elapsed := battle.get_playback_position() - before
	_check(elapsed > 0.1 and elapsed < 0.4, "4x combat speed leaves music playback at real-time speed")
	_check(Audio.play_base_music() == base and absf(base.get_playback_position() - base_position) < 0.1, "Base resumes from its paused position without restarting")
	await _wait(4.0)
	_check(base.volume_linear > 0.4 and base.volume_linear < 0.6 and battle.volume_linear > 0.18 and battle.volume_linear < 0.27, "Battle-to-Base crossfade is halfway through after four real-time seconds")
	Audio.play_base_music()
	await _wait(4.15)
	_check(is_equal_approx(base.volume_linear, 1.0) and battle.stream_paused and is_zero_approx(battle.volume_linear), "The eight-second fade completes without restarting on repeated Base requests")
	_check(base.get_playback_position() > base_position + 7.5, "Base advances normally after resuming")
	before = battle.get_playback_position()
	_check(Audio.play_battle_music(true) == battle and battle.get_playback_position() < 0.1, "A new Battle restarts its existing player from the beginning")
	await _wait(1.0)
	_check(battle.volume_linear > 0.18 and battle.volume_linear < 0.27, "A restarted Battle uses the two-second crossfade")
	Audio.play_battle_music()
	await _wait(1.15)
	_check(battle.get_playback_position() < before and is_equal_approx(battle.volume_db, -7.0) and base.stream_paused, "Repeated Battle requests preserve playback and the in-progress fade")
	Audio.play_battle_music(true)
	_check(battle.get_playback_position() < 0.1, "A rematch restarts music even when Battle is already selected")
	await _wait(2.15)
	_check(is_equal_approx(battle.volume_db, -7.0) and is_zero_approx(base.volume_linear), "A rematch fades Battle to its reduced volume")
	Audio.play_base_music()
	await _wait(0.2)
	var base_volume := base.volume_linear
	var battle_volume := battle.volume_linear
	Audio.play_battle_music()
	_check(is_equal_approx(base.volume_linear, base_volume) and is_equal_approx(battle.volume_linear, battle_volume), "An interrupted crossfade starts from the current volumes")
	await _wait(2.15)
	_check(base.stream_paused and is_zero_approx(base.volume_linear) and is_equal_approx(battle.volume_db, -7.0), "Interrupted crossfades settle on the last requested track")
	Audio.stop_music()
	await _wait(0.1)
	base_position = base.get_playback_position()
	Audio.play_base_music()
	await _wait(0.2)
	_check(not base.stream_paused and base.get_playback_position() > base_position and base.volume_linear < 0.1 and battle.volume_linear > 0.22, "Interrupting a stop resumes Base with the slow crossfade")
	Audio.stop_music()
	await _wait(0.6)
	_check(not base.has_stream_playback() and not battle.has_stream_playback(), "Explicit stop clears playback of both songs")
	battle = Audio.play_battle_music(true)
	await _wait(0.6)
	_check(not base.has_stream_playback() and is_equal_approx(battle.volume_db, -7.0), "Direct Battle entry starts only Battle music")
	Audio.base_music = null
	_check(Audio.play_base_music() == null, "An empty Base slot remains valid")
	await _wait(8.15)
	_check(is_zero_approx(battle.volume_linear) and battle.stream_paused, "Selecting an empty Base slot still fades out Battle music")
	Audio.stop_music()
	await _wait(0.6)
	get_tree().paused = false
	Engine.time_scale = 1.0


func _scene(path: String) -> Node:
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	await _wait(0.65)
	return get_tree().current_scene


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		get_tree().root.push_input(event, true)
	await _wait(0.04)


func _click(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		get_tree().root.push_input(event, true)
	await _wait(0.04)


func _check_scenes_and_menu() -> void:
	Audio.base_music = _tone(60.0)
	Audio.battle_music = _tone(60.0)
	await _scene("res://assets/title/title.tscn")
	var base_music := Audio.play_base_music()
	_check(base_music.playing and is_equal_approx(base_music.volume_linear, 1.0), "Title selects Base music")
	var position := base_music.get_playback_position()
	var base := await _scene("res://assets/base/base.tscn")
	_check(base_music.get_playback_position() > position, "Title to Base preserves playback")
	await _check_menu(base.get_node("RunMenu") as RunMenu)
	GameState.clear_pending_seal_choice()
	GameState.troop.seed_if_empty(StarterPackages.build_units(&"great_sword_spear"))
	var battle_music := Audio.play_battle_music(true)
	await _wait(2.15)
	position = battle_music.get_playback_position()
	var sandbox := await _scene("res://assets/combat/combat_sandbox/combat_sandbox.tscn")
	_check(battle_music.get_playback_position() < position and battle_music.volume_linear > 0.10 and battle_music.volume_linear < 0.22, "Entering a new combat scene restarts Battle with a two-second fade")
	var restart: Button
	for button in sandbox.get_node("%MatchupButtons").get_children():
		if button is Button and button.text == "Restart":
			restart = button
	if restart != null:
		await _click(restart)
	_check(restart != null and battle_music.get_playback_position() < 0.2, "Restarting combat in the same scene restarts Battle music")
	var effect := Audio.play_sfx(_tone(60.0))
	get_tree().paused = true
	await _scene("res://assets/day_summary/day_summary.tscn")
	get_tree().paused = false
	_check(not effect.playing, "Leaving a paused Battle clears its gameplay effects")
	# Start each result from a settled Battle track so every scene must initiate its own fade.
	for path in ["day_summary/day_summary", "victory/victory", "game_over/game_over"]:
		Audio.play_battle_music(true)
		await _wait(2.15)
		position = base_music.get_playback_position()
		await _scene("res://assets/" + path + ".tscn")
		_check(not base_music.stream_paused and base_music.get_playback_position() > position and base_music.volume_linear > 0.04 and base_music.volume_linear < 0.2 and battle_music.volume_linear > 0.38 and battle_music.volume_linear < 0.44, path + " starts the eight-second return to Base music")
	position = base_music.get_playback_position()
	await _scene("res://assets/base/base.tscn")
	_check(base_music.get_playback_position() > position and base_music.volume_linear > 0.12 and base_music.volume_linear < 0.3, "Result-to-Base entry preserves playback and continues the existing fade")
	await _wait(6.9)
	_check(is_equal_approx(base_music.volume_linear, 1.0) and battle_music.stream_paused and is_zero_approx(battle_music.volume_linear), "The result-screen crossfade finishes on its original eight-second schedule in Base")
	effect = Audio.play_sfx(_tone(20.0))
	_check(effect != null and effect.playing, "New scene can play effects after previous owner was freed")
	await _scene("res://assets/title/title.tscn")
	_check(not effect.playing, "New scene effects also clear on the next scene exit")
	var ready_scene := await _scene("res://.scratch/audio-infrastructure/ready_effect.tscn")
	effect = ready_scene.get("effect") as AudioStreamPlayer
	_check(effect.playing, "A scene can start an effect during ready")
	await _scene("res://assets/title/title.tscn")
	_check(not effect.playing, "Effects started during ready clear on scene exit")
	Audio.stop_music()
	await _wait(0.6)


func _check_new_runs() -> void:
	Audio.base_music = _tone(60.0)
	Audio.battle_music = _tone(60.0)
	for path in ["title/title", "game_over/game_over", "victory/victory"]:
		if path != "title/title":
			Audio.play_battle_music(true)
			await _wait(2.15)
		var screen := await _scene("res://assets/" + path + ".tscn")
		await _wait(0.3)
		var base := Audio.play_base_music()
		_check(base.get_playback_position() > 0.5, path + " has existing Base playback before a new Run")
		await _click(screen.get_node("%NewRunButton"))
		_check(base.get_playback_position() < 0.2, path + " New Run restarts Base music from the beginning")
		await get_tree().scene_changed
		await _wait(0.65)
		_check(get_tree().current_scene.scene_file_path == GameState.BASE_SCENE_PATH and base.get_playback_position() > 0.8 and is_equal_approx(base.volume_linear, 1.0), "Base entry continues the restarted song and finishes its short fade-in")
		GameState.clear_pending_seal_choice()
		GameState.troop.seed_if_empty(StarterPackages.build_units(&"great_sword_spear"))
	await _scene("res://assets/title/title.tscn")
	Audio.stop_music()
	await _wait(0.6)


func _check_menu(menu: RunMenu) -> void:
	await _click(menu.get_node("%GearButton"))
	await _click(menu.get_node("%SettingsButton"))
	var sfx := menu.get_node_or_null("%SFXVolume") as HSlider
	var music := menu.get_node_or_null("%MusicVolume") as HSlider
	_check(sfx != null and music != null, "Settings contains both volume sliders")
	if sfx == null or music == null:
		menu.close_menu()
		return
	_check(sfx.value == 40.0 and music.value == 75.0, "Sliders show the saved percentages")
	await _click(sfx)
	var before := sfx.value
	await _key(KEY_LEFT)
	_check(sfx.value < before and get_viewport().gui_get_focus_owner() == sfx, "Left arrow adjusts SFX without moving focus")
	_check(is_equal_approx(SettingsServer.get("sfx_volume"), sfx.value / 100.0), "Slider input immediately changes saved volume")
	await _key(KEY_TAB)
	_check(get_viewport().gui_get_focus_owner() == music, "Tab reaches Music")
	await _key(KEY_RIGHT)
	_check(music.value == 76.0 and SettingsServer.get("music_volume") == 0.76, "Keyboard adjusts Music independently")
	await _key(KEY_TAB)
	_check(get_viewport().gui_get_focus_owner() == menu.get_node("%BackButton"), "Tab reaches Back after Music")
	await _key(KEY_TAB)
	_check(get_viewport().gui_get_focus_owner() == menu.get_node("%FullscreenButton"), "Settings focus wraps inside the panel")
	_check(get_tree().paused, "Volume controls leave gameplay paused")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/private/tmp/audio-settings.png")
	sfx.grab_focus()
	sfx.value = 0.0
	await _key(KEY_LEFT)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")) and get_viewport().gui_get_focus_owner() == sfx, "Slider zero mutes SFX and left at the boundary keeps focus")
	sfx.value = 100.0
	await _key(KEY_RIGHT)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")) and get_viewport().gui_get_focus_owner() == sfx, "Slider 100 unmutes SFX and right at the boundary keeps focus")
	await _key(KEY_ESCAPE)
	var back_sound := false
	for node in Audio.get_children():
		if node is AudioStreamPlayer and node.playing and node.stream == Sfx.SOUNDS[Sfx.Cue.UI_CLOSE].stream:
			back_sound = true
	_check(back_sound, "Escape back from Settings plays navigation feedback")
	await _key(KEY_ESCAPE)
	_check(not get_tree().paused, "Escape still resumes gameplay")
