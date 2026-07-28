class_name WallCapEffect
extends StrainEffect

const _WALL_SCENE := preload("res://assets/combat/wall_obstacle/wall_obstacle.tscn")


func on_death(_roster: Resource, context: DeathContext, combat_unit: Node = null) -> void:
	if context != DeathContext.COMBAT:
		return
	var unit := combat_unit as Unit
	if unit == null or not is_instance_valid(unit):
		return
	var world := unit.get_parent()
	if world == null:
		return
	var spawn_parent: Node = world
	while spawn_parent != null and not spawn_parent.is_in_group("combat_world"):
		spawn_parent = spawn_parent.get_parent()
	if spawn_parent == null:
		spawn_parent = world.get_parent()
		if spawn_parent == null:
			spawn_parent = world
	var wall: Node2D = _WALL_SCENE.instantiate()
	spawn_parent.add_child(wall)
	wall.global_position = unit.global_position
	var max_hp := 1
	if unit.stats != null:
		max_hp = unit.stats.get_max_hp()
	if wall.has_method("setup"):
		wall.call("setup", max_hp)
