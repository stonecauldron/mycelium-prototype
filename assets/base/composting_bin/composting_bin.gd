class_name CompostingBin
extends PanelContainer

signal unit_dropped_on_bin(bin: CompostingBin, drag_data: Dictionary)

const _HOVER_SCALE := 1.18
const _TWEEN_SECONDS := 0.14

var _base_modulate: Color = Color.WHITE
var _drag_hover_active: bool = false
var _scale_tween: Tween

@onready var _bin_image: TextureRect = %BinImage
@onready var _hover_punch: HoverPunch = %HoverPunch
@onready var _drop_arrow: FloatingArrow = %DropArrow


func _ready() -> void:
	_base_modulate = modulate
	mouse_exited.connect(_on_mouse_exited)
	_bin_image.resized.connect(_sync_bin_pivot)
	_sync_bin_pivot()


func _accepts_drag_data(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var source := str(data.get("source", ""))
	if source != "squad" and source != "bench":
		return false
	var unit := data.get("unit") as RosterUnitData
	return unit != null and GameState.can_compost_unit(unit)


func _refresh_arrow() -> void:
	if _drop_arrow == null:
		return
	var viewport := get_viewport()
	if viewport != null and viewport.gui_is_dragging() and _accepts_drag_data(viewport.gui_get_drag_data()):
		_drop_arrow.show_arrow()
	else:
		_drop_arrow.hide_arrow()


func sync_from_state() -> void:
	_set_drag_hover(false)
	_refresh_arrow()
	if _hover_punch != null:
		_hover_punch.reset()
		_hover_punch.call_deferred("arm_enter_unless_hovered")


func _make_custom_tooltip(_for_text: String) -> Object:
	var tip := PanelContainer.new()
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PaperStyles.apply_tooltip(tip)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	tip.add_child(box)
	var title := Label.new()
	title.text = "Composting bin"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.03, 0.035, 0.027, 1))
	box.add_child(title)
	var body := Label.new()
	body.text = "Kill a unit for biomass.\nAdults also emit spores.\nChild +%d kg · Adult +%d kg" % [
		BiomassData.COMPOST_CHILD,
		BiomassData.COMPOST_ADULT,
	]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(220, 0)
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", Color(0.03, 0.035, 0.027, 1))
	box.add_child(body)
	return DetailTooltipPopup.configure(tip)


func _sync_bin_pivot() -> void:
	_bin_image.pivot_offset = _bin_image.size * 0.5


func _on_mouse_exited() -> void:
	_set_drag_hover(false)


func _set_drag_hover(active: bool) -> void:
	if _drag_hover_active == active:
		return
	_drag_hover_active = active
	modulate = Color(0.75, 1.0, 0.8, 1.0) if active else _base_modulate
	if _hover_punch != null:
		if active:
			_hover_punch.reset()
			_hover_punch.suppress_enter()
		else:
			_hover_punch.call_deferred("arm_enter_unless_hovered")
	if _bin_image == null:
		return
	_sync_bin_pivot()
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var target := _HOVER_SCALE if active else 1.0
	_scale_tween.tween_property(_bin_image, "scale", Vector2(target, target), _TWEEN_SECONDS)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	ActionFeedback.clear_drag_preview()
	var accepted := _accepts_drag_data(data)
	_set_drag_hover(accepted)
	return accepted


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_drag_hover(false)
	_refresh_arrow()
	if _accepts_drag_data(data):
		unit_dropped_on_bin.emit(self, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_refresh_arrow()
	elif what == NOTIFICATION_DRAG_END:
		_set_drag_hover(false)
		_refresh_arrow()
