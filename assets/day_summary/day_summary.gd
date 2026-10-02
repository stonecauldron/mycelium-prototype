extends Control

const _BASE_SCENE_PATH := "res://assets/base/base.tscn"
const _COMBAT_SCENE_PATH := "res://assets/combat/combat_stage/combat_stage.tscn"
const _VICTORY_SCENE_PATH := "res://assets/victory/victory.tscn"
const _GAME_OVER_SCENE_PATH := "res://assets/game_over/game_over.tscn"
const _PORTRAIT_HOST_SIZE := Vector2(68, 84)
const _PORTRAIT_SCALE := 0.54
const _DAMAGE_PORTRAIT_HOST_SIZE := Vector2(100, 124)
const _DAMAGE_PORTRAIT_SCALE := 0.78
const _SPORE_ICON := preload("res://assets/base/nursery/spores.png")
const _SPORE_ICON_SIZE := Vector2(160, 160)
const _PLOT_EMPTY := preload("res://assets/base/plot_tile/plot_empty.png")
const _EGG0 := preload("res://assets/base/plot_tile/egg0.png")
const _EGG1 := preload("res://assets/base/plot_tile/egg1.png")
const _PLOT_ICON_SIZE := Vector2(84, 96)
const _METRIC_BAR_HEIGHT := 28.0
const _METRIC_BAR_TRACK := Color(0.08, 0.1, 0.1, 1)
const _METRIC_BAR_DEALT := Color(0.35, 0.55, 0.9, 1)
const _METRIC_BAR_RECEIVED := Color(0.85, 0.25, 0.3, 1)
const _METRIC_BAR_FONT_SIZE := 18
const _BIOMASS_REWARD_SIZE := Vector2(360, 130)

const _FORMATION_COLORS := {
	WeaponData.FormationLine.FRONT: Color(0.35, 0.75, 0.45),
	WeaponData.FormationLine.MID: Color(0.35, 0.55, 0.9),
	WeaponData.FormationLine.BACK: Color(0.85, 0.65, 0.3),
}

var _biomass_reward_amount := 0
var _biomass_reward_source: Control
var _biomass_gain: BiomassGain
var _biomass_pending_token := 0
var _biomass_delay_left := 0.15
var _biomass_ready_frame := 0
var _continuing := false
var _finishing_pointer_press := false
var _guided_result := false
var _battle_won := false
var _battle_day := 0

@onready var _entries: VBoxContainer = %Entries
@onready var _continue_button: Button = %ContinueButton
@onready var _restart_button: Button = %RestartButton
@onready var _preparation_button: Button = %PreparationButton
@onready var _end_run_button: Button = %EndRunButton
@onready var _retry_help: Label = %RetryHelp
@onready var _title: Label = %Title
@onready var _troop_hp_bar: ProgressBar = %TroopHpBar
@onready var _troop_hp_label: Label = %TroopHpLabel
@onready var _damage_boards: VBoxContainer = %DamageBoards
@onready var _biomass_counter: BiomassChip = %SummaryBiomass
@onready var _biomass_day_spacer: Label = %BiomassDaySpacer
@onready var _biomass_debug_spacer: Button = %BiomassDebugSpacer


