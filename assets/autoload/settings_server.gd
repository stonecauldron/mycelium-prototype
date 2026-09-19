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

var master_volume: float = 1.0:
	get:
		return _master_volume
	set(value):
		_master_volume = _valid_volume(value)
		_apply_volume(&"Master", _master_volume)
		_save()

var sfx_volume: float = 1.0:
	get:
		return _sfx_volume
	set(value):
		_sfx_volume = _valid_volume(value)
		_apply_volume(&"SFX", _sfx_volume)
		_save()

var music_volume: float = 1.0:
	get:
		return _music_volume
	set(value):
		_music_volume = _valid_volume(value)
		_apply_volume(&"Music", _music_volume)
		_save()

var _show_tutorial: bool = true
var _fullscreen: bool = false
var _master_volume: float = 1.0
var _sfx_volume: float = 1.0
var _music_volume: float = 1.0


func _ready() -> void:
	_fullscreen = is_fullscreen()
	_load()
	_apply_volume(&"Master", _master_volume)
	_apply_volume(&"SFX", _sfx_volume)
	_apply_volume(&"Music", _music_volume)


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
	_master_volume = _valid_volume(cfg.get_value("audio", "master_volume", 1.0))
	_sfx_volume = _valid_volume(cfg.get_value("audio", "sfx_volume", 1.0))
	_music_volume = _valid_volume(cfg.get_value("audio", "music_volume", 1.0))
	if not OS.has_feature("web") and cfg.has_section_key("display", "fullscreen"):
		_fullscreen = cfg.get_value("display", "fullscreen", _fullscreen)
		_apply_fullscreen(_fullscreen)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # Preserve other keys if present; ignore missing file.
	cfg.set_value(SECTION, "show_tutorial", _show_tutorial)
	cfg.set_value("audio", "master_volume", _master_volume)
	cfg.set_value("audio", "sfx_volume", _sfx_volume)
	cfg.set_value("audio", "music_volume", _music_volume)
	if not OS.has_feature("web"):
		cfg.set_value("display", "fullscreen", _fullscreen)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("SettingsServer: save failed (%s)" % error_string(err))


func _valid_volume(value: Variant) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return clampf(float(value), 0.0, 1.0)
	return 1.0


func _apply_volume(bus_name: StringName, volume: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		push_error("SettingsServer: missing audio bus %s" % bus_name)
		return
	AudioServer.set_bus_mute(bus, volume == 0.0)
	# Keep the gain finite at zero; the mute flag provides exact silence.
	AudioServer.set_bus_volume_linear(bus, maxf(volume, 0.0001))
