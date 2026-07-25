class_name HoverPunch
extends Node

## Subtle scale-up + rotation shake on hover. Attach as a child of a Control.

@export var hover_scale: float = 1.06
@export var shake_degrees: float = 3.5
@export var scale_in_sec: float = 0.14
@export var scale_out_sec: float = 0.1
@export var shake_step_sec: float = 0.05

var _target: Control
var _tween: Tween
var _enter_enabled: bool = false


func _ready() -> void:
	_target = get_parent() as Control
	if _target == null:
		push_error("HoverPunch must be a child of a Control")
		return
	_target.mouse_entered.connect(play_enter)
	_target.mouse_exited.connect(play_exit)
	call_deferred("arm_enter_unless_hovered")


func play_enter() -> void:
	if not _enter_enabled or _target == null:
		return
	_kill_tween()
	_target.pivot_offset = _target.size * 0.5
	var dir := 1.0 if randf() < 0.5 else -1.0
	var shake := deg_to_rad(shake_degrees * randf_range(0.75, 1.2)) * dir
	var target_scale := hover_scale * randf_range(0.98, 1.03)
	var scale_in := scale_in_sec * randf_range(0.85, 1.15)
	var step := shake_step_sec * randf_range(0.85, 1.2)
	_tween = _target.create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_target, "scale", Vector2(target_scale, target_scale), scale_in)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_target, "rotation", shake, step)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.chain()
	_tween.set_parallel(false)
	_tween.tween_property(_target, "rotation", -shake, step * 1.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_target, "rotation", shake * 0.45, step * 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_target, "rotation", 0.0, step)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func play_exit() -> void:
	_enter_enabled = true
	if _target == null:
		return
	_kill_tween()
	_tween = _target.create_tween().set_parallel(true)
	_tween.tween_property(_target, "scale", Vector2.ONE, scale_out_sec)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_target, "rotation", 0.0, scale_out_sec)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func reset() -> void:
	_kill_tween()
	if _target == null:
		return
	_target.scale = Vector2.ONE
	_target.rotation = 0.0


func suppress_enter() -> void:
	_enter_enabled = false


func arm_enter_unless_hovered() -> void:
	if _target == null or not _target.is_visible_in_tree():
		_enter_enabled = true
		return
	_enter_enabled = not _target.get_global_rect().has_point(_target.get_global_mouse_position())


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
