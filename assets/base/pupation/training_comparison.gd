class_name TrainingComparison
extends PanelContainer

## Shared, read-only Training result presentation for confirmation and drag previews.

const PORTRAIT_SCALE := 0.7
const PORTRAIT_SHADOW := 20.0
const _TAG_CHIP_SCENE := preload("res://assets/ui/tag_chip/tag_chip.tscn")
const _HOVER_PUNCH_SCENE := preload("res://assets/ui/hover_punch/hover_punch.tscn")
const _TAG_FONT_SIZE := 16
const _CHANGED_TAG_FONT_SIZE := 20
const _STAT_FONT_SIZE := 18
const _CHANGED_STAT_FONT_SIZE := 24
const _CHANGED_CHIP_SCALE := 1.3
const _SPEED_FONT_SIZE := 20

@export var result_only: bool = false

var _unit: RosterUnitData
var _school: int = 0
var _preview_unit: RosterUnitData
var _preview_troop: TroopData

@onready var _left_portrait: Control = %LeftPortrait
@onready var _left_atk_chip: StatChip = %LeftAtkChip
@onready var _left_hp_chip: StatChip = %LeftHpChip
@onready var _left_speed_chip: StatChip = %LeftSpeedChip
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
@onready var _right_speed_chip: StatChip = %RightSpeedChip
@onready var _right_atk_delta: Label = %RightAtkDelta
@onready var _right_hp_delta: Label = %RightHpDelta
@onready var _right_speed_delta: Label = %RightSpeedDelta
@onready var _right_stage: Label = %RightStage
@onready var _right_weapon_row: PupationWeaponHoverRow = %RightWeaponRow
@onready var _right_weapon_tags: HFlowContainer = %RightWeaponTags
@onready var _right_str: StatValueRow = %RightStr
@onready var _right_dex: StatValueRow = %RightDex
@onready var _right_con: StatValueRow = %RightCon


func _ready() -> void:
	_left_speed_chip.icon = AttackSpeedDisplay.ICON
	_right_speed_chip.icon = AttackSpeedDisplay.ICON
	for chip: StatChip in [_left_atk_chip, _right_atk_chip]:
		_configure_description_hover(chip, "Attack\nDamage per hit.")
	for chip: StatChip in [_left_hp_chip, _right_hp_chip]:
		_configure_description_hover(chip, "Health\nMaximum health.")
	for chip: StatChip in [_left_speed_chip, _right_speed_chip]:
		_configure_description_hover(chip, "Attack speed\nTime between attacks.")
	if result_only:
		%LeftColumn.hide()
		%MidColumn.hide()
		var duration_row := _duration_chip.get_parent() as Control
		duration_row.reparent($CompareRow/RightColumn)
		duration_row.custom_minimum_size.y = 0.0
	else:
		RosterUnitData.link_portrait_fitting(_left_portrait, _right_portrait)
	if _unit != null:
		_refresh()


func setup(unit: RosterUnitData, school: int) -> void:
	_unit = unit
	_school = school
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	if _unit == null:
		return
	_refresh_duration_chip()
	_fill_current_side()
	_fill_result_side()


func _refresh_duration_chip() -> void:
	var days := 0
	if _unit != null:
		days = _unit.effective_cocoon_days()
	_duration_chip.set_value(maxi(days, 0))
	_duration_chip.visible = days > 0
	var suffix := "Instant" if days <= 0 else WeaponSchool.day_word(days)
	_duration_suffix.text = suffix
	_duration_suffix.visible = not WeaponSchool.is_unchanged_training(_unit, _school)


func _fill_current_side() -> void:
	_clear_portrait(_left_portrait)
	_mount_comparison_portrait(_unit, _left_portrait)
	_left_stage.text = WeaponSchool.stage_display_name(_unit.life_stage_id)
	_left_weapon_row.set_unit(_unit)
	_set_combat_chips(_unit, _left_atk_chip, _left_hp_chip, _left_speed_chip, GameState.troop)
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
		_mount_comparison_portrait(_preview_unit, _right_portrait)

	_right_stage.text = WeaponSchool.stage_display_name(next_stage)
	_right_weapon_row.set_unit(_preview_unit, not WeaponSchool.is_unchanged_training(_unit, _school))
	_fill_weapon_tags(_left_weapon_tags, _unit.weapon, right_weapon, -1)
	_fill_weapon_tags(_right_weapon_tags, right_weapon, _unit.weapon, 1)
	_set_combat_chips(_preview_unit, _right_atk_chip, _right_hp_chip, _right_speed_chip, _preview_troop)
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
	_configure_stat_hover(row, abbrev)


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
	_configure_stat_hover(row, abbrev, delta != 0)


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
		_configure_stat_hover(right_row, abbrev)
	_configure_mid_delta(mid_row, abbrev, delta)


func _configure_stat_hover(row: StatValueRow, abbrev: String, show_description: bool = true) -> void:
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var description := ""
	if show_description:
		description = "%s\n%s" % [StatDisplay.display_name(abbrev), StatDisplay.description(abbrev)]
	_configure_description_hover(row, description)


func _configure_description_hover(control: Control, description: String) -> void:
	# The same comparison is also mounted inside a passive Cocoon drag tooltip.
	var interactive := not result_only and not description.is_empty()
	control.tooltip_text = description if interactive else ""
	control.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	var punch := control.get_node_or_null("HoverPunch") as HoverPunch
	if punch != null:
		punch.reset()
	if not interactive:
		if punch != null:
			punch.suppress_enter()
		return
	if punch == null:
		control.add_child(_HOVER_PUNCH_SCENE.instantiate())
	else:
		punch.arm_enter_unless_hovered()


