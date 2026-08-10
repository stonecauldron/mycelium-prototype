class_name PlotTile
extends PanelContainer

signal plot_pressed(tile: PlotTile)
signal plant_pressed(tile: PlotTile)
signal spore_dropped(tile: PlotTile, data: Dictionary)

const TILE_SIZE := Vector2(220, 336)
const _LOCKED_MODULATE := Color(0.55, 0.55, 0.55, 1.0)
const _DROP_HIGHLIGHT := Color(0.7, 1.0, 0.75, 1.0)

const _TEX_EMPTY := preload("res://assets/base/plot_tile/plot_empty.png")
const _TEX_GROWTH0 := preload("res://assets/base/plot_tile/growth0.png")
const _TEX_GROWTH1 := preload("res://assets/base/plot_tile/growth1.png")
const _TEX_EGG0 := preload("res://assets/base/plot_tile/egg0.png")
const _TEX_EGG1 := preload("res://assets/base/plot_tile/egg1.png")
const _TEX_EGG0_SHADOW := preload("res://assets/base/plot_tile/egg0_shadow.png")
const _TEX_EGG1_SHADOW := preload("res://assets/base/plot_tile/egg1_shadow.png")
const _STAT_CHIP_SCENE := preload("res://assets/ui/stat_chip/stat_chip.tscn")
const _FERTILIZER_ICON := preload("res://assets/base/nursery/fertilizers/fertiliser.png")
const _MUTATION_ICON := preload("res://assets/base/nursery/mutations/mutation_icon.png")
const _SPORE_DETAIL_CARD_SCENE := preload("res://assets/base/spore_detail_card/spore_detail_card.tscn")
const _HOURGLASS_ICON := preload("res://assets/base/nursery/spore_card/hourglass_icon.png")
const _HARVEST_ICON := preload("res://assets/combat/boom_cap_explosion/harvest_icon.png")
const _HARVEST_CHIP_SIZE := Vector2(64, 64)
const _EMPTY_CHIP_MODULATE := Color(1, 1, 1, 0.4)

const _SHAKE_IDLE_NORMAL_SEC := 1.5
const _SHAKE_IDLE_IMAGO_SEC := 0.8
const _SHAKE_STEP_NORMAL_SEC := 0.06
const _SHAKE_STEP_IMAGO_SEC := 0.045
const _SHAKE_ROT_NORMAL_DEG := 14.0
const _SHAKE_ROT_IMAGO_DEG := 26.0
const _SHAKE_NUDGE_NORMAL_PX := 4.0
const _SHAKE_NUDGE_IMAGO_PX := 8.0

var plot_index: int = 0
var is_unlockable: bool = false
var unlock_cost: int = 0
var _plot: NurseryPlotData
## True when the player can afford pay-on-plot fresh planting (hint arrow).
var _can_afford_fresh_plant: bool = false
var _base_modulate: Color = Color.WHITE
var _fertilizer_chips: Array[StatChip] = []
var _fertilizer_icon_atlas: AtlasTexture
## Living SporeDetailCard from `_make_custom_tooltip` (engine keeps it open across drops).
var _active_detail_tip: SporeDetailCard = null
var _egg_shake_tween: Tween
var _egg_shake_imago: bool = false
var _egg_shake_x: float = 0.0:
	set(value):
		_egg_shake_x = value
		_apply_egg_shake_transform()
var _egg_shake_rot: float = 0.0:
	set(value):
		_egg_shake_rot = value
		_apply_egg_shake_transform()

