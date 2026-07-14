class_name UnitVisualRoot
extends Node2D


func play(animation: StringName, randomize_start: bool = false) -> void:
	var player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player == null or not player.has_animation(animation):
		return
	player.play(animation)
	if not randomize_start:
		return
	var length := player.current_animation_length
	if length <= 0.0:
		return
	player.seek(randf() * length, true)
