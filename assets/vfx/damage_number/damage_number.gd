class_name DamageNumber
extends Node2D

const FLOAT_DISTANCE := 48.0
const DURATION := 0.75
const SPAWN_JITTER_X := 28.0
const BIG_HIT_THRESHOLD := 8
const BIG_HIT_COLOR := Color(1.0, 0.82, 0.28, 1.0)
const MIN_END_SCALE := 1.45
const MAX_END_SCALE := 3.1
const SCALE_DAMAGE_REF := 14.0
const POP_MULT := 1.55

@onready var _label: Label = $Label


func display(amount: int) -> void:
	_label.text = str(amount)
	position.x += randf_range(-SPAWN_JITTER_X, SPAWN_JITTER_X)
	rotation_degrees = randf_range(-14.0, 14.0)

	var t := clampf(float(amount) / SCALE_DAMAGE_REF, 0.0, 1.0)
	# Ease-in so mid/high hits pull farther apart from chips.
	t = t * t
	var end_scale := lerpf(MIN_END_SCALE, MAX_END_SCALE, t)
	var start_scale := end_scale * POP_MULT
	if amount >= BIG_HIT_THRESHOLD:
		_label.modulate = BIG_HIT_COLOR
	scale = Vector2(start_scale, start_scale)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(end_scale, end_scale), 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - FLOAT_DISTANCE, DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "modulate:a", 0.0, DURATION)\
		.set_delay(DURATION * 0.35)
	tween.chain().tween_callback(queue_free)