@onready var _plot_visual_area: Control = %PlotVisualArea
@onready var _plot_visual: TextureRect = %PlotVisual
@onready var _egg_shadow: TextureRect = %EggShadow
@onready var _egg_visual: TextureRect = %EggVisual
@onready var _days_chip: StatChip = %DaysChip
@onready var _stats_row: HBoxContainer = %StatsRow
@onready var _lock_spacer: Control = %LockSpacer
@onready var _action_slot: Control = %ActionSlot
@onready var _plant_button: Button = %PlantButton
@onready var _plant_cost_label: Label = %PlantCostLabel
@onready var _unlock_button: Button = %UnlockButton
@onready var _unlock_cost_label: Label = %UnlockCostLabel
@onready var _lock_icon: TextureRect = %LockIcon
@onready var _drop_arrow: FloatingArrow = %DropArrow


func _ready() -> void:
	_fertilizer_icon_atlas = AtlasTexture.new()
	_fertilizer_icon_atlas.atlas = _FERTILIZER_ICON
	_fertilizer_icon_atlas.region = Rect2(183, 167, 169, 180)
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = TILE_SIZE
	_base_modulate = modulate
	_set_children_mouse_filter_ignore(self)
	_plant_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_plant_button.pressed.connect(_on_plant_pressed)
	_unlock_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_unlock_button.pressed.connect(_on_unlock_pressed)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(clear_drop_highlight)
	if _egg_visual != null:
		_egg_visual.resized.connect(_update_egg_pivot)
	if is_unlockable or _plot != null:
		_refresh()


func setup(index: int, plot: NurseryPlotData, can_afford_fresh_plant: bool = false) -> void:
	plot_index = index
	_plot = plot
	_can_afford_fresh_plant = can_afford_fresh_plant
	is_unlockable = false
	unlock_cost = 0
	if is_node_ready():
		_refresh()
	else:
		ready.connect(_refresh, CONNECT_ONE_SHOT)


func setup_unlockable(index: int, cost: int) -> void:
	plot_index = index
	_plot = null
	_can_afford_fresh_plant = false
	is_unlockable = true
	unlock_cost = cost
	if is_node_ready():
		_refresh()
	else:
		ready.connect(_refresh, CONNECT_ONE_SHOT)


func clear_drop_highlight() -> void:
	modulate = _base_modulate


func _set_drop_arrow_visible(should_show: bool) -> void:
	if _drop_arrow == null:
		return
	if should_show:
		_drop_arrow.show_arrow()
	else:
		_drop_arrow.hide_arrow()


func _accepts_drag_data(data: Variant) -> bool:
	if is_unlockable:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if _plot == null:
		return false
	var drop_type := str(data.get("type", ""))
	var state := _plot.get_state()
	if drop_type == "spore":
		return state == NurseryPlotData.State.EMPTY
	if drop_type == "shop_fertilizer" or drop_type == "fertilizer":
		var fert := data.get("fertilizer") as FertilizerData
		if fert != null and fert.behavior == FertilizerData.Behavior.FUNGICIDE:
			return state == NurseryPlotData.State.GROWING or state == NurseryPlotData.State.READY
		if not _plot.can_apply_fertilizer():
			return false
		return state == NurseryPlotData.State.EMPTY or state == NurseryPlotData.State.GROWING
	if drop_type == "shop_mutation" or drop_type == "mutation":
		var mutation := data.get("mutation") as MutationData
		return _plot.can_apply_mutation(mutation)
	return false


func _should_show_harvest_hint() -> bool:
	if not GameState.show_plot_harvest_hint:
		return false
	if is_unlockable or _plot == null:
		return false
	return _plot.get_state() == NurseryPlotData.State.READY


func _should_show_plant_hint() -> bool:
	if not GameState.show_plot_plant_hint:
		return false
	if is_unlockable or _plot == null or not _can_afford_fresh_plant:
		return false
	return _plot.get_state() == NurseryPlotData.State.EMPTY


func _refresh_arrow() -> void:
	var viewport := get_viewport()
	if viewport != null and viewport.gui_is_dragging():
		_set_drop_arrow_visible(_accepts_drag_data(viewport.gui_get_drag_data()))
		return
	_set_drop_arrow_visible(_should_show_harvest_hint() or _should_show_plant_hint())


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)


