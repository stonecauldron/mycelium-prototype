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
	get_tree().create_timer(45.0, true, false, true).timeout.connect(func() -> void: get_tree().quit(2))
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
	await _check_sfx()
	await _check_music()
	await _check_scenes_and_menu()
	await _wait()
	get_tree().quit(1 if _failures else 0)


func _wait(seconds: float = 0.1) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


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


func _check_music() -> void:
	var audio := get_node_or_null("/root/Audio")
	_check(audio != null and audio.has_method("play_base_music"), "Base and Battle music can be selected")
	if audio == null or not audio.has_method("play_base_music"):
		return
	var base_clip := _tone(0.2)
	audio.set("base_music", base_clip)
	audio.set("battle_music", _tone(20.0))
	var base: AudioStreamPlayer = audio.call("play_base_music")
	await _wait(0.65)
	_check(base.playing, "Base track loops beyond its length")
	_check(base.bus == &"Music", "Base track routes through the Music volume control")
	_check(is_equal_approx(base.volume_linear, 1.0), "Base track finishes fading in")
	_check(base_clip.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Music looping leaves the authored stream unchanged")
	var same: AudioStreamPlayer = audio.call("play_base_music")
	_check(same == base and is_equal_approx(same.volume_linear, 1.0), "Selecting the current track preserves playback without another fade")
	audio.set("base_music", _tone(20.0))
	base = audio.call("play_base_music")
	await _wait(0.6)
	var base_position := base.get_playback_position()
	get_tree().paused = true
	Engine.time_scale = 0.05
	var battle: AudioStreamPlayer = audio.call("play_battle_music")
	await _wait(0.12)
	_check(base.playing and battle.playing and base.volume_linear > 0.2 and battle.volume_linear > 0.0, "Battle starts as Base music lowers in volume")
	await _wait(0.55)
	_check(base.playing and is_equal_approx(base.volume_linear, 0.2) and battle.playing and is_equal_approx(battle.volume_linear, 1.0), "Battle mix keeps Base at 20 percent during pause and hitstop")
	_check(base.get_playback_position() > base_position, "Base music keeps advancing through the Battle transition")
	_check(not battle.stream_paused and battle.pitch_scale == 1.0, "Music remains unpaused at normal pitch")
	Engine.time_scale = 4.0
	var before := battle.get_playback_position()
	await _wait(0.2)
	var elapsed := battle.get_playback_position() - before
	_check(elapsed > 0.1 and elapsed < 0.4, "4x combat speed leaves music playback at real-time speed")
	before = battle.get_playback_position()
	base_position = base.get_playback_position()
	var returned_base: AudioStreamPlayer = audio.call("play_base_music")
	await _wait(0.6)
	_check(returned_base == base and base.playing and base.get_playback_position() > base_position and is_equal_approx(base.volume_linear, 1.0), "Returning to Base restores its existing player and position at full volume")
	_check(is_zero_approx(battle.volume_linear), "Battle track is silent after returning to Base")
	before = battle.get_playback_position()
	var returned_battle: AudioStreamPlayer = audio.call("play_battle_music", true)
	await _wait(0.6)
	_check(returned_battle == battle and battle.get_playback_position() < before and is_equal_approx(battle.volume_linear, 1.0), "A new Battle restarts its music from the beginning and fades it in")
	audio.call("play_battle_music", true)
	_check(battle.get_playback_position() < 0.1, "A rematch restarts music even when Battle is already foreground")
	await _wait(0.6)
	_check(is_equal_approx(battle.volume_linear, 1.0) and is_equal_approx(base.volume_linear, 0.2), "A rematch restores the Battle mix after restarting")
	for i in 8:
		audio.call("play_base_music" if i % 2 == 0 else "play_battle_music")
		await _wait(0.02)
	await _wait(0.6)
	_check(battle.playing and is_equal_approx(battle.volume_linear, 1.0) and base.playing and is_equal_approx(base.volume_linear, 0.2), "Interrupted changes settle on the last requested mix")
	before = battle.get_playback_position()
	audio.call("stop_music")
	await _wait(0.1)
	audio.call("play_base_music")
	await _wait(0.6)
	_check(base.playing and battle.playing and battle.get_playback_position() > before and is_zero_approx(battle.volume_linear), "Interrupting a stop restores Base music and silences Battle music")
	audio.set("base_music", null)
	audio.call("play_base_music")
	await _wait(0.6)
	_check(not base.playing and is_zero_approx(battle.volume_linear), "An empty Base slot does not make Battle music audible in Base")
	audio.call("stop_music")
	await _wait(0.6)
	_check(not base.playing and not battle.playing, "Explicit stop fades out and stops both tracks")
	audio.set("base_music", base_clip)
	audio.call("play_base_music")
	await _wait(0.6)
	_check(base.playing and not battle.playing, "Fresh Base playback waits until a Battle to start Battle music")
	audio.call("stop_music")
	await _wait(0.6)
	audio.call("play_battle_music")
	await _wait(0.6)
	_check(base.playing and is_equal_approx(base.volume_linear, 0.2) and battle.playing and is_equal_approx(battle.volume_linear, 1.0), "Direct Battle entry starts both tracks at the Battle mix")
	audio.call("stop_music")
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
	var audio := get_node_or_null("/root/Audio")
	if audio == null or not audio.has_method("play_base_music"):
		return
	audio.set("base_music", _tone(20.0))
	audio.set("battle_music", _tone(20.0))
	var base_music: AudioStreamPlayer = audio.call("play_base_music")
	var battle_music: AudioStreamPlayer = audio.call("play_battle_music")
	await _scene("res://assets/title/title.tscn")
	_check(base_music.playing and is_equal_approx(base_music.volume_linear, 1.0) and is_zero_approx(battle_music.volume_linear), "Title brings Base music forward and silences Battle music")
	var position := base_music.get_playback_position()
	var base := await _scene("res://assets/base/base.tscn")
	_check(base_music.playing and base_music.get_playback_position() > position, "Title to Base keeps the same music position")
	await _check_menu(base.get_node("RunMenu") as RunMenu)
	# Finish the Run setup before simulating battle/result scene transitions.
	GameState.clear_pending_seal_choice()
	GameState.troop.seed_if_empty(StarterPackages.build_units(&"great_sword_spear"))
	position = battle_music.get_playback_position()
	var sandbox := await _scene("res://assets/combat/combat_sandbox/combat_sandbox.tscn")
	_check(battle_music.playing and is_equal_approx(battle_music.volume_linear, 1.0) and base_music.playing and is_equal_approx(base_music.volume_linear, 0.2), "Starting a Battle brings Battle music forward and lowers Base music")
	_check(battle_music.get_playback_position() < position, "Entering a new combat scene restarts Battle music")
	var restart: Button
	for button in sandbox.get_node("%MatchupButtons").get_children():
		if button is Button and button.text == "Restart":
			restart = button
	if restart != null:
		await _click(restart)
	_check(restart != null and battle_music.get_playback_position() < 0.2, "Restarting combat in the same scene restarts Battle music")
	await _wait(0.6)
	var effect: AudioStreamPlayer = audio.call("play_sfx", _tone(20.0))
	get_tree().paused = true
	await _scene("res://assets/day_summary/day_summary.tscn")
	get_tree().paused = false
	_check(not effect.playing, "Leaving a paused Battle clears its gameplay effects")
	for path in ["day_summary/day_summary", "victory/victory", "game_over/game_over"]:
		position = battle_music.get_playback_position()
		await _scene("res://assets/" + path + ".tscn")
		_check(battle_music.playing and battle_music.get_playback_position() > position and is_equal_approx(battle_music.volume_linear, 1.0) and is_equal_approx(base_music.volume_linear, 0.2), path + " continues the Battle mix")
	await _scene("res://assets/base/base.tscn")
	_check(base_music.playing and is_equal_approx(base_music.volume_linear, 1.0) and is_zero_approx(battle_music.volume_linear), "Returning to Base restores Base music and silences Battle music")
	effect = audio.call("play_sfx", _tone(20.0))
	_check(effect != null and effect.playing, "New scene can play effects after previous owner was freed")
	await _scene("res://assets/title/title.tscn")
	_check(not effect.playing, "New scene effects also clear on the next scene exit")
	var ready_scene := await _scene("res://.scratch/audio-infrastructure/ready_effect.tscn")
	effect = ready_scene.get("effect") as AudioStreamPlayer
	_check(effect.playing, "A scene can start an effect during ready")
	await _scene("res://assets/title/title.tscn")
	_check(not effect.playing, "Effects started during ready clear on scene exit")
	audio.call("stop_music")
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
	await _key(KEY_ESCAPE)
	_check(not get_tree().paused, "Escape still resumes gameplay")
