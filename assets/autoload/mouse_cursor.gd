extends Node

const _POINT := preload("res://assets/ui/cursors/hand_point.svg")
const _POINT_PRESSED := preload("res://assets/ui/cursors/hand_point_pressed.svg")
const _OPEN := preload("res://assets/ui/cursors/hand_open.svg")
const _CLOSED := preload("res://assets/ui/cursors/hand_closed.svg")
const _POINT_HOTSPOT := Vector2(22, 12)
const _GRAB_HOTSPOT := Vector2(32, 32)

var _point_pressed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_point_cursor(_POINT)
	# Keep drag images fixed so they also work in macOS's embedded game view.
	Input.set_custom_mouse_cursor(_OPEN, Input.CURSOR_DRAG, _GRAB_HOTSPOT)
	Input.set_custom_mouse_cursor(_CLOSED, Input.CURSOR_CAN_DROP, _GRAB_HOTSPOT)
	Input.set_custom_mouse_cursor(_CLOSED, Input.CURSOR_FORBIDDEN, _GRAB_HOTSPOT)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_set_point_pressed(event.pressed)


func _set_point_pressed(pressed: bool) -> void:
	if _point_pressed == pressed:
		return
	_point_pressed = pressed
	_set_point_cursor(_POINT_PRESSED if pressed else _POINT)


func _set_point_cursor(texture: Texture2D) -> void:
	# Live image changes may not appear in macOS's embedded game view.
	for shape in range(Input.CURSOR_ARROW, Input.CURSOR_HELP + 1):
		if shape in [Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP, Input.CURSOR_FORBIDDEN]:
			continue
		Input.set_custom_mouse_cursor(texture, shape as Input.CursorShape, _POINT_HOTSPOT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_set_point_pressed(false)
	elif what == NOTIFICATION_DRAG_BEGIN:
		# Godot chooses CAN_DROP/FORBIDDEN over controls. Cover empty space too.
		Input.set_default_cursor_shape(Input.CURSOR_CAN_DROP)
	elif what == NOTIFICATION_DRAG_END:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