func _refresh() -> void:
	if is_unlockable:
		# Same stack as empty plots (plot + stats + action) so Unlock lines up with Plant.
		_days_chip.visible = false
		_clear_fertilizer_chips()
		_lock_spacer.visible = false
		_plot_visual_area.visible = true
		_hide_egg_layers()
		_plot_visual.texture = _TEX_EMPTY
		_plot_visual.modulate = Color.WHITE
		_lock_icon.visible = true
		_action_slot.visible = true
		_plant_button.visible = false
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
		_refresh_arrow()
		_sync_active_detail_tip()
		return

	_lock_icon.visible = false
	_lock_spacer.visible = false
	_unlock_button.visible = false
	_unlock_button.modulate = Color.WHITE
	_lock_icon.modulate = Color.WHITE
	_action_slot.visible = true
	_plot_visual_area.visible = true
	if _plot == null:
		_days_chip.visible = false
		_clear_fertilizer_chips()
		_plant_button.visible = false
		tooltip_text = ""
		_apply_visual_state()
		_refresh_arrow()
		_sync_active_detail_tip()
		return

	match _plot.get_state():
		NurseryPlotData.State.EMPTY:
			_days_chip.visible = false
			modulate = Color.WHITE
			_base_modulate = modulate
			_refresh_plant_button(true)
		NurseryPlotData.State.GROWING:
			_refresh_plant_button(false)
			var left := 0
			if _plot.planted_spore != null:
				left = _plot.days_to_mature_effective() - _plot.days_grown
			left = maxi(0, left)
			_days_chip.visible = left > 0
			if left > 0:
				_days_chip.chip_size = StatChip.CHIP_SIZE
				_days_chip.icon = _HOURGLASS_ICON
				_days_chip.set_value(left)
			modulate = Color.WHITE
			_base_modulate = modulate
		NurseryPlotData.State.READY:
			_refresh_plant_button(false)
			_days_chip.visible = true
			_days_chip.chip_size = _HARVEST_CHIP_SIZE
			_days_chip.icon = _HARVEST_ICON
			_days_chip.set_value()
			modulate = Color.WHITE
			_base_modulate = modulate
	_refresh_fertilizer_chips()
	if _plot.planted_spore != null:
		# Non-empty text enables the tooltip popup; content comes from _make_custom_tooltip.
		tooltip_text = _plot.planted_spore.display_name
	else:
		tooltip_text = ""
	_apply_visual_state()
	_refresh_arrow()
	_sync_active_detail_tip()


func _refresh_plant_button(should_show: bool) -> void:
	if _plant_button == null:
		return
	if not should_show:
		_plant_button.visible = false
		_plant_button.modulate = Color.WHITE
		return
	var cost := SealModifiers.fresh_plant_cost()
	_plant_cost_label.text = "%d" % cost
	var can_plant := GameState.biomass.can_afford(cost)
	_plant_button.visible = true
	_plant_button.disabled = not can_plant
	_plant_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_plant_button.modulate = Color.WHITE if can_plant else Color(1, 1, 1, 0.45)


func _make_custom_tooltip(_for_text: String) -> Object:
	if _plot == null or _plot.planted_spore == null:
		return null
	var tip: SporeDetailCard = _SPORE_DETAIL_CARD_SCENE.instantiate()
	tip.setup(_plot.planted_spore, false, _plot)
	DetailTooltipPopup.configure(tip)
	_active_detail_tip = tip
	tip.tree_exiting.connect(_on_active_detail_tip_exiting.bind(tip), CONNECT_ONE_SHOT)
	return tip


func _on_active_detail_tip_exiting(tip: SporeDetailCard) -> void:
	if _active_detail_tip == tip:
		_active_detail_tip = null


