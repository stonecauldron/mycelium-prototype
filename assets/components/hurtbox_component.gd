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
	knockback_force: float = 0.0,
	killer: Node = null,
	damage_type: WeaponData.DamageType = WeaponData.DamageType.SLASHING,
	is_melee: bool = false,
	impact_cue: int = -1
) -> void:
	# Only direct weapon contacts carry an authored impact; status damage keeps its cue.
	if is_melee and is_instance_valid(killer):
		var profile: CombatProfile = killer.get("combat") as CombatProfile
		if profile != null:
			impact_cue = profile.get_impact_sfx()
	var combatant := get_combatant()
	if combatant != null and combatant.has_method("take_damage"):
		combatant.take_damage(
			damage, from_global, knockback_force, killer, damage_type, true, is_melee, impact_cue
		)
