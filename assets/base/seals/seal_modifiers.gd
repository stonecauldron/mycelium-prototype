class_name SealModifiers
extends RefCounted

## Pure seal effect queries. All player-side; enemies ignore these.


static func _seals() -> SealsCollection:
	return GameState.seals


static func count(seal_id: StringName) -> int:
	var collection := _seals()
	if collection == null:
		return 0
	return collection.count(seal_id)


static func spore_shop_cost(base_cost: int) -> int:
	var n := count(SealCatalog.ID_ROTTEN_THUMB)
	if n <= 0:
		return base_cost
	return maxi(1, base_cost - 2 * n)


static func max_fertilizer_stacks() -> int:
	return 1 + count(SealCatalog.ID_FERTILIZER_SPREADER)


static func greenhouse_day_reduction() -> int:
	return count(SealCatalog.ID_GREENHOUSE)


static func wooden_heart_flat_hp() -> int:
	return 8 * count(SealCatalog.ID_WOODEN_HEART)


static func wooden_melee_flat_damage() -> int:
	return 2 * count(SealCatalog.ID_WOODEN_SWORD)


static func wooden_ranged_flat_damage() -> int:
	return 2 * count(SealCatalog.ID_WOODEN_BOW)


static func golden_mould_biomass() -> int:
	return 6 * count(SealCatalog.ID_GOLDEN_MOULD)


static func favourite_child_owned() -> bool:
	return count(SealCatalog.ID_FAVOURITE_CHILD) > 0


## ATK/HP multipliers for a roster unit (favourite / neotonia / commoners / bulwark|ranger).
static func unit_atk_multiplier(unit: RosterUnitData, troop: TroopData = null) -> float:
	if unit == null:
		return 1.0
	var mult := 1.0
	if unit.favourite_child_buff:
		mult *= 1.5
	if unit.life_stage_id == UnitStrain.STAGE_JUVENILE:
		mult *= _pow_count(1.5, count(SealCatalog.ID_NEOTONIA))
	if unit.weapon_trainings.is_empty():
		mult *= _pow_count(2.0, count(SealCatalog.ID_COMMONERS_DELIGHT))
	var squad := troop if troop != null else GameState.troop
	if squad != null and squad.is_rearmost_squad_unit(unit):
		mult *= _pow_count(2.0, count(SealCatalog.ID_RANGER))
	return mult


static func unit_hp_multiplier(unit: RosterUnitData, troop: TroopData = null) -> float:
	if unit == null:
		return 1.0
	var mult := 1.0
	if unit.favourite_child_buff:
		mult *= 1.5
	if unit.life_stage_id == UnitStrain.STAGE_JUVENILE:
		mult *= _pow_count(1.5, count(SealCatalog.ID_NEOTONIA))
	if unit.weapon_trainings.is_empty():
		mult *= _pow_count(2.0, count(SealCatalog.ID_COMMONERS_DELIGHT))
	var squad := troop if troop != null else GameState.troop
	if squad != null and squad.is_frontmost_squad_unit(unit):
		mult *= _pow_count(2.0, count(SealCatalog.ID_BULWARK))
	return mult


static func effective_max_hp(unit: RosterUnitData, troop: TroopData = null) -> int:
	if unit == null or unit.stats == null:
		return 0
	var base_hp := unit.stats.get_max_hp() + wooden_heart_flat_hp()
	return maxi(roundi(float(base_hp) * unit_hp_multiplier(unit, troop)), 1)


## Display / non-combat ATK estimate (weapon style from profile; hybrid uses projectile if any).
static func effective_attack_damage(unit: RosterUnitData, troop: TroopData = null) -> int:
	if unit == null or unit.stats == null:
		return 0
	var combat := unit.ensure_combat_profile()
	var raw: int = combat.base_damage + unit.stats.get_damage_bonus(combat.damage_stat)
	if combat.uses_projectile():
		raw += wooden_ranged_flat_damage()
	else:
		raw += wooden_melee_flat_damage()
	var mult := combat.outgoing_damage_multiplier * unit_atk_multiplier(unit, troop)
	return maxi(roundi(float(raw) * mult), 1)


static func combat_attack_damage(
	unit: Unit,
	raw_base: int,
	weapon_outgoing_mult: float,
	is_projectile_attack: bool
) -> int:
	if unit == null:
		return maxi(roundi(float(raw_base) * weapon_outgoing_mult), 1)
	var raw := raw_base
	var atk_mult := 1.0
	if unit.is_player_controlled():
		if is_projectile_attack:
			raw += wooden_ranged_flat_damage()
		else:
			raw += wooden_melee_flat_damage()
		var roster := unit.roster_data
		if roster != null:
			atk_mult = unit_atk_multiplier(roster)
	return maxi(roundi(float(raw) * weapon_outgoing_mult * atk_mult), 1)


static func _pow_count(factor: float, n: int) -> float:
	if n <= 0:
		return 1.0
	return pow(factor, n)
