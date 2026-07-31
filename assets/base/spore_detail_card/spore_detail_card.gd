class_name SporeDetailCard
extends Control

const CARD_SIZE := Vector2(240, 280)
const CARD_SIZE_WITH_PLOT := Vector2(240, 360)
const _MOCK_SPORE_PATH := "res://assets/base/nursery/common_spore.tres"

var spore_data: SporeData
var plot_data: NurseryPlotData
var interactive: bool = true
## When true, footer shows buy cost instead of sell value (shop tooltips).
var show_buy_price: bool = false

@onready var _name_label: Label = %NameLabel
@onready var _desc_label: Label = %DescLabel
@onready var _days_chip: StatChip = %DaysChip
@onready var _tier_tag: TagChip = %TierTag
@onready var _hatch_tag: TagChip = %HatchTag
@onready var _sell_row: HBoxContainer = %SellRow
@onready var _sell_label: Label = %SellLabel
@onready var _plot_section: VBoxContainer = %PlotSection
@onready var _status_label: Label = %StatusLabel
@onready var _plot_info_label: Label = %PlotInfoLabel


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
	_days_chip.set_value(spore_data.days_to_mature)
	_refresh_price_row()
	_refresh_tags(strain)
	_refresh_plot_section()


func _refresh_price_row() -> void:
	if _sell_row == null or _sell_label == null:
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


func _plot_status_text() -> String:
	match plot_data.get_state():
		NurseryPlotData.State.EMPTY:
			return "Empty"
		NurseryPlotData.State.GROWING:
			var left := maxi(plot_data.days_to_mature_effective() - plot_data.days_grown, 0)
			return "Growing — %d day%s left" % [left, "" if left == 1 else "s"]
		NurseryPlotData.State.READY:
			if plot_data.will_harvest_as_imago():
				return "Ready — Imago"
			return "Ready"
	return ""


func _plot_info_text() -> String:
	var lines: PackedStringArray = []
	var residue := plot_data.fungicide_residue_text()
	if not residue.is_empty():
		lines.append(residue)
	for fert in plot_data.applied_fertilizers:
		if fert == null:
			continue
		if fert.behavior == FertilizerData.Behavior.FUNGICIDE:
			continue
		lines.append("%s (%s)" % [fert.display_name, fert.subtitle_text()])
	return "\n".join(lines)


func _apply_interaction_mode() -> void:
	mouse_filter = (
		Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	)


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
