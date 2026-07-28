class_name BoomCapEffect
extends StrainEffect

const _EXPLOSION_SCENE := preload("res://assets/combat/boom_cap_explosion/boom_cap_explosion.tscn")
const RADIUS := 100.0
const KNOCKBACK := 420.0


func on_death(_roster: Resource, context: DeathContext, combat_unit: Node = null) -> void:
	if context != DeathContext.COMBAT:
		return
	var unit := combat_unit as Unit
	if unit == null or not is_instance_valid(unit):
		return
	var world := unit.get_parent()
	if world == null:
		return
	# Prefer combat World root (Units -> Troop -> World).
	var spawn_parent: Node = world
	while spawn_parent != null and not spawn_parent.is_in_group("combat_world"):
		spawn_parent = spawn_parent.get_parent()
	if spawn_parent == null:
		spawn_parent = world.get_parent()
		if spawn_parent == null:
			spawn_parent = world
	var explosion: Node2D = _EXPLOSION_SCENE.instantiate()
	spawn_parent.add_child(explosion)
	explosion.global_position = unit.global_position
	var str_stat := 5
	if unit.stats != null:
		str_stat = unit.stats.strength
	if explosion.has_method("trigger"):
		explosion.call("trigger", str_stat, RADIUS, KNOCKBACK, unit)
