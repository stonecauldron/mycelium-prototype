class_name PlotTile
extends PanelContainer

signal plot_pressed(tile: PlotTile)
signal spore_dropped(tile: PlotTile, data: Dictionary)

const TILE_SIZE := Vector2(220, 260)
const _LOCKED_MODULATE := Color(0.55, 0.55, 0.55, 1.0)
const _DROP_HIGHLIGHT := Color(0.7, 1.0, 0.75, 1.0)

const _TEX_EMPTY := preload("res://assets/base/plot_tile/plot_empty.png")
const _TEX_GROWTH0 := preload("res://assets/base/plot_tile/growth0.png")
const _TEX_GROWTH1 := preload("res://assets/base/plot_tile/growth1.png")
const _TEX_GROWTH2 := preload("res://assets/base/plot_tile/growth2.png")
const _TEX_GROWTH3 := preload("res://assets/base/plot_tile/growth3.png")
const _STAT_CHIP_SCENE := preload("res://assets/ui/stat_chip/stat_chip.tscn")
const _FERTILIZER_ICON := preload("res://assets/base/nursery/fertilizers/fertiliser.png")

var plot_index: int = 0
var is_unlockable: bool = false
var unlock_cost: int = 0
var _plot: NurseryPlotData
var _can_plant: bool = false
var _base_modulate: Color = Color.WHITE
var _fertilizer_chips: Array[StatChip] = []
var _fertilizer_icon_atlas: AtlasTexture

@onready var _plot_visual: TextureRect = %PlotVisual
@onready var _days_chip: StatChip = %DaysChip
@onready var _stats_row: HBoxContainer = %StatsRow
@onready var _lock_spacer: Control = %LockSpacer
@onready var _unlock_button: Button = %UnlockButton
@onready var _unlock_cost_label: Label = %UnlockCostLabel
@onready var _lock_icon: TextureRect = %LockIcon


func _ready() -> void:
	_fertilizer_icon_atlas = AtlasTexture.new()
	_fertilizer_icon_atlas.atlas = _FERTILIZER_ICON
	_fertilizer_icon_atlas.region = Rect2(183, 167, 169, 180)
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = TILE_SIZE
	_base_modulate = modulate
	_set_children_mouse_filter_ignore(self)
	_unlock_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_unlock_button.pressed.connect(_on_unlock_pressed)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(clear_drop_highlight)
	if is_unlockable or _plot != null:
		_refresh()


func setup(index: int, plot: NurseryPlotData, can_plant: bool = false) -> void:
	plot_index = index
	_plot = plot
	_can_plant = can_plant
	is_unlockable = false
	unlock_cost = 0
	if is_node_ready():
		_refresh()
	else:
		ready.connect(_refresh, CONNECT_ONE_SHOT)


func setup_unlockable(index: int, cost: int) -> void:
	plot_index = index
	_plot = null
	_can_plant = false
	is_unlockable = true
	unlock_cost = cost
	if is_node_ready():
		_refresh()
	else:
		ready.connect(_refresh, CONNECT_ONE_SHOT)


func clear_drop_highlight() -> void:
	modulate = _base_modulate


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)


func _refresh() -> void:
	if is_unlockable:
		_days_chip.visible = false
		_clear_fertilizer_chips()
		_plot_visual.visible = false
		_lock_spacer.visible = true
		_lock_icon.visible = true
		_unlock_button.visible = true
		_unlock_cost_label.text = "%d" % unlock_cost
		var can_unlock := GameState.biomass.can_afford(unlock_cost)
		_unlock_button.disabled = not can_unlock
		_unlock_button.mouse_filter = Control.MOUSE_FILTER_STOP
		modulate = _LOCKED_MODULATE
		_base_modulate = modulate
		# Compensate for dimmed card; fade further when unaffordable.
		var button_mod := Color.WHITE / _LOCKED_MODULATE
		_unlock_button.modulate = button_mod if can_unlock else button_mod * Color(1, 1, 1, 0.45)
		_lock_icon.modulate = Color.WHITE / _LOCKED_MODULATE
		tooltip_text = ""
		return

	_lock_icon.visible = false
	_lock_spacer.visible = false
	_unlock_button.visible = false
	_unlock_button.modulate = Color.WHITE
	_lock_icon.modulate = Color.WHITE
	_plot_visual.visible = true
	if _plot == null:
		_days_chip.visible = false
		_clear_fertilizer_chips()
		tooltip_text = ""
		_apply_visual_state()
		return

	match _plot.get_state():
		NurseryPlotData.State.EMPTY:
			_days_chip.visible = false
			modulate = Color.WHITE
			_base_modulate = modulate
		NurseryPlotData.State.GROWING:
			var left := 0
			if _plot.planted_spore != null:
				left = _plot.planted_spore.days_to_mature - _plot.days_grown
			left = maxi(0, left)
			_days_chip.visible = left > 0
			if left > 0:
				_days_chip.set_value(left)
			modulate = Color.WHITE
			_base_modulate = modulate
		NurseryPlotData.State.READY:
			_days_chip.visible = true
			_days_chip.set_value(0)
			modulate = Color.WHITE
			_base_modulate = modulate
	_refresh_fertilizer_chips()
	tooltip_text = _plot.fertilizer_tooltip()
	_apply_visual_state()


