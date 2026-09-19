extends Node

## Captures the real mixer after Master effects, including on Web/Stream.
var _failures: int = 0
var _report: Array[String] = []
var _capture: AudioEffectCapture
var _capture_index: int
var _settings_backup: PackedByteArray
var _had_settings: bool


func _ready() -> void:
	_had_settings = FileAccess.file_exists(SettingsServer.PATH)
	if _had_settings:
		_settings_backup = FileAccess.get_file_as_bytes(SettingsServer.PATH)
	if OS.has_feature("web"):
		var start := Button.new()
		start.text = "Run muted audio checks"
		start.position = Vector2(24, 24)
		start.size = Vector2(400, 80)
		add_child(start)
		await start.pressed
		start.queue_free()
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	var line := ("PASS: " if condition else "FAIL: ") + label
	print(line)
	_report.append(line)
	if not condition:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _peak() -> float:
	var peak := 0.0
	var frames := _capture.get_buffer(_capture.get_frames_available())
	for frame in frames:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	return peak


func _clear_players() -> void:
	Audio.stop_music()
	Audio.stop_gameplay_sfx()
	for child in Audio.get_children():
		if child is AudioStreamPlayer and child.bus == &"SFX":
			child.stop()
	await _wait(0.7)
	_capture.clear_buffer()


func _run() -> void:
	# Capture sits before the Master fader; silence browser test tones at output.
	if OS.has_feature("web"):
		AudioServer.set_bus_volume_db(0, -80.0)
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 5.0
	_capture_index = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, _capture)
	SettingsServer.sfx_volume = 1.0
	SettingsServer.music_volume = 1.0
	# The browser's start button is automatically wired to a UI click cue.
	await _clear_players()
	_check(ProjectSettings.get_setting("audio/general/default_playback_type.web") == 0,
		"Web uses Stream playback so Master/SFX effects are active")
	# A steady tone below the limiter threshold measures the actual fixed trim.
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.mix_rate = 44100
	tone.loop_mode = AudioStreamWAV.LOOP_FORWARD
	tone.loop_end = 44100
	var data := PackedByteArray()
	data.resize(44100 * 2)
	for i in 44100:
		data.encode_s16(i * 2, roundi(sin(TAU * 220.0 * i / 44100.0) * 8192.0))
	tone.data = data
	var player := Audio.play_sfx(tone, 0.0, 0.0)
	await _wait(0.6)
	var peak := _peak()
	var gain_db := linear_to_db(peak / 0.25)
	_check(peak > 0.0 and absf(gain_db + 6.0) < 0.15,
		"Master applies -6 dB at 100%% sliders (measured %.2f dB)" % gain_db)
	SettingsServer.sfx_volume = 0.5
	await _wait(0.3)
	_capture.clear_buffer()
	await _wait(0.3)
	var half_peak := _peak()
	_check(peak > 0.0 and absf(half_peak / peak - 0.5) < 0.01,
		"SFX slider scales the quieter mix independently")
	SettingsServer.sfx_volume = 0.0
	await _wait(0.3)
	_capture.clear_buffer()
	await _wait(0.3)
	_check(_peak() < 0.00001, "Zero SFX volume is silent")
	SettingsServer.sfx_volume = 1.0
	player.stop()
	await _clear_players()
	# Deliberate overdrive proves Master limits the sum, not just the SFX bus.
	player = Audio.play_sfx(tone, 24.0, 0.0)
	player.bus = &"Music"
	await _wait(0.6)
	peak = _peak()
	_check(peak > 0.1 and peak <= db_to_linear(-0.95),
		"Master limits an overloaded Music signal to -1 dB (peak %.2f dBFS)" % linear_to_db(peak))
	player.stop()
	await _clear_players()
	for speed in [1.0, 4.0]:
		Engine.time_scale = speed
		var music := Audio.play_battle_music(true)
		await _wait(0.7)
		_check(is_equal_approx(music.volume_db, -7.0), "Battle music settles at -7 dB at %dx" % int(speed))
		_capture.clear_buffer()
		var mixed_peak := 0.0
		for i in int(20 * speed):
			for cue in [Sfx.Cue.EXPLOSION, Sfx.Cue.HIT_BLUNT, Sfx.Cue.GREAT_HIT_SLASH,
					Sfx.Cue.SLASH, Sfx.Cue.BOW, Sfx.Cue.DEATH]:
				Audio.play_cue(cue)
			if i == 0:
				Audio.play_ui_cue(Sfx.Cue.BATTLE_WIN)
			await _wait(0.04 / speed)
			mixed_peak = maxf(mixed_peak, _peak())
		await _wait(1.0)
		mixed_peak = maxf(mixed_peak, _peak())
		_check(mixed_peak > 0.01 and mixed_peak <= db_to_linear(-0.95),
			"Actual music + crowded SFX at %dx stay below -1 dB (peak %.2f dBFS)" % [int(speed), linear_to_db(mixed_peak)])
		await _clear_players()
	Engine.time_scale = 1.0
	_check(_capture.get_discarded_frames() == 0, "No captured audio frames were lost")
	AudioServer.remove_bus_effect(0, _capture_index)
	AudioServer.set_bus_volume_db(0, 0.0)
	if _had_settings:
		var file := FileAccess.open(SettingsServer.PATH, FileAccess.WRITE)
		file.store_buffer(_settings_backup)
		file.close()
	else:
		DirAccess.remove_absolute(SettingsServer.PATH)
	print("AUDIO_MIX_RESULT: ", JSON.stringify({"failures": _failures, "checks": _report}))
	if OS.has_feature("web"):
		var label := Label.new()
		label.text = "Audio mix validation: %d failures\n\n%s" % [_failures, "\n".join(_report)]
		label.position = Vector2(24, 24)
		add_child(label)
	else:
		get_tree().quit(1 if _failures else 0)
