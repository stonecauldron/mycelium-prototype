class_name PlotTile
extends PanelContainer

signal plot_pressed(tile: PlotTile)
signal spore_dropped(tile: PlotTile, data: Dictionary)

const TILE_SIZE := Vector2(160, 180)
const _LOCKED_MODULATE := Color(0.55, 0.55, 0.55, 1.0)

const _TEX_EMPTY := preload("res://assets/base/plot_tile/plot_empty.png")
const _TEX_GROWTH0 := preload("res://assets/base/plot_tile/growth0.png")
const _TEX_GROWTH1 := preload("res://assets/base/plot_tile/growth1.png")
const _TEX_GROWTH2 := preload("res://assets/base/plot_tile/growth2.png")

var plot_index: int = 0
var is_unlockable: bool = false
var unlock_cost: int = 0
var _plot: NurseryPlotData
var _can_plant: bool = false
var _base_modulate: Color = Color.WHITE

@onready var _plot_visual: TextureRect = %PlotVisual
@onready var _hint_label: Label = %HintLabel
@onready var _lock_spacer: Control = %LockSpacer
@onready var _unlock_button: Button = %UnlockButton
@onready var _unlock_cost_label: Label = %UnlockCostLabel
@onready var _lock_icon: TextureRect = %LockIcon


func _ready() -> void:
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
		_hint_label.visible = false
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
		return

	_lock_icon.visible = false
	_lock_spacer.visible = false
	_unlock_button.visible = false
	_unlock_button.modulate = Color.WHITE
	_lock_icon.modulate = Color.WHITE
	_plot_visual.visible = true
	_hint_label.visible = true
	if _plot == null:
		_hint_label.text = ""
		_apply_visual_state()
		return

	match _plot.get_state():
		NurseryPlotData.State.EMPTY:
			_hint_label.text = "Plant / Drop spore"
			modulate = Color.WHITE
			_base_modulate = modulate
		NurseryPlotData.State.GROWING:
			_hint_label.text = "Growing"
			modulate = Color.WHITE
			_base_modulate = modulate
		NurseryPlotData.State.READY:
			_hint_label.text = "Ready to harvest"
			modulate = Color.WHITE
			_base_modulate = modulate
	_apply_visual_state()


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
	if _plot == null or _plot.get_state() != NurseryPlotData.State.EMPTY:
		clear_drop_highlight()
		return false
	var drop_type := str(data.get("type", ""))
	if drop_type == "shop_spore":
		modulate = Color(0.7, 1.0, 0.75, 1.0)
		return true
	if drop_type == "spore":
		if not _can_plant:
			clear_drop_highlight()
			return false
		modulate = Color(0.7, 1.0, 0.75, 1.0)
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
	if drop_type != "spore" and drop_type != "shop_spore":
		return
	spore_dropped.emit(self, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		clear_drop_highlight()
