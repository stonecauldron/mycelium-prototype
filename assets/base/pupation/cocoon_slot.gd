class_name CocoonSlot
extends PanelContainer

signal unit_dropped_on_cocoon(slot: CocoonSlot, drag_data: Dictionary)

const _COCOON_CLOSED := preload("res://assets/base/pupation/cocoon.png")
const _COCOON_OPEN := preload("res://assets/base/pupation/cocoon_open.png")
const _HOURGLASS_ICON := preload("res://assets/base/nursery/spore_card/hourglass_icon.png")
const _UNIT_DETAIL_CARD_SCENE := preload("res://assets/base/unit_detail_card/unit_detail_card.tscn")
const _WEAPON_DETAIL_CARD_SCENE := preload("res://assets/base/weapon_detail_card/weapon_detail_card.tscn")
const _SCHOOL_TRAINING_DETAIL_CARD_SCENE := preload(
	"res://assets/base/pupation/school_training_detail_card.tscn"
)
const _TRAINING_PREVIEW_TOOLTIP := preload("res://assets/base/pupation/training_preview_tooltip.gd")
const _DETAIL_TOOLTIP_SEPARATION := 12.0
const _SLOT_SIZE := Vector2(132, 260)
const _HOVER_SCALE := 1.18
const _TWEEN_SECONDS := 0.14

@export var school: int = 0

var _base_modulate: Color = Color.WHITE
var _drag_hover_active: bool = false
var _scale_tween: Tween
var _drag_preview_unit: RosterUnitData
var _drag_preview_tip: TrainingPreviewTooltip
var _drag_preview_lease: Control
var _emergence_active: bool = false

@onready var _weapon_icon: TextureRect = %WeaponIcon
@onready var _cocoon_image: TextureRect = %CocoonImage
@onready var _days_chip: StatChip = %DaysChip
@onready var _hover_punch: HoverPunch = %HoverPunch
@onready var _drop_arrow: FloatingArrow = %DropArrow


func _set_drop_arrow_visible(should_show: bool) -> void:
	if _drop_arrow == null:
		return
	if should_show:
		_drop_arrow.show_arrow()
	else:
		_drop_arrow.hide_arrow()


func _accepts_drag_data(data: Variant) -> bool:
	var unit := _dragged_troop_unit(data)
	if unit == null:
		return false
	return GameState.can_cocoon_for_pupation(unit, school)


func _training_drag_decision(data: Variant) -> ActionDecision:
	var unit := _dragged_troop_unit(data)
	if unit == null:
		return null
	return unit.check_training_eligibility(school)


func _dragged_troop_unit(data: Variant) -> RosterUnitData:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var unit := data.get("unit") as RosterUnitData
	if unit == null:
		return null
	var source := str(data.get("source", ""))
	if source != "squad" and source != "bench":
		return null
	return unit


func _refresh_arrow() -> void:
	var viewport := get_viewport()
	if viewport != null and viewport.gui_is_dragging():
		_set_drop_arrow_visible(_accepts_drag_data(viewport.gui_get_drag_data()))
		return
	_set_drop_arrow_visible(false)