func _ready() -> void:
	Audio.play_base_music()
	_title.text = "Day %d => Day %d" % [GameState.current_day, GameState.current_day + 1]
	_guided_result = GameState.is_guided_run and DaySummaryFeed.guided_result
	_battle_won = DaySummaryFeed.battle_won
	_battle_day = DaySummaryFeed.battle_day
	var run_length := GameState.get_run_length()
	var day := clampi(GameState.get_upcoming_day(), 1, run_length)
	_biomass_day_spacer.text = "Day %d / %d" % [day, run_length]
	_configure_result_actions()
	_on_debug_mode_changed(GameState.debug_mode_active)
	GameState.debug_mode_changed.connect(_on_debug_mode_changed)
	_populate_combat_recap()
	_populate_entries(DaySummaryFeed.take_entries())
	if _biomass_reward_amount > 0:
		_biomass_pending_token = _biomass_counter.begin_gain(_biomass_reward_amount)
	_continue_button.pressed.connect(_on_continue_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_preparation_button.pressed.connect(_on_preparation_pressed)
	_end_run_button.pressed.connect(_on_end_run_pressed)
	_biomass_ready_frame = Engine.get_process_frames() + 2
	set_process(_biomass_reward_amount > 0)


func _configure_result_actions() -> void:
	_continue_button.visible = not _guided_result or _battle_won
	_restart_button.visible = _guided_result
	_preparation_button.visible = _guided_result
	_end_run_button.visible = _guided_result
	_retry_help.visible = _guided_result
	if not _guided_result:
		return
	_title.text = "Day %d · %s" % [_battle_day, "Victory" if _battle_won else "Battle lost"]
	_restart_button.theme_type_variation = &"NavButton" if _battle_won else &"PrimaryButton"
	if _battle_won and GameState.has_won_run():
		_continue_button.text = "Finish Guided Run"


func _on_debug_mode_changed(is_active: bool) -> void:
	_biomass_debug_spacer.visible = is_active


func _process(delta: float) -> void:
	_biomass_delay_left = maxf(_biomass_delay_left - delta, 0.0)
	if (
		_biomass_delay_left > 0.0 or Engine.get_process_frames() < _biomass_ready_frame
		or SceneTransition.is_transitioning()
	):
		return
	set_process(false)
	if _continuing or not is_instance_valid(_biomass_reward_source):
		return
	var source_rect := _biomass_reward_source.get_global_transform_with_canvas() * Rect2(
		Vector2.ZERO, _biomass_reward_source.size
	)
	_biomass_gain = BiomassGain.play(self, source_rect, _biomass_reward_amount, _biomass_counter, true)
	_biomass_pending_token = 0
	_biomass_gain.cancelled.connect(_on_biomass_gain_cancelled)


func _on_biomass_gain_cancelled() -> void:
	_biomass_gain = null
	_show_biomass_reward_total()


func _show_biomass_reward_total() -> void:
	if _continuing or not is_inside_tree() or not is_instance_valid(_biomass_reward_source):
		return
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_biomass_reward_source.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var amount := BiomassDisplay.make_amount(
		BiomassDisplay.number(_biomass_reward_amount, true), 64, Color("f1d980"), true
	)
	(amount.get_child(0) as Label).add_theme_constant_override("outline_size", 7)
	center.add_child(amount)


func _input(event: InputEvent) -> void:
	var pressed := false
	var pointer_position := Vector2.ZERO
	if event is InputEventMouseButton:
		if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			return
		pressed = event.pressed
		pointer_position = event.position
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		pointer_position = event.position
	else:
		return
	if _finishing_pointer_press:
		get_viewport().set_input_as_handled()
		if not pressed:
			# Touch and its emulated mouse release can arrive in either order.
			_clear_finishing_pointer_press.call_deferred()
		return
	if _is_over_result_action(pointer_position):
		# Result actions remain available on the first click during a reward.
		return
	if pressed and _finish_biomass_animation():
		# Consume the whole gesture, including the mouse events emulated from a tap.
		_finishing_pointer_press = true
		get_viewport().set_input_as_handled()


func _is_over_result_action(pointer_position: Vector2) -> bool:
	for button: Button in [_continue_button, _restart_button, _preparation_button, _end_run_button]:
		if not button.is_visible_in_tree():
			continue
		var button_position := button.get_global_transform_with_canvas().affine_inverse() * pointer_position
		if Rect2(Vector2.ZERO, button.size).has_point(button_position):
			return true
	return false


func _clear_finishing_pointer_press() -> void:
	_finishing_pointer_press = false


func _finish_biomass_animation() -> bool:
	if _continuing:
		return false
	if _biomass_pending_token > 0:
		set_process(false)
		_biomass_counter.end_gain(_biomass_pending_token)
		_biomass_pending_token = 0
		_show_biomass_reward_total()
		Audio.play_owned_ui_cue(self, Sfx.Cue.BIOMASS_COMPLETE)
		return true
	if is_instance_valid(_biomass_gain) and not _biomass_gain.is_finished():
		_biomass_gain.finish_immediately()
		return true
	return false


func _populate_combat_recap() -> void:
	_apply_troop_hp(DaySummaryFeed.troop_hp_current, DaySummaryFeed.troop_hp_max)
	for child in _damage_boards.get_children():
		child.queue_free()

	var rows := DaySummaryFeed.unit_damage_rows
	var max_dealt := 0
	for row in rows:
		max_dealt = maxi(max_dealt, int(row.get("dealt", 0)))

	if rows.is_empty():
		var empty := _make_entry_label("—")
		empty.theme_type_variation = &"PageSubtitleLabel"
		_damage_boards.add_child(empty)
	else:
		for row in rows:
			var unit := row.get("unit") as RosterUnitData
			if unit == null:
				continue
			_damage_boards.add_child(_make_unit_damage_row(
				unit,
				int(row.get("dealt", 0)),
				int(row.get("taken", 0)),
				max_dealt,
				int(row.get("max_hp", 0))
			))

	DaySummaryFeed.troop_hp_current = 0
	DaySummaryFeed.troop_hp_max = 0
	DaySummaryFeed.unit_damage_rows.clear()


func _apply_troop_hp(current: int, maximum: int) -> void:
	var max_hp := maxi(maximum, 1)
	_troop_hp_bar.max_value = max_hp
	_troop_hp_bar.value = clampi(current, 0, max_hp)
	_troop_hp_label.text = "%d / %d" % [current, maximum]


func _make_unit_damage_row(
	unit: RosterUnitData,
	dealt: int,
	taken: int,
	max_dealt: int,
	unit_max_hp: int
) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var host := Control.new()
	host.custom_minimum_size = _DAMAGE_PORTRAIT_HOST_SIZE
	host.size = _DAMAGE_PORTRAIT_HOST_SIZE
	host.clip_contents = true
	host.set_meta("_portrait_fit", true)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(host)
	unit.mount_portrait(host, _DAMAGE_PORTRAIT_SCALE)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 4)

	var name_label := _make_metric_label(unit.display_name)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	text_col.add_child(name_label)

	text_col.add_child(_make_metric_bar(
		"Damage dealt: %d" % dealt,
		dealt,
		max_dealt,
		_METRIC_BAR_DEALT
	))
	var hp_basis := unit_max_hp
	if hp_basis <= 0 and unit.stats != null:
		hp_basis = unit.stats.get_max_hp()
	text_col.add_child(_make_metric_bar(
		"HP Lost: %d" % taken,
		taken,
		hp_basis,
		_METRIC_BAR_RECEIVED,
		true
	))

	row.add_child(text_col)
	return row


