class_name SporeDetailCard
extends Control

const CARD_WIDTH := 320.0
const CARD_WIDTH_WITH_PLOT := 430.0
const PORTRAIT_HOST_HEIGHT := 140.0
const PORTRAIT_SCALE := 0.7
const PORTRAIT_SHADOW_CLEARANCE := 16.0
const _TRAINING_ICON_SIZE := Vector2(48, 48)
const _MOCK_SPORE_PATH := "res://assets/base/nursery/common_spore.tres"

var spore_data: SporeData
var plot_data: NurseryPlotData
var interactive: bool = true
## When true, footer shows buy cost instead of sell value (shop tooltips).
var show_buy_price: bool = false
var _portrait_instance: Node2D = null
var _preview_unit: RosterUnitData = null

@onready var _card_panel: PanelContainer = $CardPanel
@onready var _name_label: Label = %NameLabel
@onready var _desc_label: Label = %DescLabel
@onready var _grow_label: Label = %GrowLabel
@onready var _days_chip: StatChip = %DaysChip
@onready var _days_suffix_label: Label = %DaysSuffixLabel
@onready var _tier_tag: TagChip = %TierTag
@onready var _hatch_tag: TagChip = %HatchTag
@onready var _sell_row: HBoxContainer = %SellRow
@onready var _sell_label: Label = %SellLabel
@onready var _plot_section: VBoxContainer = %PlotSection
@onready var _status_label: Label = %StatusLabel
@onready var _plot_info_label: Label = %PlotInfoLabel
## Typed at runtime via unit_detail_card_content.gd (class_name UnitDetailCardContent).
@onready var _unit_content = %UnitDetailCardContent
@onready var _lineage_section: VBoxContainer = %LineageSection
@onready var _portrait_host: Control = %PortraitHost
@onready var _child_name_label: Label = %ChildNameLabel
@onready var _str_label: Label = %StrLabel
@onready var _dex_label: Label = %DexLabel
@onready var _con_label: Label = %ConLabel
@onready var _spd_label: Label = %SpdLabel
@onready var _trainings_label: Label = %TrainingsLabel
@onready var _trainings_row: HBoxContainer = %TrainingsRow
@onready var _mutations_label: Label = %MutationsLabel
@onready var _footer_spacer: Control = $CardPanel/Margin/VBox/FooterSpacer
@onready var _footer_row: HBoxContainer = $CardPanel/Margin/VBox/FooterRow


func setup(
	spore: SporeData,
	p_interactive: bool = true,
	plot: NurseryPlotData = null,
	p_show_buy_price: bool = false
) -> void:
	spore_data = spore
	plot_data = plot
	interactive = p_interactive
	show_buy_price = p_show_buy_price
	if is_node_ready():
		_apply_interaction_mode()
		_refresh()
		fit_to_content()
	else:
		ready.connect(_on_setup_ready, CONNECT_ONE_SHOT)


func _on_setup_ready() -> void:
	_apply_interaction_mode()
	_refresh()
	fit_to_content()


func card_width() -> float:
	return CARD_WIDTH_WITH_PLOT if plot_data != null else CARD_WIDTH


func card_size() -> Vector2:
	if custom_minimum_size.x > 0.0 and custom_minimum_size.y > 0.0:
		return custom_minimum_size
	if size.x > 0.0 and size.y > 0.0:
		return size
	return Vector2(card_width(), PORTRAIT_HOST_HEIGHT)


func reset_compact_layout() -> void:
	fit_to_content()


func fit_to_content() -> void:
	if not is_node_ready() or _card_panel == null:
		return
	if _portrait_host != null:
		_portrait_host.clip_contents = false
		_portrait_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_portrait_host.custom_minimum_size = Vector2(0.0, PORTRAIT_HOST_HEIGHT)
	if _unit_content != null and _unit_content.visible:
		_unit_content.apply_portrait_layout()
	if _footer_spacer != null:
		_footer_spacer.visible = false
		_footer_spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	DetailCardFit.apply(self, _card_panel, card_width())


func _ready() -> void:
	_set_children_mouse_filter_ignore(self)
	_apply_interaction_mode()
	if spore_data == null and get_tree().current_scene == self:
		spore_data = load(_MOCK_SPORE_PATH) as SporeData
	if spore_data != null:
		_refresh()
	fit_to_content()


func _refresh() -> void:
	if spore_data == null:
		return
	_name_label.text = spore_data.display_name
	_desc_label.text = ""
	_desc_label.visible = false
	_refresh_growth_row()
	_refresh_price_row()
	_refresh_tags()
	_refresh_plot_section()
	_refresh_hatch_preview()


func _refresh_growth_row() -> void:
	if plot_data != null:
		_grow_label.text = "Remaining Time:"
		var left := maxi(plot_data.days_to_mature_effective() - plot_data.days_grown, 0)
		_days_chip.set_value(left)
	else:
		_grow_label.text = "Growth Time:"
		_days_chip.set_value(spore_data.days_to_mature_effective())
	_days_suffix_label.text = "days"


