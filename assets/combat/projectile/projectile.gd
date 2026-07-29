class_name Projectile
extends Area2D

## Shared ballistic projectile. Per-weapon scenes reuse this script with different
## sprites / exports; override hooks only when flight or impact logic differs.
## Avoids typed refs to Unit/WeaponData so PackedScene links from WeaponData don't cycle.

const FLOOR_Y := 786.0

@export var launch_angle_deg: float = 45.0
@export var fallback_speed: float = 600.0
@export var max_lifetime: float = 2.5
@export var stick_hold_time: float = 1.6
@export var stick_fade_time: float = 1.2

var damage: int = 0
var knockback_force: float = 0.0
## Matches WeaponData.DamageType (int) without importing WeaponData here.
var damage_type: int = 0
var owner_unit: Node
var _velocity: Vector2 = Vector2.ZERO
var _lifetime: float = 0.0
var _spent: bool = false


func _ready() -> void:
	add_to_group("projectiles")
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func launch(
	from_global: Vector2,
	aim_global: Vector2,
	attack_damage: int,
	attack_knockback: float,
	thrower: Node
) -> void:
	global_position = from_global
	damage = attack_damage
	knockback_force = attack_knockback
	owner_unit = thrower
	if thrower != null:
		var w = thrower.get("weapon")
		if w != null and w.get("damage_type") != null:
			damage_type = int(w.damage_type)
	_velocity = _compute_launch_velocity(from_global, aim_global)
	_face_velocity()
	monitoring = true
	monitorable = false


## Override for custom arcs (e.g. flatter crossbow). Default = lobbed ballistic.
func _compute_launch_velocity(from_global: Vector2, aim_global: Vector2) -> Vector2:
	var displacement := aim_global - from_global
	var direction_x := signf(displacement.x)
	if direction_x == 0.0:
		var troop = owner_unit.get("_troop") if owner_unit != null else null
		direction_x = 1.0 if troop == null or not bool(troop.get("is_enemy")) else -1.0

	var launch_angle := deg_to_rad(launch_angle_deg)
	var gravity_y := _gravity_vector().y
	var dx := absf(displacement.x)
	var dy := displacement.y
	var cos_a := cos(launch_angle)
	var tan_a := tan(launch_angle)
	# Godot Y+ is down: v² = g·dx² / (2·cos²α · (dy + dx·tanα))
	var denominator := 2.0 * cos_a * cos_a * (dy + dx * tan_a)
	var speed := fallback_speed
	if denominator > 1.0:
		speed = sqrt(gravity_y * dx * dx / denominator)

	var angle := -launch_angle if direction_x > 0.0 else -PI + launch_angle
	return Vector2(cos(angle), sin(angle)) * speed


## Override for homing / other in-flight behaviour. Default = gravity + integrate.
func _physics_flight(delta: float) -> void:
	_velocity += _gravity_vector() * delta
	var next_position := global_position + _velocity * delta
	if next_position.y >= FLOOR_Y:
		global_position = next_position
		global_position.y = FLOOR_Y
		_face_velocity()
		_stick_and_fade()
		return
	global_position = next_position
	_face_velocity()


## Override for AOE / multi-hit. Default = damage closest valid hurtbox.
func _on_impact(hurtbox: Area2D) -> void:
	if hurtbox == null or not hurtbox.has_method("receive_hit"):
		return
	var from_pos := (
		(owner_unit as Node2D).global_position
		if owner_unit is Node2D
		else global_position
	)
	var killer: Node = owner_unit if owner_unit != null and is_instance_valid(owner_unit) else null
	hurtbox.call("receive_hit", damage, from_pos, knockback_force, killer, damage_type)
	if killer != null:
		var roster = killer.get("roster_data")
		if roster != null and roster.get("strain") != null:
			var target = hurtbox.call("get_combatant") if hurtbox.has_method("get_combatant") else null
			roster.strain.call_effect(&"on_hit_dealt", [killer, target, damage])


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_lifetime += delta
	if _lifetime >= max_lifetime:
		_stick_and_fade()
		return
	_physics_flight(delta)


func _gravity_vector() -> Vector2:
	var gravity_strength := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	return Vector2(0.0, gravity_strength)


func _face_velocity() -> void:
	if _velocity.length_squared() < 1.0:
		return
	rotation = _velocity.angle()


func _on_area_entered(_area: Area2D) -> void:
	if _spent:
		return
	_resolve_hit()


func _resolve_hit() -> void:
	var chosen: Area2D = null
	var closest_distance := INF
	for area in get_overlapping_areas():
		if not area.has_method("get_combatant") or not area.has_method("receive_hit"):
			continue
		var target: Node = area.call("get_combatant")
		if not _is_valid_target(target):
			continue
		var distance := global_position.distance_squared_to((target as Node2D).global_position)
		if chosen == null or distance < closest_distance:
			chosen = area
			closest_distance = distance
	if chosen == null:
		return
	_spent = true
	set_deferred("monitoring", false)
	_on_impact(chosen)
	queue_free()


func _on_body_entered(_body: Node2D) -> void:
	if _spent:
		return
	_stick_and_fade()


func _is_valid_target(target: Node) -> bool:
	if target == null or target == owner_unit:
		return false
	if target.has_method("is_combat_obstacle") and target.call("is_combat_obstacle"):
		return true
	if owner_unit == null:
		return false
	var owner_troop = owner_unit.get("_troop")
	if owner_troop == null:
		return false
	var target_troop := _get_troop(target)
	if target_troop == null:
		return false
	return bool(owner_troop.get("is_enemy")) != bool(target_troop.get("is_enemy"))


func _get_troop(target: Node) -> Node:
	if target == null:
		return null
	return target.get("_troop")


func _stick_and_fade() -> void:
	if _spent:
		return
	_spent = true
	_velocity = Vector2.ZERO
	set_deferred("monitoring", false)
	set_physics_process(false)
	if global_position.y > FLOOR_Y:
		global_position.y = FLOOR_Y
	var tween := create_tween()
	tween.tween_interval(stick_hold_time)
	tween.tween_property(self, "modulate:a", 0.0, stick_fade_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