func _make_metric_bar(
	label_text: String,
	value: int,
	max_value: int,
	fill_color: Color,
	clamp_fill: bool = false
) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, _METRIC_BAR_HEIGHT)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.max_value = 1.0
	var ratio := 0.0
	if max_value > 0:
		ratio = float(value) / float(max_value)
		if clamp_fill:
			ratio = minf(ratio, 1.0)
	bar.value = ratio
	bar.add_theme_stylebox_override("background", _make_bar_style(_METRIC_BAR_TRACK))
	bar.add_theme_stylebox_override("fill", _make_bar_style(fill_color))

	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", _METRIC_BAR_FONT_SIZE)
	bar.add_child(label)
	return bar


func _make_bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	return style


func _make_metric_label(text: String) -> Label:
	var label := _make_entry_label(text)
	label.add_theme_font_size_override("font_size", 28)
	return label


func _populate_entries(entries: Array[Dictionary]) -> void:
	for child in _entries.get_children():
		child.queue_free()
	_biomass_reward_amount = 0
	_biomass_reward_source = null
	for entry in entries:
		if bool(entry.get("biomass", false)):
			_biomass_reward_amount += maxi(int(entry.get("biomass_amount", 0)), 0)

	if entries.is_empty():
		_entries.add_child(_make_message_row("Nothing notable happened today."))
		return

	for entry in entries:
		var text := str(entry.get("text", ""))
		var unit := entry.get("unit") as RosterUnitData
		if unit != null:
			var spore_tint := Color.WHITE
			var show_spore := bool(entry.get("emitted_spores", false))
			if show_spore and entry.has("spore_tint"):
				spore_tint = entry.get("spore_tint") as Color
			_entries.add_child(_make_unit_row(text, unit, show_spore, spore_tint))
			continue
		if bool(entry.get("biomass", false)):
			if int(entry.get("biomass_amount", 0)) > 0:
				if _biomass_reward_source == null:
					_biomass_reward_source = Control.new()
					_biomass_reward_source.name = "BiomassRewardSource"
					_biomass_reward_source.custom_minimum_size = _BIOMASS_REWARD_SIZE
					_biomass_reward_source.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					_biomass_reward_source.mouse_filter = Control.MOUSE_FILTER_IGNORE
					_entries.add_child(_biomass_reward_source)
				continue
			_entries.add_child(_make_entry_label(text))
			continue
		if bool(entry.get("nursery_ready", false)):
			_entries.add_child(_make_nursery_row(
				text,
				entry.get("tint", Color.WHITE) as Color,
				bool(entry.get("as_imago", false))
			))
			continue
		var formation_line := int(entry.get("formation_line", -1))
		if formation_line >= 0:
			_entries.add_child(_make_icon_row(text, formation_line))
		else:
			_entries.add_child(_make_message_row(text))


