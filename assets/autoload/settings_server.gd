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
var _fullscreen: bool = false


func _ready() -> void:
	_fullscreen = is_fullscreen()
	_load()


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	]


func set_fullscreen(enabled: bool) -> void:
	_apply_fullscreen(enabled)
	if not OS.has_feature("web"):
		_fullscreen = enabled
		_save()


func _apply_fullscreen(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)
	# macOS restores its window decorations as part of its asynchronous transition.
	if not enabled and not OS.has_feature("macos"):
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)


func _load() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(PATH)
	if err != OK:
		return
	_show_tutorial = cfg.get_value(SECTION, "show_tutorial", true)
	if not OS.has_feature("web") and cfg.has_section_key("display", "fullscreen"):
		_fullscreen = cfg.get_value("display", "fullscreen", _fullscreen)
		_apply_fullscreen(_fullscreen)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # Preserve other keys if present; ignore missing file.
	cfg.set_value(SECTION, "show_tutorial", _show_tutorial)
	if not OS.has_feature("web"):
		cfg.set_value("display", "fullscreen", _fullscreen)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("SettingsServer: save failed (%s)" % error_string(err))
