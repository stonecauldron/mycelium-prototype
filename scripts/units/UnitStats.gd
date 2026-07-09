class_name UnitStats
extends Resource

enum PowerTier { WEAK, AVERAGE, STRONG }

const NEUTRAL_STAT := 5
const NEW_UNIT_MIN := 3
const NEW_UNIT_MAX := 7

const TIER_RANGES := {
	PowerTier.WEAK: Vector2i(2, 4),
	PowerTier.AVERAGE: Vector2i(4, 6),
	PowerTier.STRONG: Vector2i(6, 8),
}

@export_range(1, 99, 1) var str: int = NEUTRAL_STAT
@export_range(1, 99, 1) var dex: int = NEUTRAL_STAT
@export_range(1, 99, 1) var con: int = NEUTRAL_STAT
@export_range(1, 99, 1) var spd: int = NEUTRAL_STAT


static func create_random(rng: RandomNumberGenerator = null) -> UnitStats:
	return create_for_tier(PowerTier.AVERAGE, rng)


static func create_for_tier(tier: PowerTier, rng: RandomNumberGenerator = null) -> UnitStats:
	var generator := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		generator.randomize()

	var stat_range: Vector2i = TIER_RANGES.get(tier, TIER_RANGES[PowerTier.AVERAGE])
	var stats := UnitStats.new()
	stats.str = generator.randi_range(stat_range.x, stat_range.y)
	stats.dex = generator.randi_range(stat_range.x, stat_range.y)
	stats.con = generator.randi_range(stat_range.x, stat_range.y)
	stats.spd = generator.randi_range(stat_range.x, stat_range.y)
	return stats


func get_max_hp() -> int:
	return maxi(con * 4, 1)


func get_attack_stat(weapon_range: WeaponData.WeaponRange) -> int:
	match weapon_range:
		WeaponData.WeaponRange.MELEE:
			return str
		WeaponData.WeaponRange.RANGED:
			return dex
		WeaponData.WeaponRange.MID:
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
	return get_attack_stat(WeaponData.WeaponRange.MID) - NEUTRAL_STAT


func get_damage_bonus(weapon_range: WeaponData.WeaponRange) -> int:
	match weapon_range:
		WeaponData.WeaponRange.MELEE:
			return get_melee_damage_bonus()
		WeaponData.WeaponRange.RANGED:
			return get_ranged_damage_bonus()
		WeaponData.WeaponRange.MID:
			return get_mid_damage_bonus()
		_:
			return 0
