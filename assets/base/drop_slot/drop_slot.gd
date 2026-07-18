class_name DropSlot
extends PanelContainer

signal unit_dropped(slot: DropSlot, drag_data: Dictionary)

@export var slot_index: int = 0

var occupied_unit: Resource

@onready var _placeholder: Label = %Placeholder
@onready var _card_host: CenterContainer = %CardHost

var _base_modulate: Color = Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(140, 160)
	_base_modulate = modulate
	_set_children_mouse_filter_ignore(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(clear_drop_highlight)
	_update_placeholder()


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)


func clear_drop_highlight() -> void:
	modulate = _base_modulate


func set_card(card: Control) -> void:
	clear_card()
	if card == null:
		occupied_unit = null
		_update_placeholder()
		return
	var unit_card := card as UnitCard
	if unit_card != null:
		occupied_unit = unit_card.unit_data
		unit_card.source = "squad"
		unit_card.slot = self
		# Card must receive mouse for dragging, and forwards drops to this slot.
		unit_card.mouse_filter = Control.MOUSE_FILTER_STOP
		# Keep native card size — stretching causes ColorRect edge artefacts.
		unit_card.reset_compact_layout()
	_card_host.add_child(card)
	_update_placeholder()


func clear_card() -> void:
	for child in _card_host.get_children():
		_card_host.remove_child(child)
		child.queue_free()
	occupied_unit = null
	_update_placeholder()


func take_card() -> Control:
	if _card_host.get_child_count() == 0:
		return null
	var card := _card_host.get_child(0) as Control
	_card_host.remove_child(card)
	occupied_unit = null
	_update_placeholder()
	return card


func _update_placeholder() -> void:
	if _placeholder:
		_placeholder.visible = false


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		clear_drop_highlight()
		return false
	var unit := data.get("unit") as RosterUnitData
	if unit == null:
		clear_drop_highlight()
		return false
	modulate = Color(0.7, 1.0, 0.75, 1.0)
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	clear_drop_highlight()
	if typeof(data) != TYPE_DICTIONARY:
		return
	unit_dropped.emit(self, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		clear_drop_highlight()