func _refresh_price_row() -> void:
	if _sell_row == null or _sell_label == null:
		return
	if plot_data != null:
		_sell_row.visible = false
		return
	_sell_row.visible = true
	if show_buy_price:
		_sell_label.text = "Buy: %d" % spore_data.biomass_cost
	else:
		_sell_label.text = "Sell: %d" % BiomassData.sell_value(spore_data.biomass_cost)


func _refresh_tags() -> void:
	_hatch_tag.visible = false
	if plot_data != null:
		# Generation lives on the embedded unit detail content in plot mode.
		_tier_tag.visible = false
		if _footer_row != null:
			_footer_row.visible = false
		return
	_tier_tag.visible = true
	if _footer_row != null:
		_footer_row.visible = true
	var generation := _preview_generation()
	_tier_tag.set_text(UnitNames.format_generation_label(generation))
	_tier_tag.set_fill_color(UnitStatsData.tint_for_generation(generation))


func _refresh_plot_section() -> void:
	if plot_data == null:
		_plot_section.visible = false
		return
	_plot_section.visible = true
	_status_label.text = _plot_status_text()
	var residue := plot_data.fungicide_residue_text()
	_plot_info_label.text = residue
	_plot_info_label.visible = not residue.is_empty()


func _refresh_hatch_preview() -> void:
	_preview_unit = _make_preview_unit()
	if plot_data != null:
		_refresh_plot_unit_content()
		return
	_refresh_stock_lineage_section()


func _refresh_plot_unit_content() -> void:
	if _lineage_section != null:
		_lineage_section.visible = false
	_clear_portrait()
	_clear_trainings_row()
	if _unit_content == null:
		return
	if _preview_unit == null:
		_unit_content.visible = false
		return
	_unit_content.visible = true
	_unit_content.setup(_preview_unit, true)
	if _footer_spacer != null:
		_footer_spacer.visible = false


func _refresh_stock_lineage_section() -> void:
	if _unit_content != null:
		_unit_content.visible = false
	if _lineage_section == null or spore_data == null:
		return
	var lineage := spore_data.is_lineage_spore()
	_lineage_section.visible = true
	if _footer_spacer != null:
		_footer_spacer.visible = false
	if lineage:
		_child_name_label.visible = true
		_trainings_label.visible = true
		_trainings_row.visible = true
		_child_name_label.text = _preview_unit.display_name if _preview_unit != null else ""
		_refresh_trainings_row()
	else:
		_child_name_label.visible = false
		_trainings_label.visible = false
		_trainings_row.visible = false
		_clear_trainings_row()
	_refresh_mutations_label()
	_refresh_mean_stats()
	_refresh_portrait()


## Generation of the Child that would hatch from this spore.
func _preview_generation() -> int:
	if spore_data != null and spore_data.is_lineage_spore():
		return maxi(spore_data.parent_generation, 1) + 1
	return 1


func _refresh_mean_stats() -> void:
	var stats := _preview_average_stats()
	if stats == null:
		_str_label.text = "STR —"
		_dex_label.text = "DEX —"
		_con_label.text = "CON —"
		_spd_label.text = "SPD —"
		return
	_str_label.text = "STR %d" % stats.strength
	_dex_label.text = "DEX %d" % stats.dex
	_con_label.text = "CON %d" % stats.con
	_spd_label.text = "SPD %d" % stats.spd


func _preview_average_stats() -> UnitStatsData:
	if spore_data == null:
		return null
	if spore_data.is_lineage_spore() and spore_data.mean_stats != null:
		return spore_data.mean_stats
	var stats := UnitStatsData.average_for_tier(spore_data.power_tier)
	var body := _preview_body_mutation()
	var cap := _preview_cap_mutation()
	if body != null:
		body.apply_hatch_stats(stats)
	if cap != null:
		cap.apply_hatch_stats(stats)
	return stats


func _refresh_trainings_row() -> void:
	_clear_trainings_row()
	if _trainings_row == null or spore_data == null:
		return
	var trainings := spore_data.weapon_trainings
	if trainings.is_empty():
		_trainings_label.text = "Trainings: none"
		var none_label := Label.new()
		none_label.text = "—"
		none_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_label.add_theme_font_size_override("font_size", 22)
		none_label.add_theme_color_override(
			"font_color",
			Color(0.03137255, 0.03529412, 0.02745098, 1)
		)
		_trainings_row.add_child(none_label)
		return
	_trainings_label.text = "Trainings"
	for school in trainings:
		var weapon := WeaponSchool.load_weapon(WeaponSchool.base_weapon_path(int(school)))
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 2)
		var icon := TextureRect.new()
		icon.custom_minimum_size = _TRAINING_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if weapon != null:
			icon.texture = weapon.icon
		cell.add_child(icon)
		var label := Label.new()
		label.text = WeaponSchool.display_name(int(school))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override(
			"font_color",
			Color(0.03137255, 0.03529412, 0.02745098, 1)
		)
		cell.add_child(label)
		_trainings_row.add_child(cell)