func _make_message_row(text: String) -> Control:
	return _make_entry_label(text)


func _make_entry_label(text: String) -> Control:
	if "biomass" in text:
		var rich := StatDisplay.make_rich_label(
			text,
			get_theme_font_size("font_size", "SummaryEntryLabel"),
			get_theme_color("font_color", "SummaryEntryLabel")
		)
		rich.add_theme_font_override("normal_font", get_theme_font("font", "SummaryEntryLabel"))
		rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rich.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return rich
	var label := Label.new()
	label.theme_type_variation = &"SummaryEntryLabel"
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _make_unit_row(
	text: String,
	unit: RosterUnitData,
	show_spore: bool = false,
	spore_tint: Color = Color.WHITE
) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var host := Control.new()
	host.custom_minimum_size = _PORTRAIT_HOST_SIZE
	host.size = _PORTRAIT_HOST_SIZE
	host.clip_contents = true
	host.set_meta("_portrait_fit", true)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(host)
	unit.mount_portrait(host, _PORTRAIT_SCALE)
	row.add_child(_make_entry_label(text))
	if show_spore:
		var spore_icon := TextureRect.new()
		spore_icon.custom_minimum_size = _SPORE_ICON_SIZE
		spore_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		spore_icon.texture = _SPORE_ICON
		spore_icon.modulate = spore_tint if spore_tint != Color.WHITE else Color.WHITE
		spore_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spore_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(spore_icon)

	return row


func _make_nursery_row(text: String, tint: Color, as_imago: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var host := Control.new()
	host.custom_minimum_size = _PLOT_ICON_SIZE
	host.size = _PLOT_ICON_SIZE
	host.clip_contents = true
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var bed := TextureRect.new()
	bed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bed.texture = _PLOT_EMPTY
	bed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bed.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.add_child(bed)

	var egg := TextureRect.new()
	egg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	egg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	egg.texture = _EGG1 if as_imago else _EGG0
	egg.modulate = tint
	egg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	egg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.add_child(egg)

	row.add_child(host)
	row.add_child(_make_entry_label(text))
	return row


func _make_icon_row(text: String, formation_line: int) -> Control:
	var row := HBoxContainer.new()

	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.color = _FORMATION_COLORS.get(formation_line, Color(0.7, 0.7, 0.7))
	row.add_child(icon)
	row.add_child(_make_entry_label(text))

	return row


func _on_continue_pressed() -> void:
	if _continuing or (_guided_result and not _battle_won):
		return
	if _guided_result:
		DaySummaryFeed.clear()
		if GameState.has_won_run():
			Analytics.run_complete()
			GameState.finish_run(true)
			_leave_result(_VICTORY_SCENE_PATH)
			return
	_leave_result(_BASE_SCENE_PATH)


func _on_restart_pressed() -> void:
	if _continuing or not _guided_result:
		return
	if not GameState.restart_guided_battle():
		return
	_leave_result(_COMBAT_SCENE_PATH)


func _on_preparation_pressed() -> void:
	if _continuing or not _guided_result:
		return
	if not GameState.restore_guided_preparation():
		return
	_leave_result(_BASE_SCENE_PATH)


func _on_end_run_pressed() -> void:
	if _continuing or not _guided_result:
		return
	# End the last accepted Day, not the provisional victory being discarded.
	if not GameState.restore_guided_preparation():
		return
	Analytics.day_fail()
	Analytics.run_fail()
	GameState.finish_run()
	_leave_result(_GAME_OVER_SCENE_PATH)


func _leave_result(scene_path: String) -> void:
	_continuing = true
	set_process(false)
	_cancel_biomass_gain()
	SceneTransition.change_scene(scene_path)


func _exit_tree() -> void:
	_continuing = true
	_cancel_biomass_gain()


func _cancel_biomass_gain() -> void:
	if _biomass_pending_token > 0 and is_instance_valid(_biomass_counter):
		_biomass_counter.end_gain(_biomass_pending_token)
		_biomass_pending_token = 0
	if not is_instance_valid(_biomass_gain):
		return
	var effect := _biomass_gain
	_biomass_gain = null
	effect.cancel()
