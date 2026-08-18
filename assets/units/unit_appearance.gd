class_name UnitAppearance
extends Node2D

const PLAYER_CHILD_BASE_SCENE := "res://assets/units/generalist/player_child_base.tscn"
const PLAYER_IMAGO_BASE_SCENE := "res://assets/units/generalist/player_imago_base.tscn"
const DEFAULT_CHILD_BODY_SCENE := "res://assets/units/generalist/gen_child_body.tscn"
const DEFAULT_IMAGO_BODY_SCENE := "res://assets/units/generalist/gen_imago_body.tscn"
const DEFAULT_CHILD_CAP_SCENE := "res://assets/units/generalist/gen_child_cap.tscn"
const DEFAULT_IMAGO_CAP_SCENE := "res://assets/units/generalist/gen_imago_cap.tscn"

const DEFAULT_CHILD_BODY := Color("E4C8A2")
const DEFAULT_CHILD_CAP := Color("51422D")
const DEFAULT_IMAGO_BODY := Color("E4C8A2")
const DEFAULT_IMAGO_CAP := Color("472D1C")

const BODY_NODE_NAME := &"Body"

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var body_shape: CollisionShape2D = $BodyShape

var hurtbox: HurtboxComponent
var weapon_mount: Node2D
var sprite: Sprite2D
var _body_root: Node2D
var _cap_root: Node

var _sprite_rest_position: Vector2 = Vector2.ZERO
var _sprite_rest_scale: Vector2 = Vector2.ONE
var _sprite_rest_captured: bool = false
var _body_scale_factor: float = 1.0


func _ready() -> void:
	_resolve_composed_refs()
	_capture_sprite_rest_pose()


## Player composition: shared base (collider + anim) + body + cap.
## Player units compose base + body + cap; enemies use a packed appearance scene.
static func compose_player(
	is_adult: bool,
	body_mutation: MutationData = null,
	cap_mutation: MutationData = null
) -> UnitAppearance:
	var base_path := PLAYER_IMAGO_BASE_SCENE if is_adult else PLAYER_CHILD_BASE_SCENE
	var base_scene := load(base_path) as PackedScene
	if base_scene == null:
		return null
	var appearance := base_scene.instantiate() as UnitAppearance
	if appearance == null:
		return null
	appearance._mount_body_and_cap(is_adult, body_mutation, cap_mutation)
	appearance.apply_mutation_tints(is_adult, body_mutation, cap_mutation)
	return appearance


## Backward-compatible alias used by older call sites / scratch checks.
static func instantiate_player_layers(
	is_adult: bool,
	body_mutation: MutationData = null,
	cap_mutation: MutationData = null
) -> UnitAppearance:
	return compose_player(is_adult, body_mutation, cap_mutation)


func _mount_body_and_cap(
	is_adult: bool,
	body_mutation: MutationData,
	cap_mutation: MutationData
) -> void:
	var body_scene := _resolve_body_scene(is_adult, body_mutation)
	if body_scene == null:
		return
	var body := body_scene.instantiate() as Node2D
	if body == null:
		return
	body.name = String(BODY_NODE_NAME)
	add_child(body)
	_body_root = body

	var cap_mount := body.get_node_or_null("CapMount") as Node2D
	var cap_scene := _resolve_cap_scene(is_adult, cap_mutation)
	if cap_mount != null and cap_scene != null:
		var cap := cap_scene.instantiate()
		if cap != null:
			cap_mount.add_child(cap)
			_cap_root = cap

	_resolve_composed_refs()
	_sprite_rest_captured = false
	_capture_sprite_rest_pose()


func _resolve_body_scene(is_adult: bool, body_mutation: MutationData) -> PackedScene:
	if body_mutation != null:
		var custom := body_mutation.appearance_for(is_adult)
		if custom != null:
			return custom
	var path := DEFAULT_IMAGO_BODY_SCENE if is_adult else DEFAULT_CHILD_BODY_SCENE
	return load(path) as PackedScene


func _resolve_cap_scene(is_adult: bool, cap_mutation: MutationData) -> PackedScene:
	if cap_mutation != null:
		var custom := cap_mutation.appearance_for(is_adult)
		if custom != null:
			return custom
	var path := DEFAULT_IMAGO_CAP_SCENE if is_adult else DEFAULT_CHILD_CAP_SCENE
	return load(path) as PackedScene


