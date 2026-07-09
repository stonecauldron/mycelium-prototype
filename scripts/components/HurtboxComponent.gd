class_name HurtboxComponent
extends Area2D


func get_combatant() -> Node:
	return get_parent()


func receive_hit(damage: int, from_global: Vector2 = Vector2.ZERO) -> void:
	var combatant := get_combatant()
	if combatant != null and combatant.has_method("take_damage"):
		combatant.take_damage(damage, from_global)
