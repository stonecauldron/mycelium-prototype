class_name ShopSellOverlay
extends Control

const _HOVER_SCALE := 1.14
const _SCALE_IN_SEC := 0.14
const _SCALE_OUT_SEC := 0.1

@onready var _amount_label: Label = %AmountLabel
@onready var _badge: PanelContainer = %Badge

var _scale_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_children_mouse_filter_ignore(self)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	visible = false


func show_amount(amount: int) -> void:
	if _amount_label != null:
		_amount_label.text = str(amount)
	visible = true
	call_deferred("_sync_hover_scale")


func hide_overlay() -> void:
	_reset_badge_scale()
	visible = false


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var zone := get_parent() as ShopDropZone
	if zone != null:
		return zone._can_drop_data(at_position, data)
	return false


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var zone := get_parent() as ShopDropZone
	if zone != null:
		zone._drop_data(at_position, data)


func _on_mouse_entered() -> void:
	if not visible:
		return
	_tween_badge_scale(_HOVER_SCALE)


func _on_mouse_exited() -> void:
	_tween_badge_scale(1.0)


func _sync_hover_scale() -> void:
	if not visible or not is_inside_tree():
		return
	if get_global_rect().has_point(get_global_mouse_position()):
		_tween_badge_scale(_HOVER_SCALE)
	else:
		_tween_badge_scale(1.0)


func _tween_badge_scale(target: float) -> void:
	if _badge == null:
		return
	_badge.pivot_offset = _badge.size * 0.5
	if _scale_tween != null:
		_scale_tween.kill()
	var duration := _SCALE_IN_SEC if target > 1.0 else _SCALE_OUT_SEC
	_scale_tween = create_tween()
	_scale_tween.tween_property(
		_badge,
		"scale",
		Vector2(target, target),
		duration
	).set_trans(Tween.TRANS_BACK if target > 1.0 else Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func _reset_badge_scale() -> void:
	if _scale_tween != null:
		_scale_tween.kill()
		_scale_tween = null
	if _badge != null:
		_badge.scale = Vector2.ONE
		_badge.rotation = 0.0


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