func _resolve_composed_refs() -> void:
	if animation_player == null:
		animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if body_shape == null:
		body_shape = get_node_or_null("BodyShape") as CollisionShape2D

	_body_root = get_node_or_null(NodePath(String(BODY_NODE_NAME))) as Node2D
	if _body_root != null:
		sprite = _body_root.get_node_or_null("Sprite") as Sprite2D
		hurtbox = _body_root.get_node_or_null("Hurtbox") as HurtboxComponent
		weapon_mount = _body_root.get_node_or_null("WeaponMount") as Node2D
		var cap_mount := _body_root.get_node_or_null("CapMount") as Node2D
		if cap_mount != null and cap_mount.get_child_count() > 0:
			_cap_root = cap_mount.get_child(0)
	else:
		# Legacy flat enemy / specialty appearance layout.
		sprite = get_node_or_null("Sprite") as Sprite2D
		hurtbox = get_node_or_null("Hurtbox") as HurtboxComponent
		weapon_mount = get_node_or_null("WeaponMount") as Node2D
		_cap_root = get_node_or_null("Cap")


func apply_mutation_tints(
	is_adult: bool,
	body_mutation: MutationData = null,
	cap_mutation: MutationData = null
) -> void:
	_resolve_composed_refs()
	var body_tint := DEFAULT_IMAGO_BODY if is_adult else DEFAULT_CHILD_BODY
	var cap_tint := DEFAULT_IMAGO_CAP if is_adult else DEFAULT_CHILD_CAP
	if body_mutation != null:
		body_tint = body_mutation.tint
	if cap_mutation != null:
		cap_tint = cap_mutation.tint
	var body_sprite := _body_sprite()
	if body_sprite != null:
		body_sprite.modulate = body_tint
	if _cap_root is CanvasItem:
		(_cap_root as CanvasItem).self_modulate = cap_tint


## Scales visual + collision volumes (juvenile fallback from imago art / enemies).
## Root scale is enough: hurtbox/body/weapon mount are children and inherit it.
## Combat remounts BodyShape with global_transform preserved so volume stays correct.
func apply_body_scale(factor: float) -> void:
	if factor <= 0.0 or is_equal_approx(factor, 1.0):
		return
	_body_scale_factor = factor
	scale = Vector2(_body_scale_factor, _body_scale_factor)


func get_body_scale() -> Vector2:
	return Vector2(_body_scale_factor, _body_scale_factor)


func reset_body_scale() -> void:
	scale = get_body_scale()


func mount_weapon_appearance(weapon: WeaponData) -> void:
	_resolve_composed_refs()
	var mount := weapon_mount
	if mount == null:
		mount = get_node_or_null("WeaponMount") as Node2D
	if mount == null and _body_root != null:
		mount = _body_root.get_node_or_null("WeaponMount") as Node2D
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


## Axis-aligned bounds of visible sprites in this appearance's local space.
## Origin is the feet pivot; y is typically negative (up).
func visual_rect_local(include_weapon: bool = true) -> Rect2:
	var merged := Rect2()
	var has_rect := false
	var stack: Array = [[self, Transform2D.IDENTITY]]
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var node: Node = pair[0]
		var xf: Transform2D = pair[1]
		if not include_weapon and node.name == "WeaponMount":
			continue
		if node is Sprite2D:
			var sprite_2d := node as Sprite2D
			if sprite_2d.visible and sprite_2d.texture != null:
				var r := sprite_2d.get_rect()
				var corners: Array[Vector2] = [
					xf * r.position,
					xf * Vector2(r.end.x, r.position.y),
					xf * r.end,
					xf * Vector2(r.position.x, r.end.y),
				]
				for point in corners:
					if not has_rect:
						merged = Rect2(point, Vector2.ZERO)
						has_rect = true
					else:
						merged = merged.expand(point)
		for child in node.get_children():
			var child_xf := xf
			if child is Node2D:
				child_xf = xf * (child as Node2D).transform
			stack.append([child, child_xf])
	return merged


func _body_sprite() -> Sprite2D:
	if sprite != null:
		return sprite
	_resolve_composed_refs()
	return sprite


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
