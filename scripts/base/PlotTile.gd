class_name PlotTile
extends PanelContainer

signal plot_pressed(tile: PlotTile)
signal spore_dropped(tile: PlotTile, stock_index: int)

const TILE_SIZE := Vector2(160, 180)

var plot_index: int = 0
var _plot: NurseryPlotData
var _can_plant: bool = false
var _base_modulate: Color = Color.WHITE

@onready var _visual_host: CenterContainer = %VisualHost
@onready var _placeholder: ColorRect = %PlaceholderVisual
@onready var _state_label: Label = %StateLabel
@onready var _hint_label: Label = %HintLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = TILE_SIZE
	_base_modulate = modulate
	_set_children_mouse_filter_ignore(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(clear_drop_highlight)
	if _plot != null:
		_refresh()


func setup(index: int, plot: NurseryPlotData, can_plant: bool = false) -> void:
	plot_index = index
	_plot = plot
	_can_plant = can_plant
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
	if _plot == null:
		_state_label.text = "—"
		_hint_label.text = ""
		_apply_visual_state()
		return

	match _plot.get_state():
		NurseryPlotData.State.EMPTY:
			_state_label.text = "Empty"
			_hint_label.text = "Plant / Drop spore" if _can_plant else "No spores"
			modulate = Color(1, 1, 1, 1.0) if _can_plant else Color(1, 1, 1, 0.65)
			_base_modulate = modulate
		NurseryPlotData.State.GROWING:
			var spore_name := _plot.planted_spore.display_name if _plot.planted_spore else "Spore"
			var needed := _plot.planted_spore.days_to_mature if _plot.planted_spore else 0
			_state_label.text = "%s\nDay %d/%d" % [spore_name, _plot.days_grown, needed]
			_hint_label.text = "Growing"
			modulate = Color.WHITE
			_base_modulate = modulate
		NurseryPlotData.State.READY:
			var ready_name := _plot.planted_spore.display_name if _plot.planted_spore else "Spore"
			_state_label.text = ready_name
			_hint_label.text = "Ready to harvest"
			modulate = Color.WHITE
			_base_modulate = modulate
	_apply_visual_state()


func _apply_visual_state() -> void:
	## Hook for future plot art. Placeholder color encodes state for now.
	if _placeholder == null:
		return
	if _plot == null:
		_placeholder.color = Color(0.2, 0.22, 0.2, 1.0)
		return
	match _plot.get_state():
		NurseryPlotData.State.EMPTY:
			_placeholder.color = Color(0.22, 0.24, 0.2, 1.0)
		NurseryPlotData.State.GROWING:
			_placeholder.color = Color(0.28, 0.42, 0.28, 1.0)
		NurseryPlotData.State.READY:
			_placeholder.color = Color(0.45, 0.7, 0.35, 1.0)
	# Keep VisualHost available for later TextureRect / sprout scenes.
	if _visual_host != null:
		_visual_host.visible = true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			plot_pressed.emit(self)
			accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		clear_drop_highlight()
		return false
	if str(data.get("type", "")) != "spore":
		clear_drop_highlight()
		return false
	if _plot == null or _plot.get_state() != NurseryPlotData.State.EMPTY:
		clear_drop_highlight()
		return false
	if not _can_plant:
		clear_drop_highlight()
		return false
	modulate = Color(0.7, 1.0, 0.75, 1.0)
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	clear_drop_highlight()
	if typeof(data) != TYPE_DICTIONARY:
		return
	if str(data.get("type", "")) != "spore":
		return
	spore_dropped.emit(self, int(data.get("stock_index", 0)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		clear_drop_highlight()
