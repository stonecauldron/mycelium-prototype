extends RefCounted

# Model Godot 4.7 macOS LayerHost: cursor image messages update a cache;
# NOTIFICATION_MOUSE_ENTER is what applies that cache to the desktop cursor.
enum CursorShape {
	CURSOR_ARROW, CURSOR_IBEAM, CURSOR_POINTING_HAND, CURSOR_CROSS,
	CURSOR_WAIT, CURSOR_BUSY, CURSOR_DRAG, CURSOR_CAN_DROP, CURSOR_FORBIDDEN,
	CURSOR_VSIZE, CURSOR_HSIZE, CURSOR_BDIAGSIZE, CURSOR_FDIAGSIZE,
	CURSOR_MOVE, CURSOR_VSPLIT, CURSOR_HSPLIT, CURSOR_HELP,
}

const CURSOR_ARROW = CursorShape.CURSOR_ARROW
const CURSOR_DRAG = CursorShape.CURSOR_DRAG
const CURSOR_CAN_DROP = CursorShape.CURSOR_CAN_DROP
const CURSOR_FORBIDDEN = CursorShape.CURSOR_FORBIDDEN
const CURSOR_HELP = CursorShape.CURSOR_HELP

static var registered_images: Dictionary = {}
static var displayed_images: Dictionary = {}
static var default_shape: CursorShape = CursorShape.CURSOR_ARROW


static func set_custom_mouse_cursor(texture: Resource, shape: CursorShape, _hotspot: Vector2) -> void:
	registered_images[shape] = texture


static func set_default_cursor_shape(shape: CursorShape) -> void:
	default_shape = shape


static func mouse_enter() -> void:
	displayed_images = registered_images.duplicate()
