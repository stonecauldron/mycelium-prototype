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
const _DETAIL_TOOLTIP_SEPARATION := 12.0
const _SLOT_SIZE := Vector2(160, 260)
const _HOVER_SCALE := 1.18
const _TWEEN_SECONDS := 0.14

@export var school: int = 0

var _base_modulate: Color = Color.WHITE
var _drag_hover_active: bool = false
var _scale_tween: Tween

@onready var _weapon_icon: TextureRect = %WeaponIcon
@onready var _cocoon_image: TextureRect = %CocoonImage
@onready var _days_chip: StatChip = %DaysChip
@onready var _hover_punch: HoverPunch = %HoverPunch


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = _SLOT_SIZE
	_base_modulate = modulate
	mouse_exited.connect(_on_mouse_exited)
	_set_structure_mouse_ignore(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_weapon_icon()
	_refresh_visuals()
	_prepare_cocoon_pivot()


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
	var unit := get_occupant()
	# Non-empty text enables the tooltip popup; content comes from _make_custom_tooltip.
	if unit != null:
		tooltip_text = unit.display_name
	else:
		tooltip_text = WeaponSchool.display_name(school)


func get_occupant() -> RosterUnitData:
	return GameState.pupation.get_occupant(school)


func sync_from_state() -> void:
	_refresh_visuals()
	_set_drag_hover(false)
	if _hover_punch != null:
		_hover_punch.reset()
		_hover_punch.call_deferred("arm_enter_unless_hovered")


func _make_custom_tooltip(_for_text: String) -> Object:
	var unit := get_occupant()
	if unit == null:
		return _make_empty_training_tooltip()
	return _make_cocooned_unit_tooltip(unit)


func _make_empty_training_tooltip() -> Object:
	var tip: SchoolTrainingDetailCard = _SCHOOL_TRAINING_DETAIL_CARD_SCENE.instantiate()
	tip.setup(school)
	var tip_size := tip.card_size()
	tip.custom_minimum_size = tip_size
	tip.size = tip_size
	tip.tree_entered.connect(
		_configure_detail_tooltip_popup.bind(tip, tip_size), CONNECT_ONE_SHOT
	)
	return tip


func _make_cocooned_unit_tooltip(unit: RosterUnitData) -> Object:
	var preview := WeaponSchool.preview_emerged_unit(unit, school)
	if preview == null:
		return null
	var unit_tip: UnitDetailCard = _UNIT_DETAIL_CARD_SCENE.instantiate()
	# Portrait included — cocoon art does not show the emerged unit.
	# Non-interactive so hover stays stable while the tooltip is open.
	unit_tip.setup(preview, true, false)
	var unit_size := unit_tip.card_size()
	unit_tip.custom_minimum_size = unit_size
	unit_tip.size = unit_size

	if preview.weapon == null:
		unit_tip.tree_entered.connect(
			_configure_detail_tooltip_popup.bind(unit_tip, unit_size), CONNECT_ONE_SHOT
		)
		return unit_tip

	var weapon_tip: WeaponDetailCard = _WEAPON_DETAIL_CARD_SCENE.instantiate()
	weapon_tip.setup(preview.weapon, false)
	var weapon_size := weapon_tip.card_size()
	weapon_tip.custom_minimum_size = weapon_size
	weapon_tip.size = weapon_size

	var host := HBoxContainer.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_theme_constant_override("separation", int(_DETAIL_TOOLTIP_SEPARATION))
	host.add_child(unit_tip)
	host.add_child(weapon_tip)
	var combined := Vector2(
		unit_size.x + weapon_size.x + _DETAIL_TOOLTIP_SEPARATION,
		maxf(unit_size.y, weapon_size.y)
	)
	host.custom_minimum_size = combined
	host.size = combined
	host.tree_entered.connect(
		_configure_detail_tooltip_popup.bind(host, combined), CONNECT_ONE_SHOT
	)
	return host


func _configure_detail_tooltip_popup(tip: Control, tip_size: Vector2) -> void:
	var node: Node = tip.get_parent()
	while node != null:
		if node is PopupPanel:
			var popup := node as PopupPanel
			popup.transparent = true
			popup.transparent_bg = true
			popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			popup.size = Vector2i(ceili(tip_size.x), ceili(tip_size.y))
			return
		node = node.get_parent()


func _on_mouse_exited() -> void:
	_set_drag_hover(false)


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
	if typeof(data) != TYPE_DICTIONARY:
		_set_drag_hover(false)
		return false
	var unit := data.get("unit") as RosterUnitData
	if unit == null:
		_set_drag_hover(false)
		return false
	var source := str(data.get("source", ""))
	if source != "squad" and source != "bench":
		_set_drag_hover(false)
		return false
	if not GameState.can_cocoon_for_pupation(unit, school):
		_set_drag_hover(false)
		return false
	_set_drag_hover(true)
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_drag_hover(false)
	if typeof(data) != TYPE_DICTIONARY:
		return
	unit_dropped_on_cocoon.emit(self, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_drag_hover(false)
