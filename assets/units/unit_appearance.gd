class_name UnitAppearance
extends Node2D

const LAYERED_CHILD_SCENE := "res://assets/units/generalist/gen_child_appearance.tscn"
const LAYERED_IMAGO_SCENE := "res://assets/units/generalist/gen_imago_appearance.tscn"

const DEFAULT_CHILD_BODY := Color("E4C8A2")
const DEFAULT_CHILD_CAP := Color("51422D")
const DEFAULT_IMAGO_BODY := Color("E4C8A2")
const DEFAULT_IMAGO_CAP := Color("472D1C")

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var body_shape: CollisionShape2D = $BodyShape
@onready var weapon_mount: Node2D = $WeaponMount
@onready var sprite: Sprite2D = $Sprite

var _sprite_rest_position: Vector2 = Vector2.ZERO
var _sprite_rest_scale: Vector2 = Vector2.ONE
var _sprite_rest_captured: bool = false
var _body_scale_factor: float = 1.0
var _silhouette_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_capture_sprite_rest_pose()


## Player composition: layered Generalist body + cap for the life stage.
## Specialty full-body strain scenes are not used here.
static func instantiate_player_layers(
	is_adult: bool,
	body_mutation: MutationData = null,
	cap_mutation: MutationData = null
) -> UnitAppearance:
	var path := LAYERED_IMAGO_SCENE if is_adult else LAYERED_CHILD_SCENE
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var appearance := scene.instantiate() as UnitAppearance
	if appearance == null:
		return null
	appearance.apply_mutation_tints(is_adult, body_mutation, cap_mutation)
	return appearance


func apply_mutation_tints(
	is_adult: bool,
	body_mutation: MutationData = null,
	cap_mutation: MutationData = null
) -> void:
	var body_sprite := _body_sprite()
	var cap := _cap_sprite()
	var body_tint := DEFAULT_IMAGO_BODY if is_adult else DEFAULT_CHILD_BODY
	var cap_tint := DEFAULT_IMAGO_CAP if is_adult else DEFAULT_CHILD_CAP
	if body_mutation != null:
		body_tint = body_mutation.tint
	if cap_mutation != null:
		cap_tint = cap_mutation.tint
	if body_sprite != null:
		body_sprite.modulate = body_tint
	if cap != null:
		cap.modulate = cap_tint


## Body-mutation silhouette: scales visual layers + hurtbox.
## Call after combat remounts BodyShape so the physics collider stays base-sized.
func apply_body_mutation_silhouette(body_mutation: MutationData) -> void:
	var factor := Vector2.ONE
	if body_mutation != null:
		factor = body_mutation.silhouette_scale
	if factor.x <= 0.0 or factor.y <= 0.0:
		factor = Vector2.ONE
	_silhouette_scale = factor
	_apply_combined_scale()


## Scales visual + collision volumes (juvenile fallback from imago art).
## Root scale is enough: hurtbox/body/weapon mount are children and inherit it.
## Combat remounts BodyShape with global_transform preserved so volume stays correct.
func apply_body_scale(factor: float) -> void:
	if factor <= 0.0 or is_equal_approx(factor, 1.0):
		return
	_body_scale_factor = factor
	_apply_combined_scale()


func get_body_scale() -> Vector2:
	return Vector2(_body_scale_factor, _body_scale_factor) * _silhouette_scale


func reset_body_scale() -> void:
	_apply_combined_scale()


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


func _apply_combined_scale() -> void:
	scale = Vector2(_body_scale_factor, _body_scale_factor) * _silhouette_scale


func _body_sprite() -> Sprite2D:
	if sprite != null:
		return sprite
	sprite = get_node_or_null("Sprite") as Sprite2D
	return sprite


func _cap_sprite() -> Sprite2D:
	return get_node_or_null("Cap") as Sprite2D


func _is_playing(animation: StringName) -> bool:
	var player := animation_player
	if player == null:
		player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player == null:
		return false
	return player.is_playing() and player.current_animation == animation


func _capture_sprite_rest_pose() -> void:
	if _sprite_rest_captured:
		return
	var body_sprite := _body_sprite()
	if body_sprite == null:
		return
	_sprite_rest_position = body_sprite.position
	_sprite_rest_scale = body_sprite.scale
	_sprite_rest_captured = true


func _reset_sprite_rest_pose() -> void:
	_capture_sprite_rest_pose()
	var body_sprite := _body_sprite()
	if body_sprite == null:
		return
	body_sprite.position = _sprite_rest_position
	body_sprite.scale = _sprite_rest_scale
