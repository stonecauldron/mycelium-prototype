class_name FloatingArrow
extends Control

const ARROW_SIZE := Vector2(96, 96)
const _BOB_AMPLITUDE_PX := 6.0
const _BOB_HALF_DURATION_SEC := 0.45

@onready var _icon: TextureRect = %Icon

var _bob_tween: Tween
var _bob_y: float = 0.0:
	set(value):
		_bob_y = value
		_apply_bob_y()


func _ready() -> void:
	custom_minimum_size = ARROW_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _icon != null:
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_start_bob()


func show_arrow() -> void:
	visible = true
	if _bob_tween == null:
		_start_bob()


func hide_arrow() -> void:
	visible = false


func _start_bob() -> void:
	if _bob_tween != null:
		_bob_tween.kill()
	_bob_y = 0.0
	_apply_bob_y()
	var tween := create_tween()
	_bob_tween = tween
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "_bob_y", -_BOB_AMPLITUDE_PX, _BOB_HALF_DURATION_SEC)
	tween.tween_property(self, "_bob_y", _BOB_AMPLITUDE_PX, _BOB_HALF_DURATION_SEC)


func _apply_bob_y() -> void:
	if _icon == null:
		return
	# Same delta on both offsets shifts a full-rect child without fighting anchors.
	_icon.offset_top = _bob_y
	_icon.offset_bottom = _bob_y
