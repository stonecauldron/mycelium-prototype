class_name CompostConfirmDialog
extends Control

signal confirmed(unit: RosterUnitData)
signal cancelled

const PORTRAIT_SCALE := 0.7
const PORTRAIT_SHADOW := 20.0
const _COMPOST_ICON := preload("res://assets/base/composting_bin/composting_bin.png")
const _COLOR_NEUTRAL := Color(0.03, 0.035, 0.027, 1)
const _COLOR_UP := Color(0.12, 0.45, 0.18, 1)

var _unit: RosterUnitData

@onready var _dim: ColorRect = %Dim
@onready var _header_icon: TextureRect = %HeaderIcon
@onready var _header_title: Label = %HeaderTitle
@onready var _close_button: Button = %CloseButton
@onready var _unit_title: Label = %UnitTitle
@onready var _left_portrait: Control = %LeftPortrait
@onready var _left_stage: Label = %LeftStage
@onready var _outcome_biomass: RichTextLabel = %OutcomeBiomass
@onready var _outcome_spore: Label = %OutcomeSpore
@onready var _growth_time: Label = %GrowthTime
@onready var _lineage_preview: VBoxContainer = %LineagePreview
@onready var _descendant_title: Label = %DescendantTitle
@onready var _generation: Label = %Generation
@onready var _inherited_trainings: Label = %InheritedTrainings
@onready var _inherited_mutations: Label = %InheritedMutations
@onready var _inherited_stats: Label = %InheritedStats
@onready var _confirm_button: Button = %ConfirmButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_gui_input)
	_close_button.pressed.connect(_on_cancel_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_header_icon.texture = _COMPOST_ICON
	if _unit != null:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_on_cancel_pressed()
			get_viewport().set_input_as_handled()


func setup(unit: RosterUnitData) -> void:
	_unit = unit
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	if _unit == null:
		return
	_header_title.text = "Composting"
	_unit_title.text = "Compost %s" % _unit.display_name
	_clear_portrait(_left_portrait)
	_unit.mount_portrait(_left_portrait, PORTRAIT_SCALE, PORTRAIT_SHADOW)
	_left_stage.text = WeaponSchool.stage_display_name(_unit.life_stage_id)

	var preview := GameState.preview_compost_outcome(_unit)
	var biomass := int(preview.get("biomass", 0))
	var emits_spore := bool(preview.get("emits_spore", false))
	StatDisplay.apply_to(_outcome_biomass, BiomassDisplay.text(biomass, true), 24, _COLOR_UP)
	_lineage_preview.visible = emits_spore
	_growth_time.visible = emits_spore
	if emits_spore:
		var spore := SporeData.from_fallen_unit(_unit)
		_outcome_spore.text = "%s\nAdded to Stock" % spore.display_name
		_outcome_spore.add_theme_color_override("font_color", _COLOR_UP)
		_refresh_lineage_preview(spore)
	else:
		_outcome_spore.text = "No lineage spore\nOnly Adults leave spores."
		_outcome_spore.add_theme_color_override("font_color", _COLOR_NEUTRAL)

	_confirm_button.text = "Compost"
	_confirm_button.icon = null
	_confirm_button.disabled = not GameState.can_compost_unit(_unit)
	_confirm_button.modulate = (
		Color.WHITE if not _confirm_button.disabled else Color(0.55, 0.55, 0.55, 1)
	)


func _refresh_lineage_preview(spore: SporeData) -> void:
	var days := spore.days_to_mature_effective()
	_growth_time.text = "Growth Time: %d %s" % [days, WeaponSchool.day_word(days)]
	_growth_time.tooltip_text = (
		"Plant this lineage spore on an unlocked, empty Plot.\n"
		+ "Planting consumes the spore without paying for a fresh grow.\n"
		+ "Plot Fertilizers may change Remaining Time."
	)
	var child_generation := maxi(spore.parent_generation, 1) + 1
	var child_name := UnitNames.format_unit_name(spore.lineage_name, child_generation)
	_descendant_title.text = "After harvest: %s · Child" % child_name
	_generation.text = "%s → %s · %s Tier unchanged" % [
		UnitNames.format_generation_label(spore.parent_generation),
		UnitNames.format_generation_label(child_generation),
		UnitStatsData.label_for_tier(spore.power_tier),
	]
	var trainings: PackedStringArray = []
	for training in spore.weapon_trainings:
		trainings.append(WeaponSchool.display_name(training))
	var weapon := WeaponSchool.resolve_weapon(spore.weapon_trainings)
	var weapon_name := weapon.display_name if weapon != null else "—"
	_inherited_trainings.text = "Trainings inherited: %s → %s" % [
		" + ".join(trainings) if not trainings.is_empty() else "None",
		weapon_name,
	]
	_inherited_trainings.tooltip_text = (
		"The Child uses this Weapon immediately, including Trainings "
		+ "learned by its parent as an Adult."
	)
	var mutations: PackedStringArray = []
	if spore.body_mutation != null:
		mutations.append(spore.body_mutation.title_text())
	if spore.cap_mutation != null:
		mutations.append(spore.cap_mutation.title_text())
	_inherited_mutations.text = "Mutations inherited: %s" % (
		" + ".join(mutations) if not mutations.is_empty() else "None"
	)
	_inherited_mutations.tooltip_text = "\n".join(spore.mutation_tooltip_lines())
	var mean := spore.mean_stats
	var stats_detail := "Saved Stats: STR %d · DEX %d · CON %d" % [
		mean.strength if mean != null else UnitStatsData.NEUTRAL_STAT,
		mean.dex if mean != null else UnitStatsData.NEUTRAL_STAT,
		mean.con if mean != null else UnitStatsData.NEUTRAL_STAT,
	]
	_inherited_stats.tooltip_text = (
		stats_detail
		+ "\nEach Stat rolls ±1 around its saved value (within 1–99), before Plot modifiers."
		+ "\nA higher Generation does not automatically raise Stats.\n"
		+ "Fertilizer items do not carry onto the spore; baked Stat "
		+ "gains are included in saved Stats."
	)


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
	if not GameState.can_compost_unit(_unit):
		return
	confirmed.emit(_unit)
	queue_free()
