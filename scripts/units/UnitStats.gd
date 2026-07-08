class_name UnitStats
extends Resource

enum WeaponRange { MELEE, MID, RANGED }

const NEUTRAL_STAT := 5
const NEW_UNIT_MIN := 3
const NEW_UNIT_MAX := 7

@export_range(1, 99, 1) var str: int = NEUTRAL_STAT
@export_range(1, 99, 1) var dex: int = NEUTRAL_STAT
@export_range(1, 99, 1) var con: int = NEUTRAL_STAT
@export_range(1, 99, 1) var spd: int = NEUTRAL_STAT


static func create_random(rng: RandomNumberGenerator = null) -> UnitStats:
	var generator := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		generator.randomize()

	var stats := UnitStats.new()
	stats.str = generator.randi_range(NEW_UNIT_MIN, NEW_UNIT_MAX)
	stats.dex = generator.randi_range(NEW_UNIT_MIN, NEW_UNIT_MAX)
	stats.con = generator.randi_range(NEW_UNIT_MIN, NEW_UNIT_MAX)
	stats.spd = generator.randi_range(NEW_UNIT_MIN, NEW_UNIT_MAX)
	return stats


func get_max_hp() -> int:
	return maxi(con * 4, 1)


func get_attack_stat(weapon_range: WeaponRange) -> int:
	match weapon_range:
		WeaponRange.MELEE:
			return str
		WeaponRange.RANGED:
			return dex
		WeaponRange.MID:
			return maxi(str, dex)
		_:
			return NEUTRAL_STAT


func get_speed_multiplier() -> float:
	return spd / float(NEUTRAL_STAT)


func get_melee_damage_bonus() -> int:
	return str - NEUTRAL_STAT


func get_ranged_damage_bonus() -> int:
	return (dex - NEUTRAL_STAT) / 2


func get_mid_damage_bonus() -> int:
	return get_attack_stat(WeaponRange.MID) - NEUTRAL_STAT


func get_damage_bonus(weapon_range: WeaponRange) -> int:
	match weapon_range:
		WeaponRange.MELEE:
			return get_melee_damage_bonus()
		WeaponRange.RANGED:
			return get_ranged_damage_bonus()
		WeaponRange.MID:
			return get_mid_damage_bonus()
		_:
			return 0
