class_name BiomassNumber
extends Node2D

const FLOAT_DISTANCE := 48.0
const DURATION := 0.75
const SPAWN_JITTER_X := 28.0
const COLOR := Color(1.0, 0.88, 0.28, 1.0)

@onready var _row: HBoxContainer = $Row
@onready var _label: Label = %Label
@onready var _icon: TextureRect = %Icon


func display(amount: int) -> void:
	_label.text = "+%d" % amount
	_label.modulate = COLOR
	_icon.modulate = COLOR
	position.x += randf_range(-SPAWN_JITTER_X, SPAWN_JITTER_X)
	rotation_degrees = randf_range(-10.0, 10.0)
	scale = Vector2(1.6, 1.6)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - FLOAT_DISTANCE, DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_row, "modulate:a", 0.0, DURATION)\
		.set_delay(DURATION * 0.35)
	tween.chain().tween_callback(queue_free)
