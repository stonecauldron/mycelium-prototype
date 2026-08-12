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


static func _sum_field(property: StringName) -> int:
	var collection := _seals()
	if collection == null:
		return 0
	var total := 0
	var seen: Dictionary = {}
	for seal in collection.all_owned():
		if seal == null or seal.id == &"":
			continue
		if seen.has(seal.id):
			continue
		seen[seal.id] = true
		var n := collection.count(seal.id)
		if n <= 0:
			continue
		total += int(seal.get(property)) * n
	return total


static func _count_flag(property: StringName) -> int:
	var collection := _seals()
	if collection == null:
		return 0
	var total := 0
	for seal in collection.all_owned():
		if seal != null and bool(seal.get(property)):
			total += 1
	return total


static func _apply_cost_halves(base_cost: int, flag_property: StringName) -> int:
	var cost := base_cost
	var halve_count := _count_flag(flag_property)
	for _i in halve_count:
		cost = maxi(1, floori(cost / 2.0))
	return cost


## Biomass cost to plant a fresh Common grow on an empty plot (Rotten Thumb).
static func fresh_plant_cost(base_cost: int = BiomassData.COMMON_SPORE_COST) -> int:
	return _apply_cost_halves(base_cost, &"plant_cost_halve")


## Biomass cost to buy or apply a fertilizer from the shop (Phosphorus Mining).
static func fertilizer_cost(base_cost: int) -> int:
	return _apply_cost_halves(base_cost, &"fertilizer_cost_halve")


## Biomass cost to buy or apply a mutation from the shop (Radioactivity).
static func mutation_cost(base_cost: int) -> int:
	return _apply_cost_halves(base_cost, &"mutation_cost_halve")


static func max_fertilizer_stacks() -> int:
	return 1 + _sum_field(&"fertilizer_stack_bonus")


static func max_mutation_slots() -> int:
	return 1 + _sum_field(&"mutation_slot_bonus")


static func greenhouse_day_reduction() -> int:
	return _sum_field(&"greenhouse_day_reduction")


static func wooden_heart_flat_hp() -> int:
	return _sum_field(&"max_hp_flat")


static func spd_flat() -> int:
	return _sum_field(&"spd_flat")


static func effective_spd(unit: RosterUnitData) -> int:
	if unit == null or unit.stats == null:
		return UnitStatsData.NEUTRAL_STAT
	return clampi(unit.stats.spd + spd_flat(), 1, 99)


static func wooden_melee_flat_damage() -> int:
	return _sum_field(&"melee_damage_flat")


static func wooden_ranged_flat_damage() -> int:
	return _sum_field(&"ranged_damage_flat")


static func golden_mould_biomass() -> int:
	return _sum_field(&"biomass_per_day")


static func favourite_child_owned() -> bool:
	var collection := _seals()
	if collection == null:
		return false
	for seal in collection.all_owned():
		if seal != null and seal.stamps_favourite_child:
			return true
	return false


## ATK/HP multipliers for a roster unit (favourite / neotonia / commoners / bulwark|ranger).
static func unit_atk_multiplier(unit: RosterUnitData, troop: TroopData = null) -> float:
	if unit == null:
		return 1.0
	return _unit_multiplier(unit, troop, true)


static func unit_hp_multiplier(unit: RosterUnitData, troop: TroopData = null) -> float:
	if unit == null:
		return 1.0
	return _unit_multiplier(unit, troop, false)


static func _unit_multiplier(unit: RosterUnitData, troop: TroopData, for_atk: bool) -> float:
	var collection := _seals()
	if collection == null:
		return 1.0
	var mult := 1.0
	var seen: Dictionary = {}
	for seal in collection.all_owned():
		if seal == null or seal.id == &"":
			continue
		if seen.has(seal.id):
			continue
		seen[seal.id] = true
		var matches := _matches_filter(seal, unit, troop, for_atk)
		if not matches:
			continue
		var factor := seal.atk_multiplier if for_atk else seal.hp_multiplier
		if seal.multiplier_filter == SealData.UnitFilter.FAVOURITE_BUFF:
			mult *= factor
		else:
			mult *= _pow_count(factor, collection.count(seal.id))
	return mult


static func _matches_filter(
	seal: SealData,
	unit: RosterUnitData,
	troop: TroopData,
	for_atk: bool
) -> bool:
	if seal == null or unit == null or seal.multiplier_filter == SealData.UnitFilter.NONE:
		return false
	var factor := seal.atk_multiplier if for_atk else seal.hp_multiplier
	if is_equal_approx(factor, 1.0):
		return false
	match seal.multiplier_filter:
		SealData.UnitFilter.JUVENILE:
			return unit.life_stage_id == RosterUnitData.STAGE_JUVENILE
		SealData.UnitFilter.NO_MUTATION:
			return unit.body_mutation == null and unit.cap_mutation == null
		SealData.UnitFilter.FRONTMOST_SQUAD:
			if for_atk:
				return false
			var front_squad := troop if troop != null else GameState.troop
			return front_squad != null and front_squad.is_frontmost_squad_unit(unit)
		SealData.UnitFilter.REARMOST_SQUAD:
			if not for_atk:
				return false
			var rear_squad := troop if troop != null else GameState.troop
			return rear_squad != null and rear_squad.is_rearmost_squad_unit(unit)
		SealData.UnitFilter.FAVOURITE_BUFF:
			return unit.favourite_child_buff
		SealData.UnitFilter.HAS_MUTATION:
			return unit.body_mutation != null or unit.cap_mutation != null
		_:
			return false


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
