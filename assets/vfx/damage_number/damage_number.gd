class_name DamageNumber
extends Node2D

const FLOAT_DISTANCE := 48.0
const DURATION := 0.75
const DRIFT_X := 8.0

@onready var _label: Label = $Label


func display(amount: int) -> void:
	_label.text = str(amount)
	position.x += randf_range(-DRIFT_X, DRIFT_X)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - FLOAT_DISTANCE, DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "modulate:a", 0.0, DURATION)\
		.set_delay(DURATION * 0.35)
	tween.chain().tween_callback(queue_free)