## Fertilizer/mutation drops refresh the tile while the hover tip is still open.
func _sync_active_detail_tip() -> void:
	if _active_detail_tip == null or not is_instance_valid(_active_detail_tip):
		_active_detail_tip = null
		return
	if _plot == null or _plot.planted_spore == null:
		return
	_active_detail_tip.setup(_plot.planted_spore, false, _plot)
	DetailTooltipPopup.configure(_active_detail_tip)


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
	# Ghost capacity chips only while a spore is planted; empty dirt shows filled only.
	var show_ghosts := not _plot.is_empty()
	_add_mutation_slot_chip(show_ghosts)
	_add_fertilizer_slot_chips(show_ghosts)


func _add_mutation_slot_chip(show_ghost: bool) -> void:
	var mutation := _plot.filled_mutation()
	if mutation == null and not show_ghost:
		return
	var chip: StatChip = _STAT_CHIP_SCENE.instantiate()
	chip.icon = _MUTATION_ICON
	_stats_row.add_child(chip)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	var icon := chip.get_node_or_null("%Icon") as TextureRect
	if mutation == null:
		chip.set_value()
		if icon != null:
			icon.self_modulate = _EMPTY_CHIP_MODULATE
		chip.tooltip_text = "Mutation"
	else:
		chip.set_value(mutation.slot_label().substr(0, 1))
		if icon != null:
			icon.self_modulate = mutation.tint
		chip.tooltip_text = "%s: %s\n%s" % [
			mutation.slot_label(),
			mutation.display_name,
			mutation.subtitle_text(),
		]
	_fertilizer_chips.append(chip)


func _add_fertilizer_slot_chips(show_ghosts: bool) -> void:
	var max_stacks := SealModifiers.max_fertilizer_stacks()
	var applied := _plot.applied_fertilizers
	var slot_count := max_stacks if show_ghosts else mini(applied.size(), max_stacks)
	for i in slot_count:
		var fert: FertilizerData = applied[i] if i < applied.size() else null
		if fert == null and not show_ghosts:
			continue
		var chip: StatChip = _STAT_CHIP_SCENE.instantiate()
		chip.icon = _fertilizer_icon_atlas
		_stats_row.add_child(chip)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		var icon := chip.get_node_or_null("%Icon") as TextureRect
		if fert == null:
			chip.set_value()
			if icon != null:
				icon.self_modulate = _EMPTY_CHIP_MODULATE
			chip.tooltip_text = "Fertilizer"
		else:
			chip.set_value()
			if icon != null:
				icon.self_modulate = fert.tint
			chip.tooltip_text = _fertilizer_chip_tooltip(fert, 1)
		_fertilizer_chips.append(chip)


func _fertilizer_chip_tooltip(fert: FertilizerData, count: int) -> String:
	if fert == null:
		return ""
	if fert.behavior == FertilizerData.Behavior.FUNGICIDE and _plot != null:
		var residue := _plot.fungicide_residue_text()
		if not residue.is_empty():
			return residue
	var title := fert.display_name
	if count > 1:
		title = "%s ×%d" % [title, count]
	var effect := fert.subtitle_text()
	if effect.is_empty():
		return title
	return "%s\n%s" % [title, effect]


func _apply_visual_state() -> void:
	if _plot_visual == null:
		return
	_plot_visual.texture = _texture_for_plot()
	var is_ready := _plot != null and _plot.get_state() == NurseryPlotData.State.READY
	if is_ready:
		_plot_visual.modulate = Color.WHITE
		_show_egg_layers(true)
	else:
		_plot_visual.modulate = _growth_tint()
		_hide_egg_layers()


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
		return _TEX_EMPTY
	var needed := 1
	if _plot.planted_spore != null:
		needed = maxi(1, _plot.days_to_mature_effective())
	var progress := float(_plot.days_grown) / float(needed)
	if progress < 0.5:
		return _TEX_GROWTH0
	return _TEX_GROWTH1


