class_name SporeDetailCard
extends Control

const CARD_WIDTH := 390.0
const _MOCK_SPORE_PATH := "res://assets/base/nursery/common_spore.tres"

var spore_data: SporeData
var plot_data: NurseryPlotData
var interactive: bool = true
## When true, footer shows buy cost instead of sell value (shop tooltips).
var show_buy_price: bool = false
var _preview_unit: RosterUnitData = null

@onready var _card_panel: PanelContainer = $CardPanel
@onready var _name_label: Label = %NameLabel
@onready var _grow_label: Label = %GrowLabel
@onready var _days_chip: StatChip = %DaysChip
@onready var _days_suffix_label: Label = %DaysSuffixLabel
@onready var _sell_row: HBoxContainer = %SellRow
@onready var _sell_label: Label = %SellLabel
@onready var _footer_row: HBoxContainer = %FooterRow
## Typed at runtime via unit_detail_card_content.gd (class_name UnitDetailCardContent).
@onready var _unit_content = %UnitDetailCardContent


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
	return CARD_WIDTH


func card_size() -> Vector2:
	if custom_minimum_size.x > 0.0 and custom_minimum_size.y > 0.0:
		return custom_minimum_size
	if size.x > 0.0 and size.y > 0.0:
		return size
	return Vector2(CARD_WIDTH, 200.0)


func reset_compact_layout() -> void:
	fit_to_content()


func fit_to_content() -> void:
	if not is_node_ready() or _card_panel == null:
		return
	if _unit_content != null:
		_unit_content.apply_portrait_layout()
	DetailCardFit.apply(self, _card_panel, CARD_WIDTH)


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
	_refresh_growth_row()
	_refresh_price_row()
	_refresh_unit_content()


func _refresh_growth_row() -> void:
	if plot_data != null:
		_grow_label.text = "Remaining Time:"
		var left := plot_data.remaining_days()
		_days_chip.set_value(left)
	else:
		_grow_label.text = "Growth Time:"
		_days_chip.set_value(spore_data.days_to_mature_effective())
	_days_suffix_label.text = "days"


func _refresh_price_row() -> void:
	if _sell_row == null or _sell_label == null or _footer_row == null:
		return
	if plot_data != null:
		_footer_row.visible = false
		return
	_footer_row.visible = true
	_sell_row.visible = true
	if show_buy_price:
		_sell_label.text = "Buy: %d" % spore_data.biomass_cost
	else:
		_sell_label.text = "Sell: %d" % BiomassData.sell_value(spore_data.biomass_cost)


func _refresh_unit_content() -> void:
	_preview_unit = _make_preview_unit()
	if _unit_content == null:
		return
	if _preview_unit == null:
		_unit_content.visible = false
		return
	_unit_content.visible = true
	var residue := ""
	if plot_data != null:
		residue = plot_data.fungicide_residue_text()
	_unit_content.setup(_preview_unit, true, residue)


## Generation of the Child that would hatch from this spore.
func _preview_generation() -> int:
	if spore_data != null and spore_data.is_lineage_spore():
		return maxi(spore_data.parent_generation, 1) + 1
	return 1


## Expected hatch averages (tier mid / lineage mean) plus plot modifiers.
## Mirrors NurseryData hatch order without rolling variance.
func _preview_average_stats() -> UnitStatsData:
	if spore_data == null:
		return null
	var stats: UnitStatsData
	if spore_data.is_lineage_spore() and spore_data.mean_stats != null:
		stats = spore_data.mean_stats.duplicate(true) as UnitStatsData
	else:
		stats = UnitStatsData.average_for_tier(spore_data.power_tier)
	_apply_preview_plot_stat_modifiers(stats)
	var body := _preview_body_mutation()
	var cap := _preview_cap_mutation()
	if body != null:
		body.apply_hatch_stats(stats)
	if cap != null:
		cap.apply_hatch_stats(stats)
	_apply_preview_yield_stat_scale(stats)
	return stats


func _apply_preview_plot_stat_modifiers(stats: UnitStatsData) -> void:
	if stats == null or plot_data == null:
		return
	for fert in plot_data.applied_fertilizers:
		if fert == null:
			continue
		if fert.is_stat_source():
			fert.apply_to(stats)
	var pending := plot_data.pending_stat_bonus
	if pending != 0:
		stats.strength = clampi(stats.strength + pending, 1, 99)
		stats.dex = clampi(stats.dex + pending, 1, 99)
		stats.con = clampi(stats.con + pending, 1, 99)
		stats.spd = clampi(stats.spd + pending, 1, 99)


## Meiosis / Triploid scale one expected unit the same way harvest does per yield.
func _apply_preview_yield_stat_scale(stats: UnitStatsData) -> void:
	if stats == null or plot_data == null:
		return
	var meiosis := false
	var triploid := false
	for fert in plot_data.applied_fertilizers:
		if fert == null:
			continue
		match fert.behavior:
			FertilizerData.Behavior.MEIOSIS:
				meiosis = true
			FertilizerData.Behavior.TRIPLOID:
				triploid = true
	if meiosis:
		stats.strength = maxi(1, roundi(float(stats.strength) * 0.5))
		stats.dex = maxi(1, roundi(float(stats.dex) * 0.5))
		stats.con = maxi(1, roundi(float(stats.con) * 0.5))
		stats.spd = maxi(1, roundi(float(stats.spd) * 0.5))
	if triploid:
		stats.strength = maxi(1, roundi(float(stats.strength) / 3.0))
		stats.dex = maxi(1, roundi(float(stats.dex) / 3.0))
		stats.con = maxi(1, roundi(float(stats.con) / 3.0))
		stats.spd = maxi(1, roundi(float(stats.spd) / 3.0))


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


func _apply_interaction_mode() -> void:
	mouse_filter = (
		Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	)


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
