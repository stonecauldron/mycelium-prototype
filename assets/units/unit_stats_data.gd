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

const TIER_TINTS := {
	PowerTier.WEAK: Color(0.82, 0.82, 0.86, 1.0),
	PowerTier.COMMON: Color.WHITE,
	PowerTier.UNCOMMON: Color(0.78, 0.92, 0.8, 1.0),
	PowerTier.RARE: Color(0.78, 0.84, 0.95, 1.0),
	PowerTier.EPIC: Color(0.88, 0.78, 0.95, 1.0),
	PowerTier.LEGENDARY: Color(0.95, 0.9, 0.78, 1.0),
}

const TIER_LABELS := {
	PowerTier.WEAK: "Weak",
	PowerTier.COMMON: "Common",
	PowerTier.UNCOMMON: "Uncommon",
	PowerTier.RARE: "Rare",
	PowerTier.EPIC: "Epic",
	PowerTier.LEGENDARY: "Legendary",
}

@export_range(1, 99, 1) var strength: int = NEUTRAL_STAT
@export_range(1, 99, 1) var dex: int = NEUTRAL_STAT
@export_range(1, 99, 1) var con: int = NEUTRAL_STAT
@export_range(1, 99, 1) var spd: int = NEUTRAL_STAT


static func tint_for_tier(tier: PowerTier) -> Color:
	return TIER_TINTS.get(tier, TIER_TINTS[PowerTier.COMMON])


static func label_for_tier(tier: PowerTier) -> String:
	return TIER_LABELS.get(tier, TIER_LABELS[PowerTier.COMMON])


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


func get_attack_stat(damage_stat: WeaponData.DamageStat) -> int:
	match damage_stat:
		WeaponData.DamageStat.STRENGTH:
			return strength
		WeaponData.DamageStat.DEX:
			return dex
		WeaponData.DamageStat.FINESSE:
			return maxi(strength, dex)
		_:
			return NEUTRAL_STAT


func get_speed_multiplier() -> float:
	return spd / float(NEUTRAL_STAT)


func get_damage_bonus(damage_stat: WeaponData.DamageStat) -> int:
	match damage_stat:
		WeaponData.DamageStat.STRENGTH:
			return strength - NEUTRAL_STAT
		WeaponData.DamageStat.DEX:
			# Half weight vs STR so dex weapons don't spike as hard per point.
			return roundi((dex - NEUTRAL_STAT) / 2.0)
		WeaponData.DamageStat.FINESSE:
			return get_attack_stat(damage_stat) - NEUTRAL_STAT
		_:
			return 0