func _clear_trainings_row() -> void:
	if _trainings_row == null:
		return
	for child in _trainings_row.get_children():
		child.queue_free()


func _refresh_mutations_label() -> void:
	if _mutations_label == null or spore_data == null:
		return
	# Plot tooltips list Mutations on the embedded unit card; stock lineage shows prepared slots.
	if plot_data != null or not spore_data.is_lineage_spore():
		_mutations_label.visible = false
		return
	var body_line := "Body: —"
	if spore_data.body_mutation != null:
		body_line = "Body: %s — %s" % [
			spore_data.body_mutation.display_name,
			spore_data.body_mutation.subtitle_text(),
		]
	var cap_line := "Cap: —"
	if spore_data.cap_mutation != null:
		cap_line = "Cap: %s — %s" % [
			spore_data.cap_mutation.display_name,
			spore_data.cap_mutation.subtitle_text(),
		]
	_mutations_label.visible = true
	_mutations_label.text = "Mutations\n%s\n%s" % [body_line, cap_line]


func _make_preview_unit() -> RosterUnitData:
	if spore_data == null:
		return null
	var lineage := spore_data.is_lineage_spore()
	var child_gen := _preview_generation()
	var child_name := "Child"
	if lineage:
		child_name = UnitNames.format_unit_name(spore_data.lineage_name, child_gen)
	var stats := _preview_average_stats()
	if stats != null:
		stats = stats.duplicate(true) as UnitStatsData
	else:
		stats = UnitStatsData.new()
	var tier := spore_data.power_tier
	var unit := RosterUnitData.create(
		child_name,
		stats,
		WeaponSchool.sickle(),
		tier
	)
	if lineage:
		unit.lineage_name = spore_data.lineage_name
		unit.generation = child_gen
		unit.display_name = child_name
		unit.weapon_trainings = []
		for training in spore_data.weapon_trainings:
			unit.weapon_trainings.append(int(training))
	unit.body_mutation = (
		spore_data.body_mutation.duplicate(true) as MutationData
		if spore_data.body_mutation != null
		else null
	)
	unit.cap_mutation = (
		spore_data.cap_mutation.duplicate(true) as MutationData
		if spore_data.cap_mutation != null
		else null
	)
	unit.sync_weapon_from_trainings()
	_apply_preview_mutations(unit)
	_apply_preview_fertilizers(unit)
	return unit


## Growing-plot / lineage tooltips show Body/Cap assigned on the plot or spore.
func _apply_preview_mutations(unit: RosterUnitData) -> void:
	if unit == null:
		return
	var body := _preview_body_mutation()
	var cap := _preview_cap_mutation()
	if body != null:
		unit.body_mutation = body.duplicate(true) as MutationData
	if cap != null:
		unit.cap_mutation = cap.duplicate(true) as MutationData


func _apply_preview_fertilizers(unit: RosterUnitData) -> void:
	if unit == null:
		return
	unit.applied_fertilizers = []
	if plot_data == null:
		return
	for fert in plot_data.applied_fertilizers:
		if fert == null or fert.behavior == FertilizerData.Behavior.FUNGICIDE:
			continue
		unit.applied_fertilizers.append(fert)


func _preview_body_mutation() -> MutationData:
	if plot_data != null and plot_data.body_mutation != null:
		return plot_data.body_mutation
	if spore_data != null:
		return spore_data.body_mutation
	return null


func _preview_cap_mutation() -> MutationData:
	if plot_data != null and plot_data.cap_mutation != null:
		return plot_data.cap_mutation
	if spore_data != null:
		return spore_data.cap_mutation
	return null


func _refresh_portrait() -> void:
	_clear_portrait()
	if _portrait_host == null or _preview_unit == null:
		return
	_portrait_instance = _preview_unit.mount_portrait(
		_portrait_host,
		PORTRAIT_SCALE,
		PORTRAIT_SHADOW_CLEARANCE
	)


func _clear_portrait() -> void:
	if _portrait_instance != null:
		if is_instance_valid(_portrait_instance):
			_portrait_instance.queue_free()
		_portrait_instance = null


func _plot_status_text() -> String:
	match plot_data.get_state():
		NurseryPlotData.State.EMPTY:
			return "Status: Empty"
		NurseryPlotData.State.GROWING:
			return "Status: Growing"
		NurseryPlotData.State.READY:
			return "Status: Ready for Harvest"
	return ""


func _apply_interaction_mode() -> void:
	mouse_filter = (
		Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	)


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
