class_name ArrowProjectile
extends Area2D

const MAX_LIFETIME := 3.5
## Matches WorldBoundary/Floor in combat_stage.tscn.
const FLOOR_Y := 786.0
const LAUNCH_ANGLE := deg_to_rad(60.0)
const FALLBACK_SPEED := 900.0
const STUCK_HOLD_TIME := 1.6
const STUCK_FADE_TIME := 1.2

var damage: int = 0
var knockback_force: float = 0.0
var owner_unit: Unit
var _velocity: Vector2 = Vector2.ZERO
var _lifetime: float = 0.0
var _spent: bool = false


func launch(
	from_global: Vector2,
	aim_global: Vector2,
	attack_damage: int,
	attack_knockback: float,
	thrower: Unit
) -> void:
	global_position = from_global
	damage = attack_damage
	knockback_force = attack_knockback
	owner_unit = thrower
	_velocity = _angle_launch_velocity(from_global, aim_global)
	_face_velocity()
	monitoring = true
	monitorable = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _spent:
		return

	_lifetime += delta
	if _lifetime >= MAX_LIFETIME:
		_stick_and_fade()
		return

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


func _gravity_vector() -> Vector2:
	var gravity_strength := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	return Vector2(0.0, gravity_strength)


func _angle_launch_velocity(from_global: Vector2, aim_global: Vector2) -> Vector2:
	var displacement := aim_global - from_global
	var direction_x := signf(displacement.x)
	if direction_x == 0.0:
		direction_x = 1.0 if owner_unit == null or not owner_unit._troop.is_enemy else -1.0

	var gravity_y := _gravity_vector().y
	var dx := absf(displacement.x)
	var dy := displacement.y
	var cos_a := cos(LAUNCH_ANGLE)
	var tan_a := tan(LAUNCH_ANGLE)
	# Godot Y+ is down: v² = g·dx² / (2·cos²α · (dy + dx·tanα))
	var denominator := 2.0 * cos_a * cos_a * (dy + dx * tan_a)
	var speed := FALLBACK_SPEED
	if denominator > 1.0:
		speed = sqrt(gravity_y * dx * dx / denominator)

	var angle := -LAUNCH_ANGLE if direction_x > 0.0 else -PI + LAUNCH_ANGLE
	return Vector2(cos(angle), sin(angle)) * speed


func _face_velocity() -> void:
	if _velocity.length_squared() < 1.0:
		return
	rotation = _velocity.angle()


func _on_area_entered(_area: Area2D) -> void:
	if _spent:
		return
	_resolve_hit()


func _resolve_hit() -> void:
	var chosen: HurtboxComponent = null
	var closest_distance := INF

	for area in get_overlapping_areas():
		var hurtbox := area as HurtboxComponent
		if hurtbox == null:
			continue
		var target := hurtbox.get_combatant()
		if not _is_valid_target(target):
			continue
		var distance := global_position.distance_squared_to((target as Node2D).global_position)
		if chosen == null or distance < closest_distance:
			chosen = hurtbox
			closest_distance = distance

	if chosen == null:
		return

	_spent = true
	set_deferred("monitoring", false)
	var from_pos := owner_unit.global_position if owner_unit != null else global_position
	var killer: Unit = owner_unit if owner_unit != null and is_instance_valid(owner_unit) else null
	chosen.receive_hit(damage, from_pos, knockback_force, killer)
	queue_free()


func _on_body_entered(_body: Node2D) -> void:
	if _spent:
		return
	_stick_and_fade()


func _is_valid_target(target: Node) -> bool:
	if target == null or target == owner_unit or target is FlagBearer:
		return false
	if owner_unit == null or owner_unit._troop == null:
		return false
	var owner_troop: Troop = owner_unit._troop
	var target_troop := _get_troop(target)
	if target_troop == null:
		return false
	return owner_troop.is_enemy != target_troop.is_enemy


func _get_troop(target: Node) -> Troop:
	if target is Unit:
		return (target as Unit)._troop
	return null


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
	tween.tween_interval(STUCK_HOLD_TIME)
	tween.tween_property(self, "modulate:a", 0.0, STUCK_FADE_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
