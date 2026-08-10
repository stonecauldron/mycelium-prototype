class_name BattleStartContext
extends RefCounted

## Shared context for mutation (and future seal) battle-start effects.
## Kill requests are deferred until after every unit's on_battle_start runs.

var _pending_kills: Array[Dictionary] = []


func living_allies(unit: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if unit == null or unit._troop == null:
		return result
	for ally in unit._troop.get_living_units():
		if ally != null and ally != unit and not ally._dying:
			result.append(ally)
	return result


## Allies in immediately adjacent War Chamber / formation slots (squad_index ± 1).
func adjacent_squad_allies(unit: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	if unit == null or unit._troop == null:
		return result
	var target_indices := [unit.squad_index - 1, unit.squad_index + 1]
	for ally in unit._troop.get_living_units():
		if ally == null or ally == unit or ally._dying:
			continue
		if ally.squad_index in target_indices:
			result.append(ally)
	return result


func queue_kill(victim: Unit, killer: Unit) -> void:
	if victim == null or killer == null:
		return
	if victim._dying or victim.current_hp <= 0:
		return
	for entry in _pending_kills:
		if entry.get("victim") == victim:
			return
	_pending_kills.append({"victim": victim, "killer": killer})


func flush() -> void:
	var queued := _pending_kills.duplicate()
	_pending_kills.clear()
	for entry in queued:
		var victim: Unit = entry.get("victim") as Unit
		var killer: Unit = entry.get("killer") as Unit
		if victim == null or not is_instance_valid(victim):
			continue
		if victim._dying or victim.current_hp <= 0:
			continue
		var lethal := maxi(victim.current_hp, victim.get_effective_max_hp()) + 999
		# Omit from post-battle damage recap (Death Cap sacrifices, etc.).
		victim.take_damage(
			lethal,
			killer.global_position if killer != null else Vector2.ZERO,
			0.0,
			killer,
			WeaponData.DamageType.SLASHING,
			false
		)