func _set_combat_chips(
	roster: RosterUnitData,
	atk_chip: StatChip,
	hp_chip: StatChip,
	speed_chip: StatChip,
	troop: TroopData
) -> void:
	atk_chip.set_value_color(Color.WHITE)
	hp_chip.set_value_color(Color.WHITE)
	speed_chip.set_value_color(Color.WHITE)
	speed_chip.set_value(
		AttackSpeedDisplay.format_seconds(AttackSpeedDisplay.for_unit(roster))
		if roster != null and roster.weapon != null else "—"
	)
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
	var speed_delta := 0
	if _preview_unit != null and _preview_unit.weapon != null and _unit.weapon != null:
		# Compare the displayed hundredths, so rounding cannot show a false change.
		speed_delta = (
			roundi(AttackSpeedDisplay.for_unit(_preview_unit) * 100.0)
			- roundi(AttackSpeedDisplay.for_unit(_unit) * 100.0)
		)
	# Seconds between attacks: a negative numeric delta is an improvement.
	_apply_combat_delta(
		_right_speed_chip, _right_speed_delta, -speed_delta,
		AttackSpeedDisplay.format_delta(float(speed_delta) / 100.0), _SPEED_FONT_SIZE
	)
	_equalize_combat_group_widths($CompareRow/LeftColumn/LeftCombatRow, 48.0)
	_equalize_combat_group_widths($CompareRow/RightColumn/RightCombatRow, 64.0)


func _equalize_combat_group_widths(row: HBoxContainer, minimum_width: float) -> void:
	# Long change labels should widen every slot equally, not push one chip away.
	for group: Control in row.get_children():
		group.custom_minimum_size.x = minimum_width
	var width := minimum_width
	for group: Control in row.get_children():
		width = maxf(width, group.get_combined_minimum_size().x)
	for group: Control in row.get_children():
		group.custom_minimum_size.x = width


func _apply_combat_delta(
	chip: StatChip, label: Label, delta: int,
	delta_text: String = "", value_font_size: int = StatChip.DEFAULT_VALUE_FONT_SIZE
) -> void:
	var emphasis := _CHANGED_CHIP_SCALE if delta != 0 else 1.0
	chip.chip_size = StatChip.CHIP_SIZE * emphasis
	chip.value_font_size = roundi(value_font_size * emphasis)
	var color := Color.WHITE
	if delta != 0:
		color = StatDisplay.change_color(delta).lightened(0.35 if delta > 0 else 0.2)
	chip.set_value_color(color)
	label.text = "%+d" % delta if delta != 0 else ""
	if delta != 0 and not delta_text.is_empty():
		label.text = delta_text
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
		change_direction if other_weapon == null or weapon.formation_line != other_weapon.formation_line else 0,
		_range_description(weapon.formation_line))
	var scaling_change := change_direction if other_weapon == null or weapon.damage_stat != other_weapon.damage_stat else 0
	var scaling := _add_weapon_tag(row, "", scaling_change, _scaling_description(weapon.damage_stat))
	scaling.show_icons(StatDisplay.textures_for_damage_stat(weapon.damage_stat), "or",
		_CHANGED_TAG_FONT_SIZE if scaling_change != 0 else _TAG_FONT_SIZE, "Scaling")
	if weapon.damage_type == WeaponData.DamageType.BLUNT:
		_add_weapon_tag(row, "Blunt",
			change_direction if other_weapon == null or other_weapon.damage_type != WeaponData.DamageType.BLUNT else 0,
			"Blunt\nBypasses shields.")
	if weapon.targeting_mode == WeaponData.TargetingMode.AOE:
		_add_weapon_tag(row, "AOE",
			change_direction if other_weapon == null or other_weapon.targeting_mode != WeaponData.TargetingMode.AOE else 0,
			"Area of effect\nCan hit multiple enemies in the attack area.")


func _range_description(formation_line: WeaponData.FormationLine) -> String:
	match formation_line:
		WeaponData.FormationLine.MID:
			return "Mid Range\nRanged spear throws.\nMelee when enemies close in."
		WeaponData.FormationLine.BACK:
			return "Ranged\nFights at a distance."
		_:
			return "Melee\nFights at close range."


func _scaling_description(damage_stat: WeaponData.DamageStat) -> String:
	match damage_stat:
		WeaponData.DamageStat.DEX:
			return "Scaling\nDamage scales with DEX."
		WeaponData.DamageStat.FINESSE:
			return "Scaling\nDamage scales with whichever is higher:\nSTR or DEX."
		_:
			return "Scaling\nDamage scales with STR."


func _add_weapon_tag(row: HFlowContainer, text: String, change: int, description: String) -> TagChip:
	var tag: TagChip = _TAG_CHIP_SCENE.instantiate()
	row.add_child(tag)
	tag.set_content_font_size(_CHANGED_TAG_FONT_SIZE if change != 0 else _TAG_FONT_SIZE)
	tag.set_text(text)
	_configure_description_hover(tag, description)
	if change != 0:
		tag.set_fill_color(StatDisplay.change_color(change, true))
		var style := tag.get_theme_stylebox("panel")
		var emphasis := float(_CHANGED_TAG_FONT_SIZE) / _TAG_FONT_SIZE
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_content_margin(side, style.get_content_margin(side) * emphasis)
	return tag


func _mount_comparison_portrait(unit: RosterUnitData, host: Control) -> void:
	var appearance := unit.mount_portrait(host, PORTRAIT_SCALE, PORTRAIT_SHADOW)
	if appearance != null and appearance.animation_player != null:
		# Compare the same idle pose; weapon changes should not imply body changes.
		appearance.animation_player.seek(0.0, true)


func _clear_portrait(host: Control) -> void:
	if host == null:
		return
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
