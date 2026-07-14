class_name UnitCard
extends PanelContainer

signal drag_started(card: UnitCard)
signal clicked(card: UnitCard)

const CARD_SIZE := Vector2(140, 160)
const PORTRAIT_SCALE := 0.55
const RANGE_LABELS := {
	WeaponData.WeaponRange.MELEE: "Melee",
	WeaponData.WeaponRange.MID: "Mid",
	WeaponData.WeaponRange.RANGED: "Ranged",
}

var unit_data: Resource
var source: String = "bench"
var slot: Node
var _drag_started_flag: bool = false
var _portrait_instance: Node2D = null

@onready var _name_label: Label = %NameLabel
@onready var _weapon_label: Label = %WeaponLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _portrait_host: Control = %PortraitHost


func setup(data: Resource, card_source: String = "bench", card_slot: Node = null) -> void:
	unit_data = data
	source = card_source
	slot = card_slot
	reset_compact_layout()
	if is_node_ready():
		_refresh()
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
	mouse_exited.connect(_on_mouse_exited)
	reset_compact_layout()
	if unit_data != null:
		_refresh()


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)


func _on_mouse_exited() -> void:
	if slot != null and slot.has_method("clear_drop_highlight"):
		slot.clear_drop_highlight()


func _refresh() -> void:
	if unit_data == null:
		return
	var data := unit_data as RosterUnitData
	if data == null:
		return
	_name_label.text = data.display_name
	var weapon_name: String = data.weapon.display_name if data.weapon else "—"
	var range_name: String = str(RANGE_LABELS.get(data.get_range_class(), "?"))
	_weapon_label.text = "%s (%s)" % [weapon_name, range_name]
	if data.stats != null:
		_stats_label.text = "STR %d  DEX %d\nCON %d  SPD %d" % [
			data.stats.strength,
			data.stats.dex,
			data.stats.con,
			data.stats.spd,
		]
	else:
		_stats_label.text = "—"
	_refresh_portrait(data)


func _refresh_portrait(data: RosterUnitData) -> void:
	if _portrait_instance != null:
		_portrait_instance.queue_free()
		_portrait_instance = null
	if _portrait_host == null:
		return
	_portrait_instance = data.mount_portrait(_portrait_host, PORTRAIT_SCALE)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if unit_data == null:
		return null
	_drag_started_flag = true
	drag_started.emit(self)
	var preview := duplicate() as UnitCard
	preview.modulate = Color(1, 1, 1, 0.85)
	preview.reset_compact_layout()
	set_drag_preview(preview)
	return {
		"unit": unit_data,
		"source": source,
		"slot": slot,
		"card": self,
	}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_drag_started_flag = false
		elif not _drag_started_flag:
			clicked.emit(self)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drag_started_flag = false


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	# Occupied squad slots: the card covers the DropSlot, so forward drops.
	if slot != null and slot.has_method("_can_drop_data"):
		return slot._can_drop_data(at_position, data)
	# Bench cards cover the bench panel; allow unequipping onto them.
	if source == "bench" and typeof(data) == TYPE_DICTIONARY:
		return str(data.get("source", "")) == "squad"
	return false


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if slot != null and slot.has_method("_drop_data"):
		slot._drop_data(at_position, data)
		return
	if source == "bench":
		var base := _find_base()
		if base != null and base.has_method("_bench_drop"):
			base._bench_drop(at_position, data)


func _find_base() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("_bench_drop"):
			return node
		node = node.get_parent()
	return null
