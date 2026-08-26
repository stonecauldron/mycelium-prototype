class_name DropSlot
extends PanelContainer

signal item_dropped(slot: DropSlot, drag_data: Dictionary)
## Alias of item_dropped for troop-selection call sites.
signal unit_dropped(slot: DropSlot, drag_data: Dictionary)
signal unlock_pressed(slot: DropSlot)

const _LOCKED_MODULATE := Color(0.55, 0.55, 0.55, 1.0)
const SLOT_SIZE := Vector2(140, 200)

@export var slot_index: int = 0
## Drag payload types this slot accepts. Use "unit" for RosterUnitData drags.
## Empty array = accept nothing (display pad only).
@export var accepted_drag_types: PackedStringArray = PackedStringArray(["unit"])
@export var accepts_drops: bool = true
@export var floor_tint: Color = Color.WHITE:
	set(value):
		floor_tint = value
		_apply_floor_tint()

var occupied_unit: Resource
var is_unlockable: bool = false
var unlock_cost: int = 0

@onready var _placeholder: Label = %Placeholder
@onready var _card_host: CenterContainer = %CardHost
@onready var _floor_tile: TextureRect = %FloorTile
@onready var _lock_icon: TextureRect = %LockIcon
@onready var _action_slot: Control = %ActionSlot
@onready var _unlock_button: Button = %UnlockButton
@onready var _unlock_cost_label: Label = %UnlockCostLabel

var _base_modulate: Color = Color.WHITE


func set_floor_texture(texture: Texture2D) -> void:
	if _floor_tile == null:
		_floor_tile = %FloorTile
	if _floor_tile != null:
		_floor_tile.texture = texture


func _apply_floor_tint() -> void:
	if _floor_tile == null:
		return
	_floor_tile.self_modulate = floor_tint


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	custom_minimum_size = SLOT_SIZE
	_base_modulate = modulate
	_apply_floor_tint()
	_set_children_mouse_filter_ignore(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(clear_drop_highlight)
	if _unlock_button != null and not _unlock_button.pressed.is_connected(_on_unlock_pressed):
		_unlock_button.pressed.connect(_on_unlock_pressed)
	_update_placeholder()
	if is_unlockable:
		_refresh_unlockable()


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child == _unlock_button:
			continue
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)


func setup_unlockable(cost: int) -> void:
	is_unlockable = true
	unlock_cost = cost
	accepts_drops = false
	accepted_drag_types = PackedStringArray()
	if is_node_ready():
		_refresh_unlockable()
	else:
		ready.connect(_refresh_unlockable, CONNECT_ONE_SHOT)


func _refresh_unlockable() -> void:
	if not is_unlockable:
		return
	clear_card()
	custom_minimum_size = SLOT_SIZE
	if _action_slot != null:
		_action_slot.visible = true
	if _lock_icon != null:
		_lock_icon.visible = true
		_lock_icon.modulate = Color.WHITE / _LOCKED_MODULATE
	if _unlock_button != null:
		_unlock_button.visible = true
		_unlock_button.mouse_filter = Control.MOUSE_FILTER_STOP
		var can_unlock := GameState.biomass.can_afford(unlock_cost)
		_unlock_button.disabled = not can_unlock
		var button_mod := Color.WHITE / _LOCKED_MODULATE
		_unlock_button.modulate = button_mod if can_unlock else button_mod * Color(1, 1, 1, 0.45)
	if _unlock_cost_label != null:
		_unlock_cost_label.text = "%d" % unlock_cost
	modulate = _LOCKED_MODULATE
	_base_modulate = modulate
	tooltip_text = ""


func clear_drop_highlight() -> void:
	modulate = _base_modulate


func set_card(card: Control) -> void:
	if is_unlockable:
		return
	clear_card()
	if card == null:
		occupied_unit = null
		_update_placeholder()
		return
	var unit_card := card as UnitCard
	if unit_card != null:
		occupied_unit = unit_card.unit_data
		unit_card.slot = self
		# Card must receive mouse for dragging, and forwards drops to this slot.
		unit_card.mouse_filter = Control.MOUSE_FILTER_STOP
		# Keep native card size — stretching causes ColorRect edge artefacts.
		unit_card.reset_compact_layout()
	else:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		if card.has_method("reset_compact_layout"):
			card.reset_compact_layout()
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


func _is_accepted_drag(data: Dictionary) -> bool:
	if is_unlockable or not accepts_drops or accepted_drag_types.is_empty():
		return false
	var drop_type := str(data.get("type", ""))
	if drop_type != "" and drop_type in accepted_drag_types:
		return true
	if "unit" in accepted_drag_types and data.get("unit") is RosterUnitData:
		return true
	return false


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		clear_drop_highlight()
		return false
	if not _is_accepted_drag(data):
		clear_drop_highlight()
		return false
	modulate = Color(0.7, 1.0, 0.75, 1.0)
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	clear_drop_highlight()
	if typeof(data) != TYPE_DICTIONARY:
		return
	if not _is_accepted_drag(data):
		return
	item_dropped.emit(self, data)
	unit_dropped.emit(self, data)


func _on_unlock_pressed() -> void:
	if not is_unlockable:
		return
	unlock_pressed.emit(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		clear_drop_highlight()
