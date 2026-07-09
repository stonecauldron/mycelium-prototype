class_name HitboxComponent
extends Area2D

@export var damage: int = 0
@export var knockback_force: float = 0.0
@export var owner_unit: Unit

var _targeting_mode: WeaponData.TargetingMode = WeaponData.TargetingMode.SINGLE
var _hit_combatants: Dictionary = {}


func _ready() -> void:
	area_entered.connect(_on_area_entered)
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
	_resolve_hits()


func disable() -> void:
	monitoring = false
	_hit_combatants.clear()


func _on_area_entered(_area: Area2D) -> void:
	if not monitoring:
		return
	_resolve_hits()


func _resolve_hits() -> void:
	if _targeting_mode == WeaponData.TargetingMode.AOE:
		for area in get_overlapping_areas():
			_apply_hit_to_area(area)
		return

	_hit_closest_enemy()


func _hit_closest_enemy() -> void:
	if not _hit_combatants.is_empty():
		return

	var closest_hurtbox: HurtboxComponent = null
	var closest_distance := INF

	for area in get_overlapping_areas():
		var hurtbox: HurtboxComponent = area as HurtboxComponent
		var target := _get_valid_target(hurtbox)
		if target == null:
			continue
		var distance := owner_unit.global_position.distance_squared_to(
			(target as Node2D).global_position
		)
		if distance < closest_distance:
			closest_distance = distance
			closest_hurtbox = hurtbox

	if closest_hurtbox != null:
		_apply_hit(closest_hurtbox)


func _apply_hit_to_area(area: Area2D) -> void:
	var hurtbox: HurtboxComponent = area as HurtboxComponent
	var target := _get_valid_target(hurtbox)
	if target == null:
		return
	_apply_hit(hurtbox)


func _apply_hit(hurtbox: HurtboxComponent) -> void:
	var target := hurtbox.get_combatant()
	if target == null or _hit_combatants.has(target):
		return
	_hit_combatants[target] = true
	hurtbox.receive_hit(damage, owner_unit.global_position, knockback_force)


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
	var owner_army: Army = owner_unit._army
	var target_army := _get_army(target)
	if owner_army == null or target_army == null:
		return true
	return owner_army.is_enemy == target_army.is_enemy


func _get_army(target: Node) -> Army:
	if target is Unit:
		return (target as Unit)._army
	if target is FlagBearer:
		return (target as FlagBearer).get_parent() as Army
	return null