func _clear_fertilizer_chips() -> void:
	for chip in _fertilizer_chips:
		if is_instance_valid(chip):
			if chip.get_parent() != null:
				chip.get_parent().remove_child(chip)
			chip.free()
	_fertilizer_chips.clear()


func _refresh_fertilizer_chips() -> void:
	_clear_fertilizer_chips()
	if _plot == null or _stats_row == null:
		return
	if _plot.applied_fertilizers.is_empty():
		return
	var counts: Dictionary = {}
	var order: Array[FertilizerData] = []
	for fert in _plot.applied_fertilizers:
		if fert == null:
			continue
		var key := fert.display_name
		if not counts.has(key):
			counts[key] = 0
			order.append(fert)
		counts[key] = int(counts[key]) + 1
	for fert in order:
		var count := int(counts.get(fert.display_name, 0))
		if count <= 0:
			continue
		var chip: StatChip = _STAT_CHIP_SCENE.instantiate()
		chip.icon = _fertilizer_icon_atlas
		_stats_row.add_child(chip)
		chip.set_value(count)
		var icon := chip.get_node_or_null("%Icon") as TextureRect
		if icon != null:
			icon.self_modulate = fert.tint
		_fertilizer_chips.append(chip)


func _apply_visual_state() -> void:
	if _plot_visual == null:
		return
	_plot_visual.texture = _texture_for_plot()
	_plot_visual.modulate = _growth_tint()


func _growth_tint() -> Color:
	if _plot == null or _plot.get_state() == NurseryPlotData.State.EMPTY:
		return Color.WHITE
	if _plot.planted_spore == null:
		return Color.WHITE
	return _plot.planted_spore.tint


func _texture_for_plot() -> Texture2D:
	if _plot == null or _plot.get_state() == NurseryPlotData.State.EMPTY:
		return _TEX_EMPTY
	if _plot.get_state() == NurseryPlotData.State.READY:
		if _plot.will_harvest_as_imago():
			return _TEX_GROWTH3
		return _TEX_GROWTH2
	var needed := 1
	if _plot.planted_spore != null:
		needed = maxi(1, _plot.planted_spore.days_to_mature)
	var progress := float(_plot.days_grown) / float(needed)
	if progress < 0.5:
		return _TEX_GROWTH0
	return _TEX_GROWTH1


func _on_unlock_pressed() -> void:
	if not is_unlockable:
		return
	plot_pressed.emit(self)


func _gui_input(event: InputEvent) -> void:
	if is_unlockable:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			plot_pressed.emit(self)
			accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if is_unlockable:
		clear_drop_highlight()
		return false
	if typeof(data) != TYPE_DICTIONARY:
		clear_drop_highlight()
		return false
	if _plot == null:
		clear_drop_highlight()
		return false
	var drop_type := str(data.get("type", ""))
	var state := _plot.get_state()
	if drop_type == "shop_spore" or drop_type == "spore":
		if state != NurseryPlotData.State.EMPTY:
			clear_drop_highlight()
			return false
		if drop_type == "spore" and not _can_plant:
			clear_drop_highlight()
			return false
		modulate = _DROP_HIGHLIGHT
		return true
	if drop_type == "shop_fertilizer" or drop_type == "fertilizer":
		if state == NurseryPlotData.State.READY:
			clear_drop_highlight()
			return false
		if state != NurseryPlotData.State.EMPTY and state != NurseryPlotData.State.GROWING:
			clear_drop_highlight()
			return false
		modulate = _DROP_HIGHLIGHT
		return true
	clear_drop_highlight()
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	clear_drop_highlight()
	if is_unlockable:
		return
	if typeof(data) != TYPE_DICTIONARY:
		return
	var drop_type := str(data.get("type", ""))
	if (
		drop_type != "spore"
		and drop_type != "shop_spore"
		and drop_type != "fertilizer"
		and drop_type != "shop_fertilizer"
	):
		return
	spore_dropped.emit(self, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		clear_drop_highlight()