func _show_egg_layers(as_imago: bool) -> void:
	if _egg_shadow == null or _egg_visual == null:
		return
	_egg_shadow.visible = true
	_egg_visual.visible = true
	_egg_shadow.texture = _TEX_EGG1_SHADOW if as_imago else _TEX_EGG0_SHADOW
	_egg_visual.texture = _TEX_EGG1 if as_imago else _TEX_EGG0
	_egg_visual.modulate = _growth_tint()
	_update_egg_pivot()
	_start_egg_shake(as_imago)


func _hide_egg_layers() -> void:
	_stop_egg_shake()
	if _egg_shadow != null:
		_egg_shadow.visible = false
	if _egg_visual != null:
		_egg_visual.visible = false
		_egg_visual.modulate = Color.WHITE


func _start_egg_shake(as_imago: bool) -> void:
	if _egg_visual == null:
		return
	if _egg_shake_tween != null and _egg_shake_tween.is_valid() and _egg_shake_imago == as_imago:
		return
	_stop_egg_shake()
	_egg_shake_imago = as_imago
	_update_egg_pivot()

	var rot := _SHAKE_ROT_IMAGO_DEG if as_imago else _SHAKE_ROT_NORMAL_DEG
	var nudge := _SHAKE_NUDGE_IMAGO_PX if as_imago else _SHAKE_NUDGE_NORMAL_PX
	var step := _SHAKE_STEP_IMAGO_SEC if as_imago else _SHAKE_STEP_NORMAL_SEC
	var idle := _SHAKE_IDLE_IMAGO_SEC if as_imago else _SHAKE_IDLE_NORMAL_SEC

	var tween := create_tween()
	_egg_shake_tween = tween
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(idle)
	tween.tween_property(self, "_egg_shake_rot", -rot, step)
	tween.parallel().tween_property(self, "_egg_shake_x", -nudge, step)
	tween.tween_property(self, "_egg_shake_rot", rot, step)
	tween.parallel().tween_property(self, "_egg_shake_x", nudge, step)
	tween.tween_property(self, "_egg_shake_rot", -rot * 0.6, step)
	tween.parallel().tween_property(self, "_egg_shake_x", -nudge * 0.6, step)
	tween.tween_property(self, "_egg_shake_rot", 0.0, step)
	tween.parallel().tween_property(self, "_egg_shake_x", 0.0, step)


func _stop_egg_shake() -> void:
	if _egg_shake_tween != null:
		_egg_shake_tween.kill()
		_egg_shake_tween = null
	_egg_shake_x = 0.0
	_egg_shake_rot = 0.0
	_apply_egg_shake_transform()


func _apply_egg_shake_transform() -> void:
	if _egg_visual == null:
		return
	_egg_visual.rotation_degrees = _egg_shake_rot
	_egg_visual.offset_left = _egg_shake_x
	_egg_visual.offset_right = _egg_shake_x


func _update_egg_pivot() -> void:
	if _egg_visual == null:
		return
	_egg_visual.pivot_offset = _egg_visual.size * 0.5


func _on_plant_pressed() -> void:
	if is_unlockable or _plot == null:
		return
	if _plot.get_state() != NurseryPlotData.State.EMPTY:
		return
	plant_pressed.emit(self)


func _on_unlock_pressed() -> void:
	if not is_unlockable:
		return
	plot_pressed.emit(self)


func _gui_input(event: InputEvent) -> void:
	if is_unlockable:
		return
	# Empty plots plant only via PlantButton.
	if _plot == null or _plot.get_state() == NurseryPlotData.State.EMPTY:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			plot_pressed.emit(self)
			accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not _accepts_drag_data(data):
		clear_drop_highlight()
		return false
	modulate = _DROP_HIGHLIGHT
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	clear_drop_highlight()
	_refresh_arrow()
	if not _accepts_drag_data(data):
		return
	spore_dropped.emit(self, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_refresh_arrow()
	elif what == NOTIFICATION_DRAG_END:
		clear_drop_highlight()
		_refresh_arrow()
