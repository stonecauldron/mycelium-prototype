class_name SporeCard
extends PanelContainer

signal spore_clicked(card: SporeCard)

const CARD_SIZE := Vector2(120, 100)
const _SPORE_CARD_SCENE := preload("res://assets/base/nursery/spore_card/spore_card.tscn")
const _SPORE_DETAIL_CARD_SCENE := preload("res://assets/base/spore_detail_card/spore_detail_card.tscn")
const _HOVER_AMPLITUDE_PX := 5.0
const _HOVER_HALF_DURATION_SEC := 1.35

var spore: SporeData
var stock_index: int = 0

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _days_chip: StatChip = %DaysChip
@onready var _hover_punch: HoverPunch = %HoverPunch

var _pressing: bool = false
var _did_drag: bool = false
var _hover_tween: Tween
var _hover_y: float = 0.0:
	set(value):
		_hover_y = value
		_apply_hover_y()


func setup(spore_data: SporeData, index: int) -> void:
	spore = spore_data
	stock_index = index
	if is_node_ready():
		_refresh()
		_restart_hover()
	else:
		ready.connect(_refresh, CONNECT_ONE_SHOT)


func reset_compact_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	anchor_right = anchor_left
	anchor_bottom = anchor_top
	offset_left = 0.0
	offset_top = 0.0
	offset_right = CARD_SIZE.x
	offset_bottom = CARD_SIZE.y
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_children_mouse_filter_ignore(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	reset_compact_layout()
	if spore != null:
		_refresh()
	_restart_hover()


func _exit_tree() -> void:
	_stop_hover()


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)


func _refresh() -> void:
	if spore == null:
		return
	_name_label.text = spore.display_name
	_days_chip.set_value(spore.days_to_mature_effective())
	if _icon != null:
		_icon.modulate = spore.tint
	# Non-empty text enables the tooltip popup; content comes from _make_custom_tooltip.
	tooltip_text = spore.display_name


func _make_custom_tooltip(_for_text: String) -> Object:
	if spore == null:
		return null
	var tip: SporeDetailCard = _SPORE_DETAIL_CARD_SCENE.instantiate()
	tip.setup(spore, false)
	DetailTooltipPopup.configure(tip)
	return tip


func _apply_hover_y() -> void:
	if _icon == null:
		return
	_icon.offset_top = _hover_y
	_icon.offset_bottom = _hover_y


func _restart_hover() -> void:
	_stop_hover()
	if _icon == null or not is_inside_tree():
		return
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hover_y = 0.0
	_apply_hover_y()

	var phase_delay := fmod(float(stock_index) * 0.41, _HOVER_HALF_DURATION_SEC * 2.0)
	var starter := create_tween()
	_hover_tween = starter
	if phase_delay > 0.001:
		starter.tween_interval(phase_delay)
	starter.tween_callback(_start_hover_loop)


func _start_hover_loop() -> void:
	if _icon == null or not is_inside_tree():
		return
	var tween := create_tween()
	_hover_tween = tween
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "_hover_y", -_HOVER_AMPLITUDE_PX, _HOVER_HALF_DURATION_SEC)
	tween.tween_property(self, "_hover_y", _HOVER_AMPLITUDE_PX, _HOVER_HALF_DURATION_SEC)


func _stop_hover() -> void:
	if _hover_tween != null:
		_hover_tween.kill()
		_hover_tween = null
	_hover_y = 0.0
	_apply_hover_y()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_pressing = true
			_did_drag = false
			return
		if _pressing:
			_pressing = false
			if not _did_drag:
				spore_clicked.emit(self)
			accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if spore == null:
		return null
	_did_drag = true
	if _hover_punch != null:
		_hover_punch.reset()
	# Chess-piece pickup: leave the pad empty while dragging.
	visible = false
	# Instantiate fresh — duplicate() keeps @onready refs to this card, so the
	# preview would animate the hidden source instead of itself.
	var preview: SporeCard = _SPORE_CARD_SCENE.instantiate()
	preview.setup(spore, stock_index)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(_centered_drag_preview(preview, CARD_SIZE))
	return {
		"type": "spore",
		"stock_index": stock_index,
		"spore": spore,
	}


func _centered_drag_preview(preview: Control, preview_size: Vector2) -> Control:
	# Viewport pins the preview root origin to the cursor. Offset the child so the
	# card center sits there. Must run after preview.ready — SporeCard._ready calls
	# reset_compact_layout(), which clears any position set beforehand.
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := func() -> void:
		# Slight downward bias so the spore hangs under the cursor.
		preview.position = Vector2(-preview_size.x * 0.5, -preview_size.y * 0.5 + 28.0)
	preview.ready.connect(center, CONNECT_ONE_SHOT)
	host.add_child(preview)
	return host


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if _hover_punch != null:
			_hover_punch.reset()
			_hover_punch.suppress_enter()
		# Restore if the drag was cancelled; successful drops rebuild the card.
		if is_inside_tree():
			visible = true
		if _hover_punch != null:
			_hover_punch.call_deferred("arm_enter_unless_hovered")


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var slot := _find_host_slot()
	if slot != null:
		return slot._can_drop_data(at_position, data)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var drop_type := str(data.get("type", ""))
	return drop_type in ["shop_spore", "shop_fertilizer", "spore", "fertilizer"]


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var slot := _find_host_slot()
	if slot != null:
		slot._drop_data(at_position, data)


func _find_host_slot() -> DropSlot:
	var node: Node = get_parent()
	while node != null:
		if node is DropSlot:
			return node as DropSlot
		node = node.get_parent()
	return null
