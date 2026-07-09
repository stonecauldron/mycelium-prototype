class_name HitboxComponent
extends Area2D

@export var damage: int = 0
@export var knockback_force: float = 0.0
@export var owner_unit: Unit

var _hit_combatants: Dictionary = {}


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	monitoring = false


func enable_for_attack(attack_damage: int, attack_knockback: float) -> void:
	damage = attack_damage
	knockback_force = attack_knockback
	_hit_combatants.clear()
	monitoring = true
	_hit_overlapping_hurtboxes()


func disable() -> void:
	monitoring = false
	_hit_combatants.clear()


func _hit_overlapping_hurtboxes() -> void:
	for area in get_overlapping_areas():
		_try_hit(area)


func _on_area_entered(area: Area2D) -> void:
	if not monitoring:
		return
	_try_hit(area)


func _try_hit(area: Area2D) -> void:
	var hurtbox: HurtboxComponent = area as HurtboxComponent
	if hurtbox == null or owner_unit == null:
		return

	var target: Node = hurtbox.get_combatant()
	if target == null or target == owner_unit:
		return
	if _is_ally(target):
		return
	if _hit_combatants.has(target):
		return

	_hit_combatants[target] = true
	hurtbox.receive_hit(damage, owner_unit.global_position, knockback_force)


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
