class_name HitboxComponent
extends Area2D

@export var damage: int = 0
@export var knockback_force: float = 0.0
@export var owner_unit: Unit

var _targeting_mode: WeaponData.TargetingMode = WeaponData.TargetingMode.SINGLE
var _hit_combatants: Dictionary = {}


func _ready() -> void:
	monitoring = false


func enable_for_attack(
	attack_damage: int,
	attack_knockback: float,
	targeting_mode: WeaponData.TargetingMode
) -> void:
	damage = attack_damage
	knockback_force = attack_knockback
	_targeting_mode = targeting_mode
	_hit_combatants.clear()
	monitoring = true


func disable() -> void:
	if monitoring:
		_resolve_hits()
	monitoring = false
	_hit_combatants.clear()


func _resolve_hits() -> void:
	if _targeting_mode == WeaponData.TargetingMode.AOE:
		for area in get_overlapping_areas():
			_apply_hit_to_area(area)
		return

	_hit_single_target()


func _hit_single_target() -> void:
	var closest_unit: HurtboxComponent = null
	var closest_unit_distance := INF
	var flag_hurtboxes: Array[HurtboxComponent] = []

	for area in get_overlapping_areas():
		var hurtbox := area as HurtboxComponent
		var target := _get_valid_target(hurtbox)
		if target == null:
			continue
		if target is FlagBearer:
			flag_hurtboxes.append(hurtbox)
			continue
		var distance := owner_unit.global_position.distance_squared_to(
			(target as Node2D).global_position
		)
		if distance < closest_unit_distance:
			closest_unit_distance = distance
			closest_unit = hurtbox

	# Prefer a unit for the single-target slot; flag always gets hit if present.
	if closest_unit != null:
		_apply_hit(closest_unit)
	for hurtbox in flag_hurtboxes:
		_apply_hit(hurtbox)


func _apply_hit_to_area(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if _get_valid_target(hurtbox) == null:
		return
	_apply_hit(hurtbox)


func _apply_hit(hurtbox: HurtboxComponent) -> void:
	var target := hurtbox.get_combatant()
	if target == null or _hit_combatants.has(target):
		return
	_hit_combatants[target] = true
	var from_pos := owner_unit.global_position if owner_unit != null else global_position
	hurtbox.receive_hit(damage, from_pos, knockback_force, owner_unit)


func _get_valid_target(hurtbox: HurtboxComponent) -> Node:
	if hurtbox == null or owner_unit == null:
		return null

	var target: Node = hurtbox.get_combatant()
	if target == null or target == owner_unit:
		return null
	if _is_ally(target):
		return null
	if _hit_combatants.has(target):
		return null
	return target


func _is_ally(target: Node) -> bool:
	var owner_troop: Troop = owner_unit._troop
	var target_troop := _get_troop(target)
	if owner_troop == null or target_troop == null:
		return true
	return owner_troop.is_enemy == target_troop.is_enemy


func _get_troop(target: Node) -> Troop:
	if target is Unit:
		return (target as Unit)._troop
	if target is FlagBearer:
		return (target as FlagBearer).get_parent() as Troop
	return null
