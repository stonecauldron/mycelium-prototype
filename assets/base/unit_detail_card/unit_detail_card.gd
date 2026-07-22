class_name UnitDetailCard
extends Control

const CARD_SIZE := Vector2(180, 280)
const PORTRAIT_SCALE := 0.85
const STRAIN_LABEL := "Warrior Strain"

var unit_data: RosterUnitData
var _portrait_instance: Node2D = null

@onready var _name_label: Label = %NameLabel
@onready var _type_label: Label = %TypeLabel
@onready var _portrait_host: Control = %PortraitHost
@onready var _atk_chip: StatChip = %AtkChip
@onready var _hp_chip: StatChip = %HpChip
@onready var _str_label: Label = %StrLabel
@onready var _dex_label: Label = %DexLabel
@onready var _con_label: Label = %ConLabel
@onready var _spd_label: Label = %SpdLabel


func setup(unit: RosterUnitData) -> void:
	unit_data = unit
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
	reset_compact_layout()
	if unit_data != null:
		_refresh()

func _refresh() -> void:
	if unit_data == null:
		return
	_name_label.text = unit_data.display_name
	_type_label.text = STRAIN_LABEL
	if unit_data.stats != null:
		var atk: int = unit_data.stats.get_damage_bonus(unit_data.get_attack_style())
		var outgoing_mult: float = 1.0
		if unit_data.weapon != null:
			atk += unit_data.weapon.base_damage
			outgoing_mult = unit_data.weapon.outgoing_damage_multiplier
		atk = roundi(float(atk) * outgoing_mult)
		_atk_chip.set_value(atk)
		_hp_chip.set_value(unit_data.stats.get_max_hp())
		_str_label.text = "STR %d" % unit_data.stats.strength
		_dex_label.text = "DEX %d" % unit_data.stats.dex
		_con_label.text = "CON %d" % unit_data.stats.con
		_spd_label.text = "SPD %d" % unit_data.stats.spd
	else:
		_atk_chip.set_value("—")
		_hp_chip.set_value("—")
		_str_label.text = "STR —"
		_dex_label.text = "DEX —"
		_con_label.text = "CON —"
		_spd_label.text = "SPD —"
	_refresh_portrait()


func _refresh_portrait() -> void:
	if _portrait_instance != null:
		_portrait_instance.queue_free()
		_portrait_instance = null
	if _portrait_host == null or unit_data == null:
		return
	_portrait_instance = unit_data.mount_portrait(_portrait_host, PORTRAIT_SCALE)


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
