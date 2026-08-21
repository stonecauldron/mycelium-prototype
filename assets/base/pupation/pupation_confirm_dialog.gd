class_name PupationConfirmDialog
extends Control

signal confirmed(unit: RosterUnitData, school: int)
signal cancelled

const PORTRAIT_SCALE := 0.7
const PORTRAIT_SHADOW := 20.0
const _BIOMASS_ICON := preload("res://assets/base/biomass_small_icon.png")
const _COLOR_UP := Color(0.12, 0.45, 0.18, 1)
const _COLOR_DOWN := Color(0.7, 0.15, 0.12, 1)
const _STAT_FONT_SIZE := 18

var _unit: RosterUnitData
var _school: int = 0
var _preview_unit: RosterUnitData

@onready var _dim: ColorRect = %Dim
@onready var _school_icon: TextureRect = %SchoolIcon
@onready var _header_title: Label = %HeaderTitle
@onready var _close_button: Button = %CloseButton
@onready var _pupate_title: Label = %PupateTitle
@onready var _left_portrait: Control = %LeftPortrait
@onready var _left_atk_chip: StatChip = %LeftAtkChip
@onready var _left_hp_chip: StatChip = %LeftHpChip
@onready var _left_stage: Label = %LeftStage
@onready var _left_weapon_row: PupationWeaponHoverRow = %LeftWeaponRow
@onready var _left_weapon_icon: TextureRect = %LeftWeaponIcon
@onready var _left_weapon_name: Label = %LeftWeaponName
@onready var _left_str: StatValueRow = %LeftStr
@onready var _left_dex: StatValueRow = %LeftDex
@onready var _left_con: StatValueRow = %LeftCon
@onready var _duration_chip: StatChip = %DurationChip
@onready var _duration_suffix: Label = %DurationSuffix
@onready var _mid_str: StatValueRow = %MidStr
@onready var _mid_dex: StatValueRow = %MidDex
@onready var _mid_con: StatValueRow = %MidCon
@onready var _right_portrait: Control = %RightPortrait
@onready var _right_atk_chip: StatChip = %RightAtkChip
@onready var _right_hp_chip: StatChip = %RightHpChip
@onready var _right_stage: Label = %RightStage
@onready var _right_weapon_row: PupationWeaponHoverRow = %RightWeaponRow
@onready var _right_weapon_icon: TextureRect = %RightWeaponIcon
@onready var _right_weapon_name: Label = %RightWeaponName
@onready var _right_str: StatValueRow = %RightStr
@onready var _right_dex: StatValueRow = %RightDex
@onready var _right_con: StatValueRow = %RightCon
@onready var _confirm_button: Button = %ConfirmButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_gui_input)
	_close_button.pressed.connect(_on_cancel_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_confirm_button.icon = _BIOMASS_ICON
	_confirm_button.expand_icon = true
	_confirm_button.add_theme_constant_override("icon_max_width", 36)
	if _unit != null:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_on_cancel_pressed()
			get_viewport().set_input_as_handled()


func setup(unit: RosterUnitData, school: int) -> void:
	_unit = unit
	_school = school
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	if _unit == null:
		return
	var school_weapon := WeaponSchool.load_weapon(WeaponSchool.base_weapon_path(_school))
	_school_icon.texture = school_weapon.icon if school_weapon != null else null
	_header_title.text = "%s Training" % WeaponSchool.display_name(_school)
	_pupate_title.text = "Pupate %s" % _unit.display_name
	_refresh_duration_chip()

	_fill_current_side()
	_fill_result_side()

	var can_afford := GameState.biomass.can_afford(WeaponSchool.COCOON_COST)
	_confirm_button.text = "%d  Confirm" % WeaponSchool.COCOON_COST
	_confirm_button.disabled = not can_afford
	_confirm_button.modulate = Color.WHITE if can_afford else Color(0.55, 0.55, 0.55, 1)


func _refresh_duration_chip() -> void:
	var days := 0
	if _unit != null:
		days = _unit.effective_cocoon_days()
	if days <= 0:
		_duration_chip.set_value(0)
		_duration_suffix.text = "instant"
		return
	_duration_chip.set_value(days)
	_duration_suffix.text = WeaponSchool.day_word(days)


func _fill_current_side() -> void:
	_clear_portrait(_left_portrait)
	_unit.mount_portrait(_left_portrait, PORTRAIT_SCALE, PORTRAIT_SHADOW)
	_left_stage.text = WeaponSchool.stage_display_name(_unit.life_stage_id)
	var left_weapon := _unit.weapon
	_left_weapon_icon.texture = left_weapon.icon if left_weapon != null else null
	_left_weapon_name.text = left_weapon.display_name if left_weapon != null else "—"
	_left_weapon_row.set_weapon(left_weapon)
	_set_combat_chips(_unit, _left_atk_chip, _left_hp_chip)
	var stats := _unit.stats
	if stats != null:
		_configure_current_stat(_left_str, "STR", str(stats.strength))
		_configure_current_stat(_left_dex, "DEX", str(stats.dex))
		_configure_current_stat(_left_con, "CON", str(stats.con))
	else:
		_configure_current_stat(_left_str, "STR", "—")
		_configure_current_stat(_left_dex, "DEX", "—")
		_configure_current_stat(_left_con, "CON", "—")


func _fill_result_side() -> void:
	_preview_unit = WeaponSchool.preview_emerged_unit(_unit, _school)
	var generation := 1
	if _unit != null:
		generation = maxi(_unit.generation, 1)
	var mult := 1
	if _unit != null:
		mult = maxi(_unit.pupation_stat_multiplier, 1)
	var deltas := WeaponSchool.scaled_school_deltas(_school, generation)
	var adult_bonus := 0
	if _unit != null and _unit.life_stage_id == RosterUnitData.STAGE_JUVENILE:
		adult_bonus = _unit.pending_adult_stat_bonus
	var next_stage := (
		_preview_unit.life_stage_id if _preview_unit != null
		else WeaponSchool.next_stage_after_training(_unit)
	)
	var right_weapon: WeaponData = _preview_unit.weapon if _preview_unit != null else null
	var preview_stats: UnitStatsData = _preview_unit.stats if _preview_unit != null else null

	_clear_portrait(_right_portrait)
	if _preview_unit != null:
		_preview_unit.mount_portrait(_right_portrait, PORTRAIT_SCALE, PORTRAIT_SHADOW)

	_right_stage.text = WeaponSchool.stage_display_name(next_stage)
	_right_weapon_icon.texture = right_weapon.icon if right_weapon != null else null
	_right_weapon_name.text = right_weapon.display_name if right_weapon != null else "—"
	_right_weapon_row.set_weapon(right_weapon)
	_set_combat_chips(_preview_unit, _right_atk_chip, _right_hp_chip)

	if preview_stats != null:
		_apply_result_stat(
			_right_str, _mid_str, "STR", preview_stats.strength,
			int(deltas.get("strength", 0)) * mult + adult_bonus
		)
		_apply_result_stat(
			_right_dex, _mid_dex, "DEX", preview_stats.dex,
			int(deltas.get("dex", 0)) * mult + adult_bonus
		)
		_apply_result_stat(
			_right_con, _mid_con, "CON", preview_stats.con,
			int(deltas.get("con", 0)) * mult + adult_bonus
		)
	else:
		_configure_current_stat(_right_str, "STR", "—")
		_configure_current_stat(_right_dex, "DEX", "—")
		_configure_current_stat(_right_con, "CON", "—")
		_configure_mid_delta(_mid_str, "STR", 0)
		_configure_mid_delta(_mid_dex, "DEX", 0)
		_configure_mid_delta(_mid_con, "CON", 0)


func _configure_current_stat(row: StatValueRow, abbrev: String, value_text: String) -> void:
	if row == null:
		return
	row.configure(
		abbrev,
		value_text,
		_STAT_FONT_SIZE,
		StatDisplay.INK,
		false,
		StatValueRow.Layout.ICON_FIRST,
		StatDisplay.INK
	)


func _configure_mid_delta(row: StatValueRow, abbrev: String, delta: int) -> void:
	if row == null:
		return
	var color := StatDisplay.INK
	if delta > 0:
		color = _COLOR_UP
	elif delta < 0:
		color = _COLOR_DOWN
	row.configure(
		abbrev,
		"%+d" % delta if delta != 0 else "",
		_STAT_FONT_SIZE,
		color,
		false,
		StatValueRow.Layout.ICON_LAST,
		StatDisplay.INK
	)


func _apply_result_stat(
	right_row: StatValueRow,
	mid_row: StatValueRow,
	abbrev: String,
	value: int,
	delta: int
) -> void:
	var color := StatDisplay.INK
	var right_text := str(value)
	if delta > 0:
		color = _COLOR_UP
		right_text = "%d (%+d)" % [value, delta]
	elif delta < 0:
		color = _COLOR_DOWN
		right_text = "%d (%+d)" % [value, delta]
	if right_row != null:
		right_row.configure(
			abbrev,
			right_text,
			_STAT_FONT_SIZE,
			color,
			false,
			StatValueRow.Layout.ICON_FIRST,
			StatDisplay.INK
		)
	_configure_mid_delta(mid_row, abbrev, delta)


func _set_combat_chips(roster: RosterUnitData, atk_chip: StatChip, hp_chip: StatChip) -> void:
	if roster == null or roster.stats == null:
		atk_chip.set_value("—")
		hp_chip.set_value("—")
		return
	atk_chip.set_value(SealModifiers.effective_attack_damage(roster))
	hp_chip.set_value(SealModifiers.effective_max_hp(roster))


func _clear_portrait(host: Control) -> void:
	if host == null:
		return
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_cancel_pressed()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()


func _on_confirm_pressed() -> void:
	if _unit == null:
		return
	if not GameState.biomass.can_afford(WeaponSchool.COCOON_COST):
		return
	confirmed.emit(_unit, _school)
	queue_free()
