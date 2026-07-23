class_name UnitAppearance
extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var body_shape: CollisionShape2D = $BodyShape
@onready var weapon_mount: Node2D = $WeaponMount
@onready var sprite: Sprite2D = $Sprite

var _sprite_rest_position: Vector2 = Vector2.ZERO
var _sprite_rest_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	if sprite == null:
		sprite = get_node_or_null("Sprite") as Sprite2D
	if sprite != null:
		_sprite_rest_position = sprite.position
		_sprite_rest_scale = sprite.scale


func mount_weapon_appearance(weapon: WeaponData) -> void:
	var mount := weapon_mount
	if mount == null:
		mount = get_node_or_null("WeaponMount") as Node2D
	if mount == null:
		return
	for child in mount.get_children():
		mount.remove_child(child)
		child.free()
	if weapon == null:
		return
	var held := weapon.instantiate_appearance()
	if held == null:
		return
	mount.add_child(held)


func play(animation: StringName, randomize_start: bool = false) -> void:
	var player := animation_player
	if player == null:
		player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player == null or not player.has_animation(animation):
		return
	player.play(animation)
	if not randomize_start:
		return
	var length := player.current_animation_length
	if length <= 0.0:
		return
	player.seek(randf() * length, true)


func play_idle(randomize_start: bool = true) -> void:
	if _is_playing(&"idle"):
		return
	_reset_sprite_rest_pose()
	play(&"idle", randomize_start)


func play_walk(randomize_start: bool = true) -> void:
	if _is_playing(&"walk"):
		return
	play(&"walk", randomize_start)


func _is_playing(animation: StringName) -> bool:
	var player := animation_player
	if player == null:
		player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player == null:
		return false
	return player.is_playing() and player.current_animation == animation


func _reset_sprite_rest_pose() -> void:
	if sprite == null:
		sprite = get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		return
	sprite.position = _sprite_rest_position
	sprite.scale = _sprite_rest_scale
