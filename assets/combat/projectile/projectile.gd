class_name Projectile
extends Area2D

## Shared ballistic projectile. Per-weapon scenes reuse this script with different
## sprites / exports; override hooks only when flight or impact logic differs.
## Avoids typed refs to Unit/WeaponData so PackedScene links from WeaponData don't cycle.

const FLOOR_Y := 786.0
const _SPORE_CLOUD_SCENE := preload("res://assets/vfx/spore_cloud/spore_cloud.tscn")
## Mortar blast tint — distinct from death-spore beige / enemy red.
const _MORTAR_SPORE_COLOR := Color("9dcc6a")

@export var launch_angle_deg: float = 45.0
@export var fallback_speed: float = 600.0
@export var max_lifetime: float = 2.5
@export var stick_hold_time: float = 1.6
@export var stick_fade_time: float = 1.2
## Explosion radius after landing (mortar). 0 = no AOE.
@export var aoe_radius: float = 0.0
## Fuse seconds after landing before AOE (mortar). >0 also ignores unit collisions in flight.
@export var explode_delay: float = 0.0
## Keep flying through units, damaging each once (giant horn). Unrelated to blunt damage type.
@export var piercing: bool = false
## After ballistic apex, steer toward a locked target with no gravity (sniper).
@export var homing: bool = false

var damage: int = 0
var knockback_force: float = 0.0
## Matches WeaponData.DamageType (int) without importing WeaponData here.
var damage_type: int = 0
var owner_unit: Node
var homing_target: Node2D
var _velocity: Vector2 = Vector2.ZERO
var _lifetime: float = 0.0
var _spent: bool = false
var _hit_targets: Dictionary = {}
var _fuse_armed: bool = false
## Homing projectiles fly a normal arc until apex, then lock on.
var _homing_active: bool = false


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
	# Homing waits for apex (vy crosses upward→down). Already descending → home now.
	_homing_active = homing and _velocity.y >= 0.0
	_face_velocity()
	# Delayed bombs ignore units until they land.
	monitoring = explode_delay <= 0.0
	monitorable = false


func set_homing_target(target: Node2D) -> void:
	homing_target = target


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
	if homing and _homing_active:
		_physics_homing_flight(delta)
		return
	var prev_vy := _velocity.y
	_velocity += _gravity_vector() * delta
	if homing and not _homing_active and prev_vy < 0.0 and _velocity.y >= 0.0:
		_homing_active = true
	var next_position := global_position + _velocity * delta
	if next_position.y >= FLOOR_Y:
		global_position = next_position
		global_position.y = FLOOR_Y
		_face_velocity()
		_on_reached_ground()
		return
	global_position = next_position
	_face_velocity()


func _physics_homing_flight(delta: float) -> void:
	var speed := maxf(fallback_speed * 2.0, 1.0)
	if _is_homing_target_alive():
		var to_target := (homing_target as Node2D).global_position - global_position
		if to_target.length_squared() > 1.0:
			_velocity = to_target.normalized() * speed
	# Else keep last velocity and fly straight (no gravity).
	var next_position := global_position + _velocity * delta
	if next_position.y >= FLOOR_Y:
		global_position = next_position
		global_position.y = FLOOR_Y
		_face_velocity()
		_on_reached_ground()
		return
	global_position = next_position
	_face_velocity()


func _is_homing_target_alive() -> bool:
	if homing_target == null or not is_instance_valid(homing_target):
		return false
	if homing_target.has_method("get") and homing_target.get("_dying") == true:
		return false
	if homing_target.get("current_hp") != null and int(homing_target.get("current_hp")) <= 0:
		return false
	return true


func _on_reached_ground() -> void:
	if explode_delay > 0.0 and aoe_radius > 0.0:
		_arm_fuse()
		return
	_stick_and_fade()


func _arm_fuse() -> void:
	if _spent or _fuse_armed:
		return
	_fuse_armed = true
	_spent = true
	_velocity = Vector2.ZERO
	set_deferred("monitoring", false)
	set_physics_process(false)
	var timer := get_tree().create_timer(explode_delay)
	timer.timeout.connect(_explode_aoe)


