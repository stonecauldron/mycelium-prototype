class_name BarkBubble
extends Node2D

signal dismissed

const BOUNDS := Rect2(-210, -245, 420, 245)
## Existing death/streak callouts rise from 140 px above the feet. Keep the
## opaque card above them; only its thin pointer crosses that feedback space.
const CALLOUT_CLEARANCE := 250.0

@onready var _speaker_label: Label = $SpeakerName
@onready var _line_label: Label = $Line
@onready var _timer: Timer = $ReadingTimer
@onready var _tail: Polygon2D = $Tail

var _speaker: Node2D = null


func _ready() -> void:
	_timer.timeout.connect(dismiss)


func can_show(speaker: Node2D) -> bool:
	if not is_instance_valid(speaker) or not speaker.is_inside_tree() or not speaker.is_visible_in_tree():
		return false
	if speaker is Unit and speaker.current_hp <= 0:
		return false
	var screen := get_viewport_rect().grow(-12.0)
	var canvas := get_canvas_transform()
	var anchor := _anchor_for(speaker)
	return (
		screen.has_point(canvas * speaker.global_position)
		and screen.encloses(canvas * Rect2(anchor + BOUNDS.position, BOUNDS.size))
	)


func present(speaker: Node2D, speaker_name: String, line: String, duration: float) -> bool:
	if not can_show(speaker):
		return false
	_speaker = speaker
	_speaker_label.text = speaker_name
	_line_label.text = line
	_update_position()
	show()
	_timer.start(duration)
	return true


func dismiss() -> void:
	_timer.stop()
	_speaker = null
	if visible:
		hide()
		dismissed.emit()


func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(_speaker) or not can_show(_speaker):
		dismiss()
		return
	_update_position()


func _anchor_for(speaker: Node2D) -> Vector2:
	var head := _head_for(speaker)
	return Vector2(head.x, minf(head.y, speaker.global_position.y - CALLOUT_CLEARANCE))


func _head_for(speaker: Node2D) -> Vector2:
	if speaker is Unit:
		return speaker.get_bark_anchor()
	return (speaker as FlagBearer).get_bark_anchor()


func _update_position() -> void:
	global_position = _anchor_for(_speaker)
	_tail.polygon = PackedVector2Array([
		Vector2(-22, -42), Vector2(17, -42), to_local(_head_for(_speaker)),
	])
