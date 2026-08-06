class_name SporeDetailCard
extends Control

const CARD_SIZE := Vector2(320, 560)
const CARD_SIZE_WITH_PLOT := Vector2(430, 640)
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
@onready var _lineage_section: VBoxContainer = %LineageSection
@onready var _portrait_host: Control = %PortraitHost
@onready var _child_name_label: Label = %ChildNameLabel
@onready var _generation_label: Label = %GenerationLabel
@onready var _str_label: Label = %StrLabel
@onready var _dex_label: Label = %DexLabel
@onready var _con_label: Label = %ConLabel
@onready var _spd_label: Label = %SpdLabel
@onready var _trainings_label: Label = %TrainingsLabel
@onready var _trainings_row: HBoxContainer = %TrainingsRow
@onready var _footer_spacer: Control = $CardPanel/Margin/VBox/FooterSpacer


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
		reset_compact_layout()
		_refresh()
	else:
		ready.connect(_on_setup_ready, CONNECT_ONE_SHOT)


func _on_setup_ready() -> void:
	_apply_interaction_mode()
	reset_compact_layout()
	_refresh()


func card_size() -> Vector2:
	return CARD_SIZE_WITH_PLOT if plot_data != null else CARD_SIZE


func reset_compact_layout() -> void:
	var size_for_mode := card_size()
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	anchor_right = anchor_left
	anchor_bottom = anchor_top
	offset_left = 0.0
	offset_top = 0.0
	offset_right = size_for_mode.x
	offset_bottom = size_for_mode.y
	custom_minimum_size = size_for_mode
	size = size_for_mode
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _ready() -> void:
	_set_children_mouse_filter_ignore(self)
	_apply_interaction_mode()
	reset_compact_layout()
	if spore_data == null and get_tree().current_scene == self:
		spore_data = load(_MOCK_SPORE_PATH) as SporeData
	if spore_data != null:
		_refresh()


func _refresh() -> void:
	if spore_data == null:
		return
	_name_label.text = spore_data.display_name
	var strain := spore_data.resolved_strain()
	var desc := ""
	if strain != null:
		desc = strain.short_description.strip_edges()
	_desc_label.text = desc
	_desc_label.visible = not desc.is_empty()
	_refresh_growth_row()
	_refresh_price_row()
	_refresh_tags(strain)
	_refresh_plot_section()
	_refresh_lineage_section()
	reset_compact_layout()


func _refresh_growth_row() -> void:
	if plot_data != null:
		_grow_label.text = "Remaining Time:"
		var left := maxi(plot_data.days_to_mature_effective() - plot_data.days_grown, 0)
		_days_chip.set_value(left)
	else:
		_grow_label.text = "Growth Time:"
		_days_chip.set_value(spore_data.days_to_mature)
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


func _refresh_tags(strain: UnitStrain) -> void:
	_tier_tag.visible = true
	_tier_tag.set_text(UnitStatsData.label_for_tier(spore_data.power_tier))
	_tier_tag.set_fill_color(UnitStatsData.tint_for_tier(spore_data.power_tier))

	var hatch_count := 1 if strain == null else strain.hatch_count
	_hatch_tag.visible = hatch_count > 1
	if _hatch_tag.visible:
		_hatch_tag.set_text("x%d" % hatch_count)


func _refresh_plot_section() -> void:
	if plot_data == null:
		_plot_section.visible = false
		return
	_plot_section.visible = true
	_status_label.text = _plot_status_text()
	_plot_info_label.text = _plot_info_text()
	_plot_info_label.visible = not _plot_info_label.text.is_empty()


func _refresh_lineage_section() -> void:
	if _lineage_section == null or spore_data == null:
		return
	var lineage := spore_data.is_lineage_spore()
	_lineage_section.visible = true
	if _footer_spacer != null:
		_footer_spacer.visible = false
	_preview_unit = _make_preview_unit()
	if lineage:
		_child_name_label.visible = true
		_generation_label.visible = true
		_trainings_label.visible = true
		_trainings_row.visible = true
		_child_name_label.text = _preview_unit.display_name if _preview_unit != null else ""
		var child_gen := maxi(spore_data.parent_generation, 1) + 1
		var roman := UnitNames.roman_numeral(child_gen)
		_generation_label.text = (
			"Generation %s" % roman if not roman.is_empty() else "Generation 1"
		)
		_refresh_trainings_row()
	else:
		_child_name_label.visible = false
		_generation_label.visible = false
		_trainings_label.visible = false
		_trainings_row.visible = false
		_clear_trainings_row()
	_refresh_mean_stats()
	_refresh_portrait()


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
	var strain := spore_data.resolved_strain()
	var tier := UnitStatsData.PowerTier.COMMON
	if strain == null or strain.use_power_tier:
		tier = spore_data.power_tier
	var stats := UnitStatsData.average_for_tier(tier)
	if strain != null:
		strain.apply_hatch_stats(stats)
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


func _make_preview_unit() -> RosterUnitData:
	if spore_data == null:
		return null
	var lineage := spore_data.is_lineage_spore()
	var child_gen := 1
	var child_name := "Child"
	if lineage:
		child_gen = maxi(spore_data.parent_generation, 1) + 1
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
		spore_data.resolved_strain(),
		tier
	)
	if lineage:
		unit.lineage_name = spore_data.lineage_name
		unit.generation = child_gen
		unit.display_name = child_name
		unit.weapon_trainings = []
		for training in spore_data.weapon_trainings:
			unit.weapon_trainings.append(int(training))
	unit.sync_weapon_from_trainings()
	return unit


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


func _plot_info_text() -> String:
	var lines: PackedStringArray = []
	var residue := plot_data.fungicide_residue_text()
	if not residue.is_empty():
		lines.append(residue)
	var counts: Dictionary = {}
	var order: Array[FertilizerData] = []
	for fert in plot_data.applied_fertilizers:
		if fert == null:
			continue
		if fert.behavior == FertilizerData.Behavior.FUNGICIDE:
			continue
		var key := fert.display_name
		if not counts.has(key):
			counts[key] = 0
			order.append(fert)
		counts[key] = int(counts[key]) + 1
	for fert in order:
		var count := int(counts.get(fert.display_name, 0))
		var desc := "%s (%s)" % [fert.display_name, fert.subtitle_text()]
		if count > 1:
			lines.append("%d X %s" % [count, desc])
		else:
			lines.append(desc)
	if lines.is_empty():
		return ""
	return "Fertilizers\n" + "\n".join(lines)


func _apply_interaction_mode() -> void:
	mouse_filter = (
		Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	)


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
