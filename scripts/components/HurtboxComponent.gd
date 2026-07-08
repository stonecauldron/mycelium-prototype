class_name HurtboxComponent
extends Area2D


func get_unit() -> Unit:
	return get_parent() as Unit


func receive_hit(damage: int, from_global: Vector2 = Vector2.ZERO) -> void:
	var unit := get_unit()
	if unit:
		unit.take_damage(damage, from_global)
