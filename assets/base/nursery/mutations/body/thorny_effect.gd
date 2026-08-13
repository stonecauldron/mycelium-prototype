class_name ThornyBodyEffect
extends MutationEffect


func on_hit_taken(
	unit: Node,
	_amount: int,
	_damage_type: int,
	attacker: Node = null,
	is_melee: bool = false
) -> void:
	if not is_melee:
		return
	var self_unit := unit as Unit
	var foe := attacker as Unit
	if self_unit == null or foe == null or not is_instance_valid(foe):
		return
	if foe == self_unit or foe._dying:
		return
	# Enemies only — skip friendly-fire / same-troop melee.
	if self_unit._troop != null and foe._troop != null:
		if self_unit._troop.is_enemy == foe._troop.is_enemy:
			return
	var strength := 1
	if self_unit.stats != null:
		strength = self_unit.stats.strength
	var thorns := maxi(1, floori(strength / 2.0))
	# Not an attack: ignore bearer's outgoing mods; target resists still apply via take_damage.
	# is_melee=false so thorns never chain into more thorns.
	foe.take_damage(
		thorns,
		self_unit.global_position,
		0.0,
		self_unit,
		WeaponData.DamageType.SLASHING,
		true,
		false
	)
