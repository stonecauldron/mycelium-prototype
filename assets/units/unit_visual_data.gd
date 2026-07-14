class_name UnitVisualData
extends Resource

@export var visual_scene: PackedScene
@export var idle_animation: StringName = &"idle"


func instantiate_visual() -> Node2D:
	if visual_scene == null:
		return null
	return visual_scene.instantiate() as Node2D


func play_idle(root: Node) -> void:
	play(root, idle_animation, true)


func play(root: Node, animation: StringName, randomize_start: bool = false) -> void:
	var player := find_animation_player(root)
	if player == null:
		return
	if not player.has_animation(animation):
		return
	player.play(animation)
	if not randomize_start:
		return
	var length := player.current_animation_length
	if length <= 0.0:
		return
	player.seek(randf() * length, true)


static func find_animation_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	var named := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if named != null:
		return named
	return root.find_child("AnimationPlayer", true, false) as AnimationPlayer
