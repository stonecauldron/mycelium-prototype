extends Node

## Persists user preferences across runs (separate from GameState run data).

const PATH := "user://settings.cfg"
const SECTION := "general"

var show_tutorial: bool = true:
	get:
		return _show_tutorial
	set(value):
		if _show_tutorial == value:
			return
		_show_tutorial = value
		_save()

var _show_tutorial: bool = true


func _ready() -> void:
	_load()


func _load() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(PATH)
	if err != OK:
		return
	_show_tutorial = cfg.get_value(SECTION, "show_tutorial", true)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # Preserve other keys if present; ignore missing file.
	cfg.set_value(SECTION, "show_tutorial", _show_tutorial)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("SettingsServer: save failed (%s)" % error_string(err))
