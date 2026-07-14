class_name HurtboxComponent
extends Area2D


func get_combatant() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("take_damage"):
			return node
		node = node.get_parent()
	return null


func receive_hit(
	damage: int,
	from_global: Vector2 = Vector2.ZERO,
	knockback_force: float = 0.0
) -> void:
	var combatant := get_combatant()
	if combatant != null and combatant.has_method("take_damage"):
		combatant.take_damage(damage, from_global, knockback_force)
