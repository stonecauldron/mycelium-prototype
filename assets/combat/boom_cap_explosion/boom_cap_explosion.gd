class_name BoomCapExplosion
extends Node2D

const _PARTICLE_LIFETIME := 0.5
const _FLASH_FADE_SEC := 0.35
const _POLY_POINTS := 28
const _CAMERA_SHAKE := 0.42

var _damage: int = 0
var _radius: float = 100.0
var _knockback: float = 820.0
var _source: Unit = null
var _spent: bool = false

@onready var _embers: CPUParticles2D = %Embers
@onready var _sparks: CPUParticles2D = %Sparks
@onready var _shards: CPUParticles2D = %Shards


func _ready() -> void:
	_embers.texture = _make_ember_texture()
	_sparks.texture = _make_spark_texture()
	_shards.texture = _make_shard_texture()


func trigger(strength: int, radius: float, knockback: float, source: Unit) -> void:
	_damage = maxi(strength * 3, 1)
	_radius = radius
	_knockback = knockback
	_source = source
	if not is_node_ready():
		await ready
	_apply_damage()
	_add_camera_shake(_CAMERA_SHAKE)
	_flash_radius()
	_play_burst()
	var timer := get_tree().create_timer(_PARTICLE_LIFETIME + 0.2)
	await timer.timeout
	queue_free()


func _add_camera_shake(amount: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var camera := tree.get_first_node_in_group("battle_camera")
	if camera != null and camera.has_method("add_shake"):
		camera.add_shake(amount)


func _apply_damage() -> void:
	if _spent:
		return
	_spent = true
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	for node in units:
		var unit := node as Unit
		if unit == null or not is_instance_valid(unit) or unit == _source:
			continue
		if unit.global_position.distance_to(global_position) > _radius:
			continue
		unit.take_damage(
			_damage,
			global_position,
			_knockback,
			_source,
			WeaponData.DamageType.BLUNT
		)
	for node in get_tree().get_nodes_in_group("combat_obstacles"):
		if not is_instance_valid(node) or not node.has_method("take_damage"):
			continue
		if _source != null and _source._troop != null:
			if bool(node.get("is_enemy")) == _source._troop.is_enemy:
				continue
		if (node as Node2D).global_position.distance_to(global_position) > _radius:
			continue
		node.call("take_damage", _damage, global_position, _knockback, _source)


func _flash_radius() -> void:
	var poly := Polygon2D.new()
	poly.z_index = -1
	poly.color = Color(1.0, 0.4, 0.1, 0.5)
	var pts := PackedVector2Array()
	for i in _POLY_POINTS:
		var a := TAU * float(i) / float(_POLY_POINTS)
		pts.append(Vector2(cos(a), sin(a)) * _radius)
	poly.polygon = pts
	add_child(poly)
	# Draw under particle nodes.
	move_child(poly, 0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(poly, "modulate:a", 0.0, _FLASH_FADE_SEC)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(poly, "scale", Vector2(1.08, 1.08), _FLASH_FADE_SEC)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_burst() -> void:
	# Violent outward throw — particles reach ~radius quickly, then fall as debris.
	var speed := _radius / maxf(_PARTICLE_LIFETIME * 0.4, 0.01)
	_configure_burst(_embers, speed * 0.85, speed * 1.35, _radius * 0.12, _PARTICLE_LIFETIME)
	_configure_burst(_sparks, speed * 1.2, speed * 1.9, 0.0, _PARTICLE_LIFETIME * 0.85)
	_configure_burst(_shards, speed * 0.95, speed * 1.6, _radius * 0.05, _PARTICLE_LIFETIME)
	_embers.amount = 72
	_sparks.amount = 56
	_shards.amount = 40
	_embers.emitting = true
	_sparks.emitting = true
	_shards.emitting = true


func _configure_burst(
	particles: CPUParticles2D,
	speed_min: float,
	speed_max: float,
	emission_radius: float,
	lifetime: float
) -> void:
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = lifetime
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = emission_radius
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.initial_velocity_min = speed_min
	particles.initial_velocity_max = speed_max
	particles.gravity = Vector2(0, 780.0)
	particles.damping_min = 40.0
	particles.damping_max = 120.0


func _make_ember_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.95, 0.55, 1.0),
		Color(1.0, 0.45, 0.12, 0.95),
		Color(0.35, 0.08, 0.02, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 16
	texture.height = 16
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _make_spark_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 0.85, 1.0),
		Color(1.0, 0.7, 0.25, 0.9),
		Color(1.0, 0.3, 0.05, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 10
	texture.height = 10
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func _make_shard_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.75, 0.35, 1.0),
		Color(0.85, 0.25, 0.08, 0.95),
		Color(0.2, 0.04, 0.02, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 14
	texture.height = 8
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture
