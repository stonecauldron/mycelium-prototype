extends "res://.scratch/audio-infrastructure/runtime_check.gd"


func _run() -> void:
	# Reuse the agreed playback/UI checks without depending on music authoring.
	get_tree().current_scene = null
	SettingsServer.set("sfx_volume", 0.4)
	SettingsServer.set("music_volume", 0.75)
	await _check_sfx()
	await _check_cues()
	var menu: RunMenu = load("res://assets/ui/run_menu/run_menu.tscn").instantiate()
	add_child(menu)
	await _check_menu(menu)
	menu.queue_free()
	Audio.stop_gameplay_sfx()
	Audio.stop_music()
	await _wait(0.6)
	get_tree().quit(1 if _failures else 0)
