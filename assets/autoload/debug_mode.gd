extends Node

## Global hotkey: press ~ (grave / tilde key) to grant debug cheats.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _shortcut_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if not _is_debug_hotkey(key):
		return
	GameState.activate_debug_cheats()
	get_viewport().set_input_as_handled()


func _is_debug_hotkey(key: InputEventKey) -> bool:
	# US `~` key: KEY_QUOTELEFT unshifted, KEY_ASCIITILDE with Shift.
	return (
		key.physical_keycode == KEY_QUOTELEFT
		or key.keycode == KEY_QUOTELEFT
		or key.keycode == KEY_ASCIITILDE
		or key.physical_keycode == KEY_ASCIITILDE
	)
