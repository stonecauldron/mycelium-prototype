extends Node

## Global hotkey: press P to capture the current viewport to user://screenshots/.

const SAVE_DIR := "user://screenshots"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _shortcut_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_P and key.physical_keycode != KEY_P:
		return
	_capture()
	get_viewport().set_input_as_handled()


func _capture() -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_warning("Screenshot: viewport image unavailable")
		return

	var abs_dir := ProjectSettings.globalize_path(SAVE_DIR)
	var err := DirAccess.make_dir_recursive_absolute(abs_dir)
	if err != OK:
		push_warning("Screenshot: could not create %s (error %s)" % [SAVE_DIR, error_string(err)])
		return

	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "%s/screenshot_%s.png" % [SAVE_DIR, stamp]
	err = image.save_png(path)
	if err != OK:
		push_warning("Screenshot: save failed (%s)" % error_string(err))
		return

	print("Screenshot saved: ", ProjectSettings.globalize_path(path))
