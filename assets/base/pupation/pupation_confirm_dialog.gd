class_name PupationConfirmDialog
extends Control

signal confirmed(unit: RosterUnitData, school: int)
signal cancelled

const PORTRAIT_SCALE := 0.7
const PORTRAIT_SHADOW := 20.0
const _BIOMASS_ICON := preload("res://assets/base/biomass_small_icon.png")
const _TAG_CHIP_SCENE := preload("res://assets/ui/tag_chip/tag_chip.tscn")
const _TAG_FONT_SIZE := 16
const _CHANGED_TAG_FONT_SIZE := 20
const _STAT_FONT_SIZE := 18
const _CHANGED_STAT_FONT_SIZE := 24
const _CHANGED_CHIP_SCALE := 1.3

var _unit: RosterUnitData
var _school: int = 0
var _preview_unit: RosterUnitData
var _preview_troop: TroopData

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
@onready var _left_weapon_tags: HFlowContainer = %LeftWeaponTags
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
@onready var _right_atk_delta: Label = %RightAtkDelta
@onready var _right_hp_delta: Label = %RightHpDelta
@onready var _right_stage: Label = %RightStage
@onready var _right_weapon_row: PupationWeaponHoverRow = %RightWeaponRow
@onready var _right_weapon_tags: HFlowContainer = %RightWeaponTags
@onready var _right_str: StatValueRow = %RightStr
@onready var _right_dex: StatValueRow = %RightDex
@onready var _right_con: StatValueRow = %RightCon
@onready var _confirm_button: Button = %ConfirmButton


