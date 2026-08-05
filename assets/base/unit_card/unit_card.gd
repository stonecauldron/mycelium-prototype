class_name UnitCard
extends PanelContainer

signal drag_started(card: UnitCard)
signal clicked(card: UnitCard)
signal weapon_loadout_changed(card: UnitCard)

const CARD_SIZE := Vector2(140, 200)
const PORTRAIT_SCALE := 1.0
const _UNIT_CARD_SCENE := preload("res://assets/base/unit_card/unit_card.tscn")
const _UNIT_DETAIL_CARD_SCENE := preload("res://assets/base/unit_detail_card/unit_detail_card.tscn")
const _WEAPON_DETAIL_CARD_SCENE := preload("res://assets/base/weapon_detail_card/weapon_detail_card.tscn")
const _STAT_CHIP_SCENE := preload("res://assets/ui/stat_chip/stat_chip.tscn")
const _DETAIL_TOOLTIP_SEPARATION := 12.0
var unit_data: Resource
var source: String = "bench"
var slot: Node
var _drag_started_flag: bool = false
var _portrait_instance: Node2D = null
var _strain_chip: StatChip = null

@onready var _name_label: Label = %NameLabel
@onready var _weapon_label: Label = %WeaponLabel
@onready var _atk_chip: StatChip = %AtkChip
@onready var _hp_chip: StatChip = %HpChip
@onready var _portrait_host: Control = %PortraitHost
@onready var _hover_punch: HoverPunch = %HoverPunch


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
	pivot_offset = CARD_SIZE * 0.5
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_children_mouse_filter_ignore(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_mouse_exited)
	reset_compact_layout()
	if unit_data == null and get_tree().current_scene == self:
		unit_data = _make_mock_unit()
	if unit_data != null:
		_refresh()


func _make_mock_unit() -> RosterUnitData:
	var weapon := load(RiboforgeData.SWORD_WEAPON_PATH) as WeaponData
	return RosterUnitData.create(
		"Mock Capling",
		UnitStatsData.create_for_tier(UnitStatsData.PowerTier.COMMON),
		weapon,
		null,
		UnitStatsData.PowerTier.COMMON,
	)


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
	var range_name: String = str(WeaponData.FORMATION_LINE_LABELS.get(data.get_formation_line(), "?"))
	_weapon_label.text = "%s (%s)" % [weapon_name, range_name]
	if data.stats != null:
		var atk: int = data.stats.get_damage_bonus(data.get_damage_stat())
		var outgoing_mult: float = 1.0
		if data.weapon != null:
			atk += data.weapon.base_damage
			outgoing_mult = data.weapon.outgoing_damage_multiplier
		atk = maxi(roundi(float(atk) * outgoing_mult), 1)
		_atk_chip.set_value(atk)
		_hp_chip.set_value(data.stats.get_max_hp())
	else:
		_atk_chip.set_value("—")
		_hp_chip.set_value("—")
	_refresh_strain_chip(data)
	# Non-empty text enables the tooltip popup; content comes from _make_custom_tooltip.
	tooltip_text = data.display_name
	_refresh_portrait(data)


func _refresh_strain_chip(data: RosterUnitData) -> void:
	if _strain_chip != null:
		if is_instance_valid(_strain_chip):
			_strain_chip.queue_free()
		_strain_chip = null
	if data == null or data.strain == null or _atk_chip == null:
		return
	var info := data.strain.get_stat_chip(data)
	if info.is_empty():
		return
	var row := _atk_chip.get_parent() as Control
	if row == null:
		return
	var chip: StatChip = _STAT_CHIP_SCENE.instantiate()
	chip.icon = info.get("icon") as Texture2D
	row.add_child(chip)
	chip.set_value(info.get("value", 0))
	_strain_chip = chip


func _make_custom_tooltip(_for_text: String) -> Object:
	var data := unit_data as RosterUnitData
	if data == null:
		return null
	var unit_tip: UnitDetailCard = _UNIT_DETAIL_CARD_SCENE.instantiate()
	# No portrait — UnitCard already shows it. Non-interactive so hover stays stable.
	unit_tip.setup(data, false, false)
	var unit_size := unit_tip.card_size()
	unit_tip.custom_minimum_size = unit_size
	unit_tip.size = unit_size

	if data.weapon == null:
		unit_tip.tree_entered.connect(
			_configure_detail_tooltip_popup.bind(unit_tip, unit_size), CONNECT_ONE_SHOT
		)
		return unit_tip

	var weapon_tip: WeaponDetailCard = _WEAPON_DETAIL_CARD_SCENE.instantiate()
	weapon_tip.setup(data.weapon, false)
	var weapon_size := weapon_tip.card_size()
	weapon_tip.custom_minimum_size = weapon_size
	weapon_tip.size = weapon_size

	var host := HBoxContainer.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_theme_constant_override("separation", int(_DETAIL_TOOLTIP_SEPARATION))
	host.add_child(unit_tip)
	host.add_child(weapon_tip)
	var combined := Vector2(
		unit_size.x + weapon_size.x + _DETAIL_TOOLTIP_SEPARATION,
		maxf(unit_size.y, weapon_size.y)
	)
	host.custom_minimum_size = combined
	host.size = combined
	host.tree_entered.connect(
		_configure_detail_tooltip_popup.bind(host, combined), CONNECT_ONE_SHOT
	)
	return host


func _configure_detail_tooltip_popup(tip: Control, tip_size: Vector2) -> void:
	var node: Node = tip.get_parent()
	while node != null:
		if node is PopupPanel:
			var popup := node as PopupPanel
			popup.transparent = true
			popup.transparent_bg = true
			popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			popup.size = Vector2i(ceili(tip_size.x), ceili(tip_size.y))
			return
		node = node.get_parent()


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
	# Cocoon: click to cancel; no drag.
	if source == "cocoon":
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
	if _hover_punch != null:
		_hover_punch.reset()
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
		if _hover_punch != null:
			_hover_punch.reset()
			# Don't replay hover when the pointer is still over the card after drop.
			_hover_punch.suppress_enter()
		# Restore if the drag was cancelled; successful drops rebuild the card.
		if is_inside_tree():
			visible = true
		# Keep punch suppressed while still hovering after an equip drop.
		# play_exit on mouse leave will re-arm enter.

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
			_suppress_punch_after_equip()
			weapon_loadout_changed.emit(self)
		return
	if drop_type == "equipped_weapon":
		var from_unit := data.get("unit") as RosterUnitData
		if GameState.try_transfer_equipped_weapon(from_unit, unit):
			_refresh()
			_suppress_punch_after_equip()
			weapon_loadout_changed.emit(self)
		return
	if drop_type == "shop_weapon":
		var weapon := data.get("weapon") as WeaponData
		var cost := int(data.get("cost", 0))
		var slot_index := int(data.get("slot_index", -1))
		if weapon == null:
			return
		var new_index := GameState.try_buy_weapon(weapon, cost)
		if new_index < 0:
			return
		if slot_index >= 0:
			GameState.riboforge.replace_shop_slot(slot_index)
		if GameState.try_equip_weapon_from_stock(unit, new_index):
			_refresh()
			_suppress_punch_after_equip()
			weapon_loadout_changed.emit(self)


func _suppress_punch_after_equip() -> void:
	if _hover_punch == null:
		return
	_hover_punch.reset()
	_hover_punch.suppress_enter()


func _find_base() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("_bench_drop"):
			return node
		node = node.get_parent()
	return null
