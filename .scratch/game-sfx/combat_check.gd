extends Node

var _heard: Dictionary[String, bool] = {}
var _failures: int = 0
var _recording := AudioEffectRecord.new()


func _ready() -> void:
	get_tree().create_timer(30.0, true, false, true).timeout.connect(func() -> void: get_tree().quit(2))
	_run.call_deferred()


func _process(_delta: float) -> void:
	for node in Audio.get_children():
		if node is AudioStreamPlayer and node.playing and node.stream != null and node.bus == &"SFX":
			_heard[node.stream.resource_path.get_file().get_basename()] = true


func _check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _run() -> void:
	get_tree().current_scene = null
	# Capture only the SFX bus; do not change or save the user's volume preferences.
	var bus := AudioServer.get_bus_index(&"SFX")
	AudioServer.set_bus_mute(bus, false)
	AudioServer.add_bus_effect(bus, _recording)
	_recording.set_recording_active(true)
	GameState.combat_fast_forward = 4
	get_tree().change_scene_to_file("res://assets/combat/combat_sandbox/combat_sandbox.tscn")
	await get_tree().scene_changed
	var sandbox := get_tree().current_scene
	await _wait(4.0)
	_check(_heard.has("battle_start"), "Battle start plays its cue")
	_check(_heard.has("slash") and _heard.has("hit_slash"), "Real melee combat emits attacks and impacts")
	var weapon := sandbox.get_node("%PlayerWeapon") as OptionButton
	var enemy := sandbox.get_node("%EnemyType") as OptionButton
	for i in enemy.item_count:
		if enemy.get_item_text(i) == "Stump":
			enemy.select(i)
	for choice in ["Bow", "Mortar", "Great Horn"]:
		for i in weapon.item_count:
			if weapon.get_item_text(i) == choice:
				weapon.select(i)
		(sandbox.get_node("%RunCustom") as Button).pressed.emit()
		await _wait(3.0)
	_check(_heard.has("bow"), "Bow releases use the bow sound")
	_check(_heard.has("throw") and _heard.has("explosion"), "Mortars throw and explode audibly")
	_check(_heard.has("horn"), "Great Horn uses its authored launch sound")
	_check(_heard.has("death"), "Fallen units emit a death pop")
	_recording.set_recording_active(false)
	var recording := _recording.get_recording()
	_check(recording != null and recording.get_length() > 10.0, "The audio mixer produces a combat SFX recording")
	if recording != null:
		recording.save_to_wav("/private/tmp/mycelium-combat-sfx.wav")
	AudioServer.remove_bus_effect(bus, 0)
	get_tree().change_scene_to_file("res://assets/title/title.tscn")
	await get_tree().scene_changed
	# Release MP3 decoder voices before shutting down the audio server.
	Audio.stop_music()
	await _wait(0.6)
	print("Observed combat cues: ", _heard.keys())
	get_tree().quit(1 if _failures else 0)
