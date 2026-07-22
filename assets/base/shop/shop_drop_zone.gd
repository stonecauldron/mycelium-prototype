class_name ShopDropZone
extends PanelContainer

signal item_dropped(zone: ShopDropZone, drag_data: Dictionary)

@export var accepted_drag_types: PackedStringArray = PackedStringArray()
@export var accepts_drops: bool = true

var _base_modulate: Color = Color.WHITE
var _drop_highlight_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_base_modulate = modulate
	set_process(false)
	mouse_exited.connect(clear_drop_highlight)


func clear_drop_highlight() -> void:
	_drop_highlight_active = false
	set_process(false)
	modulate = _base_modulate


func _is_accepted_drag(data: Dictionary) -> bool:
	if not accepts_drops or accepted_drag_types.is_empty():
		return false
	var drop_type := str(data.get("type", ""))
	return drop_type != "" and drop_type in accepted_drag_types


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		clear_drop_highlight()
		return false
	if not _is_accepted_drag(data):
		clear_drop_highlight()
		return false
	_drop_highlight_active = true
	set_process(true)
	modulate = Color(0.7, 1.0, 0.75, 1.0)
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	clear_drop_highlight()
	if typeof(data) != TYPE_DICTIONARY:
		return
	if not _is_accepted_drag(data):
		return
	item_dropped.emit(self, data)


func _process(_delta: float) -> void:
	# mouse_exited often does not fire while a drag preview is active.
	if not _drop_highlight_active:
		return
	if not get_global_rect().has_point(get_global_mouse_position()):
		clear_drop_highlight()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		clear_drop_highlight()
