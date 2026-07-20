class_name UnitCard
extends PanelContainer

signal drag_started(card: UnitCard)
signal clicked(card: UnitCard)
signal weapon_loadout_changed(card: UnitCard)

const CARD_SIZE := Vector2(140, 200)
const PORTRAIT_SCALE := 1.0
const _UNIT_CARD_SCENE := preload("res://assets/base/unit_card/unit_card.tscn")
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
@onready var _atk_chip: StatChip = %AtkChip
@onready var _hp_chip: StatChip = %HpChip
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
		var atk: int = data.stats.get_damage_bonus(data.get_range_class())
		if data.weapon != null:
			atk += data.weapon.base_damage
		_atk_chip.set_value(atk)
		_hp_chip.set_value(data.stats.get_max_hp())
		tooltip_text = "STR %d  DEX %d\nCON %d  SPD %d" % [
			data.stats.strength,
			data.stats.dex,
			data.stats.con,
			data.stats.spd,
		]
	else:
		_atk_chip.set_value("—")
		_hp_chip.set_value("—")
		tooltip_text = ""
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
	# Riboforge: drag unequips non-default weapons onto the stock panel.
	if source == "riboforge_squad":
		var roster := unit_data as RosterUnitData
		if roster == null or RiboforgeData.is_default_weapon(roster.weapon):
			return null
		_drag_started_flag = true
		drag_started.emit(self)
		var weapon_card_scene: PackedScene = load("res://assets/base/riboforge/weapon_card.tscn")
		var preview := weapon_card_scene.instantiate() as WeaponCard
		preview.setup(roster.weapon, -1)
		preview.modulate = Color(1, 1, 1, 0.85)
		preview.reset_compact_layout()
		set_drag_preview(_centered_drag_preview(preview, preview.CARD_SIZE))
		return {
			"type": "equipped_weapon",
			"unit": roster,
			"weapon": roster.weapon,
		}
	_drag_started_flag = true
	drag_started.emit(self)
	# Chess-piece pickup: leave the pad empty while dragging.
	visible = false
	# Instantiate fresh — duplicate() keeps @onready refs to this card, so the
	# preview would remount its portrait onto the hidden source (no anim).
	var unit_preview: UnitCard = _UNIT_CARD_SCENE.instantiate()
	unit_preview.setup(unit_data, source, null)
	unit_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(_centered_drag_preview(unit_preview, CARD_SIZE))
	return {
		"unit": unit_data,
		"source": source,
		"slot": slot,
		"card": self,
	}


func _centered_drag_preview(preview: Control, preview_size: Vector2) -> Control:
	# Viewport pins the preview root origin to the cursor. Offset the child so the
	# card center sits there. Must run after preview.ready — UnitCard._ready calls
	# reset_compact_layout(), which clears any position set beforehand.
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := func() -> void:
		# Slight downward bias so the unit sprite hangs under the cursor.
		preview.position = Vector2(-preview_size.x * 0.5, -preview_size.y * 0.5 + 28.0)
	preview.ready.connect(center, CONNECT_ONE_SHOT)
	host.add_child(preview)
	return host


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
		# Restore if the drag was cancelled; successful drops rebuild the card.
		if is_inside_tree():
			visible = true


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and unit_data is RosterUnitData:
		var drop_type := str(data.get("type", ""))
		if drop_type == "weapon" or drop_type == "shop_weapon":
			return true
		if drop_type == "equipped_weapon":
			var from_unit := data.get("unit") as RosterUnitData
			return from_unit != null and from_unit != unit_data
	# Occupied squad slots: the card covers the DropSlot, so forward drops.
	if slot != null and slot.has_method("_can_drop_data"):
		return slot._can_drop_data(at_position, data)
	# Bench cards cover the bench panel; allow unequipping onto them.
	if source == "bench" and typeof(data) == TYPE_DICTIONARY:
		return str(data.get("source", "")) == "squad"
	return false


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and unit_data is RosterUnitData:
		var drop_type := str(data.get("type", ""))
		if (
			drop_type == "weapon"
			or drop_type == "shop_weapon"
			or drop_type == "equipped_weapon"
		):
			_try_receive_weapon(data)
			return
	if slot != null and slot.has_method("_drop_data"):
		slot._drop_data(at_position, data)
		return
	if source == "bench":
		var base := _find_base()
		if base != null and base.has_method("_bench_drop"):
			base._bench_drop(at_position, data)


func _try_receive_weapon(data: Dictionary) -> void:
	var unit := unit_data as RosterUnitData
	if unit == null:
		return
	var drop_type := str(data.get("type", ""))
	if drop_type == "weapon":
		var stock_index := int(data.get("stock_index", -1))
		if GameState.try_equip_weapon_from_stock(unit, stock_index):
			_refresh()
			weapon_loadout_changed.emit(self)
		return
	if drop_type == "equipped_weapon":
		var from_unit := data.get("unit") as RosterUnitData
		if GameState.try_transfer_equipped_weapon(from_unit, unit):
			_refresh()
			weapon_loadout_changed.emit(self)
		return
	if drop_type == "shop_weapon":
		var weapon := data.get("weapon") as WeaponData
		var cost := int(data.get("cost", 0))
		var slot_index := int(data.get("slot_index", -1))
		if weapon == null:
			return
		if not GameState.try_buy_weapon(weapon, cost):
			return
		if slot_index >= 0:
			GameState.riboforge.replace_shop_slot(slot_index)
		var new_index := GameState.riboforge.weapon_stock.size() - 1
		if GameState.try_equip_weapon_from_stock(unit, new_index):
			_refresh()
			weapon_loadout_changed.emit(self)


func _find_base() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("_bench_drop"):
			return node
		node = node.get_parent()
	return null
