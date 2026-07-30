class_name ShopDropZone
extends PanelContainer

signal item_dropped(zone: ShopDropZone, drag_data: Dictionary)

const _SELL_OVERLAY_SCENE := preload("res://assets/base/shop/sell_overlay/sell_overlay.tscn")

@export var accepted_drag_types: PackedStringArray = PackedStringArray()
@export var accepts_drops: bool = true

var _base_modulate: Color = Color.WHITE
var _drop_highlight_active: bool = false
var _sell_overlay: ShopSellOverlay = null


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
	if what == NOTIFICATION_DRAG_BEGIN:
		_refresh_sell_overlay()
	elif what == NOTIFICATION_DRAG_END:
		clear_drop_highlight()
		_hide_sell_overlay()


func _refresh_sell_overlay() -> void:
	var amount := _sell_amount_for_current_drag()
	if amount < 0:
		_hide_sell_overlay()
		return
	_ensure_sell_overlay()
	_sell_overlay.show_amount(amount)
	move_child(_sell_overlay, get_child_count() - 1)


func _hide_sell_overlay() -> void:
	if _sell_overlay != null:
		_sell_overlay.hide_overlay()


func _sell_amount_for_current_drag() -> int:
	var viewport := get_viewport()
	if viewport == null or not viewport.gui_is_dragging():
		return -1
	var data: Variant = viewport.gui_get_drag_data()
	if typeof(data) != TYPE_DICTIONARY:
		return -1
	if not _is_accepted_drag(data):
		return -1
	var drag := data as Dictionary
	var drop_type := str(drag.get("type", ""))
	match drop_type:
		"spore":
			var spore := drag.get("spore") as SporeData
			if spore == null:
				return -1
			return BiomassData.sell_value(spore.biomass_cost)
		"fertilizer":
			var fert := drag.get("fertilizer") as FertilizerData
			if fert == null:
				return -1
			return BiomassData.sell_value(fert.biomass_cost)
		"weapon", "equipped_weapon":
			var weapon := drag.get("weapon") as WeaponData
			if weapon == null or RiboforgeData.is_default_weapon(weapon):
				return -1
			return BiomassData.sell_value(weapon.biomass_cost)
	return -1


func _ensure_sell_overlay() -> void:
	if _sell_overlay != null:
		return
	_sell_overlay = _SELL_OVERLAY_SCENE.instantiate() as ShopSellOverlay
	_sell_overlay.z_index = 10
	add_child(_sell_overlay)
