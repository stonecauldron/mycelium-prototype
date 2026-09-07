extends Node

const _POINT := preload("res://assets/ui/cursors/hand_point.svg")
const _OPEN := preload("res://assets/ui/cursors/hand_open.svg")
const _CLOSED := preload("res://assets/ui/cursors/hand_closed.svg")
const _POINT_HOTSPOT := Vector2(22, 12)
const _GRAB_HOTSPOT := Vector2(32, 32)


func _ready() -> void:
	# Keep image registrations fixed: macOS's embedded game view only applies
	# changed images when the mouse re-enters the view.
	for shape in range(Input.CURSOR_ARROW, Input.CURSOR_HELP + 1):
		Input.set_custom_mouse_cursor(_POINT, shape as Input.CursorShape, _POINT_HOTSPOT)
	Input.set_custom_mouse_cursor(_OPEN, Input.CURSOR_DRAG, _GRAB_HOTSPOT)
	Input.set_custom_mouse_cursor(_CLOSED, Input.CURSOR_CAN_DROP, _GRAB_HOTSPOT)
	Input.set_custom_mouse_cursor(_CLOSED, Input.CURSOR_FORBIDDEN, _GRAB_HOTSPOT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		# Godot chooses CAN_DROP/FORBIDDEN over controls. Cover empty space too.
		Input.set_default_cursor_shape(Input.CURSOR_CAN_DROP)
	elif what == NOTIFICATION_DRAG_END:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
