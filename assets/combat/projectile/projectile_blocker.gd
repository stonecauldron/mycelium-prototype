class_name ProjectileBlocker
extends Area2D

## Mounted on weapon appearances (e.g. umbrella canopy). Destroys opposing projectiles.


func blocks_projectile_from(shooter_troop: Node) -> bool:
	var owner_troop := _get_owner_troop()
	if owner_troop == null or shooter_troop == null:
		return false
	return bool(owner_troop.get("is_enemy")) != bool(shooter_troop.get("is_enemy"))


func _get_owner_troop() -> Node:
	var unit := _get_owner_unit()
	if unit == null:
		return null
	return unit.get("_troop")


func _get_owner_unit() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node.is_in_group("units"):
			return node
		node = node.get_parent()
	return null