func _ready() -> void:
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	BiomassPreview.bind(self, _biomass_preview_delta)
	custom_minimum_size = _SLOT_SIZE
	_base_modulate = modulate
	mouse_exited.connect(_on_mouse_exited)
	_set_structure_mouse_ignore(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_weapon_icon()
	_refresh_visuals()
	_prepare_cocoon_pivot()


func _process(_delta: float) -> void:
	var viewport := get_viewport()
	var hovered := viewport.gui_get_hovered_control()
	if not viewport.gui_is_dragging() or not is_visible_in_tree():
		_clear_transformation_preview()
	elif hovered != self and (hovered == null or not is_ancestor_of(hovered)):
		_clear_transformation_preview()
	elif not _accepts_drag_data(viewport.gui_get_drag_data()):
		_clear_transformation_preview()


func _show_transformation_preview(unit: RosterUnitData) -> void:
	if _drag_preview_unit == unit and is_instance_valid(_drag_preview_tip):
		return
	_clear_transformation_preview()
	_drag_preview_unit = unit
	_drag_preview_tip = _TRAINING_PREVIEW_TOOLTIP.new()
	_drag_preview_tip.setup(unit, school)
	# Native hover tooltips are suspended during a drag, so own this lease explicitly.
	_drag_preview_lease = DetailTooltipPopup.configure(_drag_preview_tip)
	add_child(_drag_preview_lease)
	set_process(true)


func _clear_transformation_preview() -> void:
	_drag_preview_unit = null
	# A pause can stop the overlay's fade tween; remove the drag preview immediately.
	if is_instance_valid(_drag_preview_tip):
		_drag_preview_tip.hide()
	_drag_preview_tip = null
	if is_instance_valid(_drag_preview_lease):
		_drag_preview_lease.queue_free()
	_drag_preview_lease = null
	set_process(false)


func _biomass_preview_delta() -> Variant:
	var viewport := get_viewport()
	if not viewport.gui_is_dragging() or not _accepts_drag_data(viewport.gui_get_drag_data()):
		return null
	return -WeaponSchool.COCOON_COST


func _prepare_cocoon_pivot() -> void:
	if _cocoon_image == null:
		return
	# Scale from center when hover-tweening.
	_cocoon_image.resized.connect(_sync_cocoon_pivot)
	_sync_cocoon_pivot()


func _sync_cocoon_pivot() -> void:
	if _cocoon_image == null:
		return
	_cocoon_image.pivot_offset = _cocoon_image.size * 0.5


func _set_structure_mouse_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_structure_mouse_ignore(child)


func _refresh_weapon_icon() -> void:
	if _weapon_icon == null:
		return
	var weapon := WeaponSchool.load_weapon(WeaponSchool.base_weapon_path(school))
	_weapon_icon.texture = weapon.icon if weapon != null else null


func _refresh_visuals() -> void:
	_update_cocoon_art()
	_update_days_chip()
	_update_tooltip()


func _update_cocoon_art() -> void:
	if _cocoon_image == null:
		return
	_cocoon_image.modulate = Color.WHITE
	_cocoon_image.texture = _COCOON_CLOSED if get_occupant() != null else _COCOON_OPEN


func _update_days_chip() -> void:
	if _days_chip == null:
		return
	var left := 0
	if get_occupant() != null:
		left = GameState.pupation.get_days_remaining(school)
	_days_chip.visible = left > 0
	if left > 0:
		_days_chip.chip_size = StatChip.CHIP_SIZE
		_days_chip.icon = _HOURGLASS_ICON
		_days_chip.set_value(left)


func _update_tooltip() -> void:
	if _emergence_active or get_viewport().gui_is_dragging():
		tooltip_text = ""
		return
	var unit := get_occupant()
	# Non-empty text enables the tooltip popup; content comes from _make_custom_tooltip.
	if unit != null:
		tooltip_text = unit.display_name
	else:
		tooltip_text = WeaponSchool.display_name(school)


func get_occupant() -> RosterUnitData:
	return GameState.pupation.get_occupant(school)


func sync_from_state() -> void:
	_clear_transformation_preview()
	_refresh_visuals()
	_set_drag_hover(false)
	_refresh_arrow()
	if _hover_punch != null:
		_hover_punch.reset()
		if _emergence_active:
			_hover_punch.suppress_enter()
		else:
			_hover_punch.call_deferred("arm_enter_unless_hovered")


func begin_emergence() -> Dictionary:
	_clear_transformation_preview()
	_emergence_active = true
	_drag_hover_active = false
	modulate = _base_modulate
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_cocoon_image.scale = Vector2.ONE
	_cocoon_image.rotation = 0.0
	if _hover_punch != null:
		_hover_punch.reset()
		_hover_punch.suppress_enter()
	_set_drop_arrow_visible(false)
	tooltip_text = ""
	# Completion has already emptied the model slot; show the closed shell only
	# in the effect, keeping the live Control's layout space reserved.
	_cocoon_image.texture = _COCOON_CLOSED
	_cocoon_image.self_modulate = Color.WHITE
	var shell := UnitEmergence.capture_shell(_cocoon_image)
	_cocoon_image.self_modulate.a = 0.0
	return shell


func end_emergence() -> void:
	_emergence_active = false
	_cocoon_image.self_modulate = Color.WHITE
	_refresh_visuals()
	_refresh_arrow()
	if _hover_punch != null:
		_hover_punch.call_deferred("arm_enter_unless_hovered")


func _make_custom_tooltip(_for_text: String) -> Object:
	# A queued native tooltip must not replace the explicitly owned result preview.
	if _emergence_active or get_viewport().gui_is_dragging():
		return DetailTooltipPopup.configure(null)
	var unit := get_occupant()
	if unit == null:
		return _make_empty_training_tooltip()
	return _make_cocooned_unit_tooltip(unit)


func _make_empty_training_tooltip() -> Object:
	var tip: SchoolTrainingDetailCard = _SCHOOL_TRAINING_DETAIL_CARD_SCENE.instantiate()
	tip.setup(school)
	return DetailTooltipPopup.configure(tip)


func _make_cocooned_unit_tooltip(unit: RosterUnitData) -> Object:
	var preview := WeaponSchool.preview_emerged_unit(unit, school)
	if preview == null:
		return null
	var unit_tip: UnitDetailCard = _UNIT_DETAIL_CARD_SCENE.instantiate()
	# Portrait included — cocoon art does not show the emerged unit.
	# Non-interactive so hover stays stable while the tooltip is open.
	unit_tip.setup(preview, true, false)

	if preview.weapon == null:
		return DetailTooltipPopup.configure(unit_tip)

	var weapon_tip: WeaponDetailCard = _WEAPON_DETAIL_CARD_SCENE.instantiate()
	weapon_tip.setup(preview.weapon, false)

	var host := HBoxContainer.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_theme_constant_override("separation", int(_DETAIL_TOOLTIP_SEPARATION))
	host.add_child(unit_tip)
	host.add_child(weapon_tip)
	return DetailTooltipPopup.configure(host)


func _on_mouse_exited() -> void:
	_clear_transformation_preview()
	_set_drag_hover(false)
	ActionFeedback.clear_drag_preview()


func _set_drag_hover(active: bool) -> void:
	if _drag_hover_active == active:
		return
	_drag_hover_active = active
	if active:
		modulate = Color(0.75, 1.0, 0.8, 1.0)
		if _hover_punch != null:
			_hover_punch.reset()
			_hover_punch.suppress_enter()
	else:
		modulate = _base_modulate
		if _hover_punch != null:
			_hover_punch.call_deferred("arm_enter_unless_hovered")
	_tween_cocoon_scale(_HOVER_SCALE if active else 1.0)


func _tween_cocoon_scale(target: float) -> void:
	if _cocoon_image == null:
		return
	_sync_cocoon_pivot()
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(
		_cocoon_image,
		"scale",
		Vector2(target, target),
		_TWEEN_SECONDS
	)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var decision := _training_drag_decision(data)
	if decision != null and not decision.allowed:
		_clear_transformation_preview()
		ActionFeedback.preview_rejection(self, decision)
		_set_drag_hover(false)
		return false
	ActionFeedback.clear_drag_preview()
	if not _accepts_drag_data(data):
		_clear_transformation_preview()
		_set_drag_hover(false)
		return false
	_set_drag_hover(true)
	_show_transformation_preview(_dragged_troop_unit(data))
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_clear_transformation_preview()
	_set_drag_hover(false)
	_refresh_arrow()
	if not _accepts_drag_data(data):
		return
	unit_dropped_on_cocoon.emit(self, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_update_tooltip()
		_refresh_arrow()
	elif what == NOTIFICATION_DRAG_END:
		_clear_transformation_preview()
		_update_tooltip()
		_set_drag_hover(false)
		_refresh_arrow()
	elif what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		_clear_transformation_preview()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_clear_transformation_preview()
