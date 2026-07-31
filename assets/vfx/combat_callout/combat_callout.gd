class_name CombatCallout
extends Node2D

enum Kind { STREAK, FALLEN, VICTORY }

const FLOAT_DISTANCE := 40.0
const STREAK_DURATION := 1.15
const FALLEN_DURATION := 1.35
const VICTORY_DURATION := 1.6
const SPAWN_JITTER_X := 18.0
const STREAK_COLOR := Color(1.0, 0.88, 0.35, 1.0)
const FALLEN_COLOR := Color(0.75, 0.82, 0.95, 1.0)
const VICTORY_COLOR := Color(1.0, 0.92, 0.35, 1.0)
const VICTORY_FONT_SIZE := 64
const VICTORY_FLOAT := 28.0

@onready var _label: Label = $Label


func display(text: String, kind: Kind = Kind.STREAK) -> void:
	_label.text = text
	if kind != Kind.VICTORY:
		position.x += randf_range(-SPAWN_JITTER_X, SPAWN_JITTER_X)
		rotation_degrees = randf_range(-8.0, 8.0)

	var duration := STREAK_DURATION
	var end_scale := 1.35
	var start_scale := 2.1
	var float_distance := FLOAT_DISTANCE
	match kind:
		Kind.STREAK:
			_label.modulate = STREAK_COLOR
			end_scale = 1.45
			start_scale = 2.35
		Kind.FALLEN:
			_label.modulate = FALLEN_COLOR
			duration = FALLEN_DURATION
			end_scale = 1.2
			start_scale = 1.85
		Kind.VICTORY:
			_label.modulate = VICTORY_COLOR
			_label.add_theme_font_size_override(&"font_size", VICTORY_FONT_SIZE)
			_label.offset_left = -280.0
			_label.offset_right = 280.0
			_label.offset_top = -40.0
			_label.offset_bottom = 40.0
			duration = VICTORY_DURATION
			end_scale = 1.15
			start_scale = 2.4
			float_distance = VICTORY_FLOAT

	scale = Vector2(start_scale, start_scale)

	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(end_scale, end_scale), 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - float_distance, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "modulate:a", 0.0, duration)\
		.set_delay(duration * 0.45)
	tween.chain().tween_callback(queue_free)