func _explode_aoe() -> void:
	if not is_inside_tree():
		return
	var origin := global_position
	_spawn_aoe_spore_cloud(origin)
	var radius_sq := aoe_radius * aoe_radius
	var killer: Node = (
		owner_unit if owner_unit != null and is_instance_valid(owner_unit) else null
	)
	for node in get_tree().get_nodes_in_group("units"):
		if node == null or not is_instance_valid(node) or not (node is Node2D):
			continue
		var unit := node as Node2D
		if unit.global_position.distance_squared_to(origin) > radius_sq:
			continue
		if not _is_valid_target(unit):
			continue
		if not unit.has_method("take_damage"):
			continue
		unit.call("take_damage", damage, origin, knockback_force, killer, damage_type)
	queue_free()


func _spawn_aoe_spore_cloud(origin: Vector2) -> void:
	var parent := get_parent()
	if parent == null or aoe_radius <= 0.0:
		return
	var cloud := _SPORE_CLOUD_SCENE.instantiate() as SporeCloud
	if cloud == null:
		return
	parent.add_child(cloud)
	cloud.global_position = origin
	cloud.burst_aoe(aoe_radius, _MORTAR_SPORE_COLOR)


## Override for AOE / multi-hit. Default = damage closest valid hurtbox.
func _on_impact(hurtbox: Area2D) -> void:
	if hurtbox == null or not hurtbox.has_method("receive_hit"):
		return
	var target: Node = null
	if hurtbox.has_method("get_combatant"):
		target = hurtbox.call("get_combatant")
	if target != null and _hit_targets.has(target):
		return
	if target != null:
		_hit_targets[target] = true
	var from_pos := (
		(owner_unit as Node2D).global_position
		if owner_unit is Node2D
		else global_position
	)
	var killer: Node = owner_unit if owner_unit != null and is_instance_valid(owner_unit) else null
	hurtbox.call("receive_hit", damage, from_pos, knockback_force, killer, damage_type)
	if killer != null:
		if killer.has_method("grant_hit_biomass"):
			var hit_at: Node2D = target as Node2D if target is Node2D else self
			killer.call("grant_hit_biomass", hit_at)
		var roster = killer.get("roster_data")
		if roster != null and roster.has_method("call_combat_effect"):
			roster.call_combat_effect(&"on_hit_dealt", [killer, target, damage])


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_lifetime += delta
	if _lifetime >= max_lifetime:
		if explode_delay > 0.0 and aoe_radius > 0.0:
			_arm_fuse()
		else:
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
	if _spent or explode_delay > 0.0:
		return
	_resolve_hit()


func _resolve_hit() -> void:
	# Umbrella / projectile blockers destroy the shot with no damage.
	for area in get_overlapping_areas():
		if area is ProjectileBlocker:
			var blocker := area as ProjectileBlocker
			if blocker.blocks_projectile_from(_get_owner_troop()):
				_stick_and_fade()
				return

	if piercing:
		_resolve_piercing_hits()
		return

	var chosen: Area2D = null
	var closest_distance := INF
	for area in get_overlapping_areas():
		if area is ProjectileBlocker:
			continue
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


func _resolve_piercing_hits() -> void:
	for area in get_overlapping_areas():
		if area is ProjectileBlocker:
			continue
		if not area.has_method("get_combatant") or not area.has_method("receive_hit"):
			continue
		var target: Node = area.call("get_combatant")
		if target == null or _hit_targets.has(target):
			continue
		if not _is_valid_target(target):
			continue
		_on_impact(area)


func _on_body_entered(_body: Node2D) -> void:
	if _spent:
		return
	_on_reached_ground()


func _is_valid_target(target: Node) -> bool:
	if target == null or target == owner_unit:
		return false
	if owner_unit == null:
		return false
	var owner_troop = _get_owner_troop()
	if owner_troop == null:
		return false
	if target.has_method("is_combat_obstacle") and target.call("is_combat_obstacle"):
		# Only the opposing army can damage a wall.
		return bool(owner_troop.get("is_enemy")) != bool(target.get("is_enemy"))
	var target_troop := _get_troop(target)
	if target_troop == null:
		return false
	return bool(owner_troop.get("is_enemy")) != bool(target_troop.get("is_enemy"))


func _get_troop(target: Node) -> Node:
	if target == null:
		return null
	return target.get("_troop")


func _get_owner_troop() -> Node:
	if owner_unit == null:
		return null
	return owner_unit.get("_troop")


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