func _ready() -> void:
	GameState.biomass.changed.connect(_refresh_affordability)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_gui_input)
	_close_button.pressed.connect(_on_cancel_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	BiomassPreview.bind(_confirm_button, _biomass_preview_delta)
	_confirm_button.icon = _BIOMASS_ICON
	_confirm_button.expand_icon = true
	_confirm_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_confirm_button.add_theme_constant_override("icon_max_width", 24)
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
	_pupate_title.text = "%s %s" % [_action_verb(), _unit.display_name]
	_refresh_duration_chip()

	_fill_current_side()
	_fill_result_side()
	_refresh_affordability()


func _action_verb() -> String:
	return "Train" if _unit == null or _unit.is_adult_stage() else "Evolve"


func _biomass_preview_delta() -> Variant:
	if not GameState.can_cocoon_for_pupation(_unit, _school):
		return null
	return -WeaponSchool.COCOON_COST


func _refresh_affordability() -> void:
	var can_afford := GameState.biomass.can_afford(WeaponSchool.COCOON_COST)
	_confirm_button.text = "%s %s" % [_action_verb(), BiomassDisplay.number(WeaponSchool.COCOON_COST)]
	_confirm_button.disabled = not can_afford
	_confirm_button.modulate = Color.WHITE if can_afford else Color(0.55, 0.55, 0.55, 1)


func _refresh_duration_chip() -> void:
	var days := 0
	if _unit != null:
		days = _unit.effective_cocoon_days()
	_duration_chip.set_value(maxi(days, 0))
	_duration_chip.visible = days > 0
	var suffix := "Instant" if days <= 0 else WeaponSchool.day_word(days)
	_duration_suffix.text = suffix


func _fill_current_side() -> void:
	_clear_portrait(_left_portrait)
	_unit.mount_portrait(_left_portrait, PORTRAIT_SCALE, PORTRAIT_SHADOW)
	_left_stage.text = WeaponSchool.stage_display_name(_unit.life_stage_id)
	_left_weapon_row.set_unit(_unit)
	_set_combat_chips(_unit, _left_atk_chip, _left_hp_chip, GameState.troop)
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
	_preview_troop = _make_preview_troop()
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
	_right_weapon_row.set_unit(_preview_unit, _unit)
	_fill_weapon_tags(_left_weapon_tags, _unit.weapon, right_weapon, -1)
	_fill_weapon_tags(_right_weapon_tags, right_weapon, _unit.weapon, 1)
	_set_combat_chips(_preview_unit, _right_atk_chip, _right_hp_chip, _preview_troop)
	_refresh_combat_deltas()

	if preview_stats != null and _unit.stats != null:
		_apply_result_stat(
			_right_str, _mid_str, "STR", preview_stats.strength,
			preview_stats.strength - _unit.stats.strength
		)
		_apply_result_stat(
			_right_dex, _mid_dex, "DEX", preview_stats.dex,
			preview_stats.dex - _unit.stats.dex
		)
		_apply_result_stat(
			_right_con, _mid_con, "CON", preview_stats.con,
			preview_stats.con - _unit.stats.con
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
	row.custom_minimum_size.y = StatDisplay.icon_px(_CHANGED_STAT_FONT_SIZE)


func _configure_mid_delta(row: StatValueRow, abbrev: String, delta: int) -> void:
	if row == null:
		return
	var color := StatDisplay.INK
	if delta > 0:
		color = StatDisplay.GAIN_COLOR
	elif delta < 0:
		color = StatDisplay.LOSS_COLOR
	row.configure(
		abbrev,
		"%+d" % delta if delta != 0 else "",
		_CHANGED_STAT_FONT_SIZE if delta != 0 else _STAT_FONT_SIZE,
		color,
		false,
		StatValueRow.Layout.ICON_LAST,
		StatDisplay.INK
	)
	row.custom_minimum_size.y = StatDisplay.icon_px(_CHANGED_STAT_FONT_SIZE)


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
		color = StatDisplay.GAIN_COLOR
		right_text = "%d (%+d)" % [value, delta]
	elif delta < 0:
		color = StatDisplay.LOSS_COLOR
		right_text = "%d (%+d)" % [value, delta]
	if right_row != null:
		right_row.configure(
			abbrev,
			right_text,
			_CHANGED_STAT_FONT_SIZE if delta != 0 else _STAT_FONT_SIZE,
			color,
			false,
			StatValueRow.Layout.ICON_FIRST,
			StatDisplay.INK
		)
		right_row.custom_minimum_size.y = StatDisplay.icon_px(_CHANGED_STAT_FONT_SIZE)
	_configure_mid_delta(mid_row, abbrev, delta)


func _set_combat_chips(
	roster: RosterUnitData,
	atk_chip: StatChip,
	hp_chip: StatChip,
	troop: TroopData
) -> void:
	atk_chip.set_value_color(Color.WHITE)
	hp_chip.set_value_color(Color.WHITE)
	if roster == null or roster.stats == null:
		atk_chip.set_value("—")
		hp_chip.set_value("—")
		return
	atk_chip.set_value(SealModifiers.effective_attack_damage(roster, troop))
	hp_chip.set_value(SealModifiers.effective_max_hp(roster, troop))


func _make_preview_troop() -> TroopData:
	var troop := GameState.troop
	if troop == null:
		return null
	# Compare in the same formation without replacing the live Unit.
	var preview := TroopData.new()
	preview.unlocked_squad_count = troop.unlocked_squad_count
	preview.squad = troop.squad.duplicate()
	preview.bench = troop.bench.duplicate()
	for row in [preview.squad, preview.bench]:
		for index in row.size():
			if row[index] == _unit:
				row[index] = _preview_unit
	return preview


func _refresh_combat_deltas() -> void:
	var attack_delta := 0
	var hp_delta := 0
	if _preview_unit != null and _preview_unit.stats != null and _unit.stats != null:
		attack_delta = (
			SealModifiers.effective_attack_damage(_preview_unit, _preview_troop)
			- SealModifiers.effective_attack_damage(_unit, GameState.troop)
		)
		hp_delta = (
			SealModifiers.effective_max_hp(_preview_unit, _preview_troop)
			- SealModifiers.effective_max_hp(_unit, GameState.troop)
		)
	_apply_combat_delta(_right_atk_chip, _right_atk_delta, attack_delta)
	_apply_combat_delta(_right_hp_chip, _right_hp_delta, hp_delta)


func _apply_combat_delta(chip: StatChip, label: Label, delta: int) -> void:
	var emphasis := _CHANGED_CHIP_SCALE if delta != 0 else 1.0
	chip.chip_size = StatChip.CHIP_SIZE * emphasis
	chip.value_font_size = roundi(StatChip.DEFAULT_VALUE_FONT_SIZE * emphasis)
	var color := Color.WHITE
	if delta != 0:
		color = StatDisplay.change_color(delta).lightened(0.35 if delta > 0 else 0.2)
	chip.set_value_color(color)
	label.text = "%+d" % delta if delta != 0 else ""
	label.add_theme_font_size_override("font_size", _CHANGED_STAT_FONT_SIZE if delta != 0 else _STAT_FONT_SIZE)
	label.add_theme_color_override("font_color", StatDisplay.change_color(delta))


func _fill_weapon_tags(
	row: HFlowContainer, weapon: WeaponData, other_weapon: WeaponData, change_direction: int
) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	if weapon == null:
		return
	var range_text := (
		"Mid Range" if weapon.formation_line == WeaponData.FormationLine.MID
		else str(WeaponData.FORMATION_LINE_LABELS.get(weapon.formation_line, "?"))
	)
	_add_weapon_tag(row, range_text,
		change_direction if other_weapon == null or weapon.formation_line != other_weapon.formation_line else 0)
	var scaling_change := change_direction if other_weapon == null or weapon.damage_stat != other_weapon.damage_stat else 0
	var scaling := _add_weapon_tag(row, "", scaling_change)
	scaling.show_icons(StatDisplay.textures_for_damage_stat(weapon.damage_stat), "or",
		_CHANGED_TAG_FONT_SIZE if scaling_change != 0 else _TAG_FONT_SIZE, "Scaling")
	if weapon.damage_type == WeaponData.DamageType.BLUNT:
		_add_weapon_tag(row, "Blunt",
			change_direction if other_weapon == null or other_weapon.damage_type != WeaponData.DamageType.BLUNT else 0)
	if weapon.targeting_mode == WeaponData.TargetingMode.AOE:
		_add_weapon_tag(row, "AOE",
			change_direction if other_weapon == null or other_weapon.targeting_mode != WeaponData.TargetingMode.AOE else 0)


func _add_weapon_tag(row: HFlowContainer, text: String, change: int) -> TagChip:
	var tag: TagChip = _TAG_CHIP_SCENE.instantiate()
	row.add_child(tag)
	tag.set_content_font_size(_CHANGED_TAG_FONT_SIZE if change != 0 else _TAG_FONT_SIZE)
	tag.set_text(text)
	if change != 0:
		tag.set_fill_color(StatDisplay.change_color(change, true))
		var style := tag.get_theme_stylebox("panel")
		var emphasis := float(_CHANGED_TAG_FONT_SIZE) / _TAG_FONT_SIZE
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_content_margin(side, style.get_content_margin(side) * emphasis)
	return tag


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
