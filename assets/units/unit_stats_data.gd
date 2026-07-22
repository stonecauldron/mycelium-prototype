class_name UnitStatsData
extends Resource

enum PowerTier { WEAK, COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const NEUTRAL_STAT := 5
const NEW_UNIT_MIN := 3
const NEW_UNIT_MAX := 7

const TIER_RANGES := {
	PowerTier.WEAK: Vector2i(2, 4),
	PowerTier.COMMON: Vector2i(4, 6),
	PowerTier.UNCOMMON: Vector2i(6, 8),
	PowerTier.RARE: Vector2i(8, 10),
	PowerTier.EPIC: Vector2i(10, 12),
	PowerTier.LEGENDARY: Vector2i(12, 14),
}

@export_range(1, 99, 1) var strength: int = NEUTRAL_STAT
@export_range(1, 99, 1) var dex: int = NEUTRAL_STAT
@export_range(1, 99, 1) var con: int = NEUTRAL_STAT
@export_range(1, 99, 1) var spd: int = NEUTRAL_STAT


static func create_random(rng: RandomNumberGenerator = null) -> UnitStatsData:
	return create_for_tier(PowerTier.COMMON, rng)


static func create_for_tier(tier: PowerTier, rng: RandomNumberGenerator = null) -> UnitStatsData:
	var generator := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		generator.randomize()

	var stat_range: Vector2i = TIER_RANGES.get(tier, TIER_RANGES[PowerTier.COMMON])
	var stats := UnitStatsData.new()
	stats.strength = generator.randi_range(stat_range.x, stat_range.y)
	stats.dex = generator.randi_range(stat_range.x, stat_range.y)
	stats.con = generator.randi_range(stat_range.x, stat_range.y)
	stats.spd = generator.randi_range(stat_range.x, stat_range.y)
	return stats


func get_max_hp() -> int:
	return maxi(con * 4, 1)


func get_attack_stat(attack_style: WeaponData.AttackStyle) -> int:
	match attack_style:
		WeaponData.AttackStyle.MELEE_LUNGE:
			return strength
		WeaponData.AttackStyle.BOW_SHOT:
			return dex
		WeaponData.AttackStyle.SPEAR_THROW:
			return maxi(strength, dex)
		_:
			return NEUTRAL_STAT


func get_speed_multiplier() -> float:
	return spd / float(NEUTRAL_STAT)


func get_melee_damage_bonus() -> int:
	return strength - NEUTRAL_STAT


func get_ranged_damage_bonus() -> int:
	return roundi((dex - NEUTRAL_STAT) / 2.0)


func get_mid_damage_bonus() -> int:
	return get_attack_stat(WeaponData.AttackStyle.SPEAR_THROW) - NEUTRAL_STAT


func get_damage_bonus(attack_style: WeaponData.AttackStyle) -> int:
	match attack_style:
		WeaponData.AttackStyle.MELEE_LUNGE:
			return get_melee_damage_bonus()
		WeaponData.AttackStyle.BOW_SHOT:
			return get_ranged_damage_bonus()
		WeaponData.AttackStyle.SPEAR_THROW:
			return get_mid_damage_bonus()
		_:
			return 0
