class_name UnitCard
extends PanelContainer

signal drag_started(card: UnitCard)
signal clicked(card: UnitCard)

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
var _mutation_chip: StatChip = null

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
	return RosterUnitData.create(
		"Mock Capling",
		UnitStatsData.create_for_tier(UnitStatsData.PowerTier.COMMON),
		WeaponSchool.sword(),
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
		_atk_chip.set_value(BroodEmpressEffect.hub_effective_attack(data))
		_hp_chip.set_value(BroodEmpressEffect.hub_effective_max_hp(data))
	else:
		_atk_chip.set_value("—")
		_hp_chip.set_value("—")
	_refresh_mutation_chip(data)
	# Non-empty text enables the tooltip popup; content comes from _make_custom_tooltip.
	tooltip_text = data.display_name
	_refresh_portrait(data)


func _refresh_mutation_chip(data: RosterUnitData) -> void:
	if _mutation_chip != null:
		if is_instance_valid(_mutation_chip):
			_mutation_chip.queue_free()
		_mutation_chip = null
	if data == null or _atk_chip == null:
		return
	var info := data.get_identity_stat_chip()
	if info.is_empty():
		return
	var row := _atk_chip.get_parent() as Control
	if row == null:
		return
	var chip: StatChip = _STAT_CHIP_SCENE.instantiate()
	chip.icon = info.get("icon") as Texture2D
	row.add_child(chip)
	chip.set_value(info.get("value", 0))
	_mutation_chip = chip


func _make_custom_tooltip(_for_text: String) -> Object:
	var data := unit_data as RosterUnitData
	if data == null:
		return null
	var unit_tip: UnitDetailCard = _UNIT_DETAIL_CARD_SCENE.instantiate()
	# No portrait — UnitCard already shows it. Non-interactive so hover stays stable.
	unit_tip.setup(data, false, false)

	if data.weapon == null:
		return DetailTooltipPopup.configure(unit_tip)

	var weapon_tip: WeaponDetailCard = _WEAPON_DETAIL_CARD_SCENE.instantiate()
	weapon_tip.setup(data.weapon, false)

	var host := HBoxContainer.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_theme_constant_override("separation", int(_DETAIL_TOOLTIP_SEPARATION))
	host.add_child(unit_tip)
	host.add_child(weapon_tip)
	return DetailTooltipPopup.configure(host)


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
