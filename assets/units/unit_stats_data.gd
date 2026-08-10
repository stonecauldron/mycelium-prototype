class_name UnitStatsData
extends Resource

## FEEBLE is appended so existing spore/resource tier ints stay stable.
enum PowerTier { WEAK, COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, FEEBLE }

const NEUTRAL_STAT := 5
const NEW_UNIT_MIN := 3
const NEW_UNIT_MAX := 7

const TIER_RANGES := {
	PowerTier.FEEBLE: Vector2i(1, 2),
	PowerTier.WEAK: Vector2i(2, 4),
	PowerTier.COMMON: Vector2i(4, 6),
	PowerTier.UNCOMMON: Vector2i(6, 8),
	PowerTier.RARE: Vector2i(8, 10),
	PowerTier.EPIC: Vector2i(10, 12),
	PowerTier.LEGENDARY: Vector2i(12, 14),
}

const TIER_TINTS := {
	PowerTier.FEEBLE: Color(0.72, 0.72, 0.76, 1.0),
	PowerTier.WEAK: Color(0.82, 0.82, 0.86, 1.0),
	PowerTier.COMMON: Color.WHITE,
	PowerTier.UNCOMMON: Color(0.78, 0.92, 0.8, 1.0),
	PowerTier.RARE: Color(0.78, 0.84, 0.95, 1.0),
	PowerTier.EPIC: Color(0.88, 0.78, 0.95, 1.0),
	PowerTier.LEGENDARY: Color(0.95, 0.9, 0.78, 1.0),
}

const TIER_LABELS := {
	PowerTier.FEEBLE: "Feeble",
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


## Prestige ladder for generation chips — not the unit's actual power_tier.
static func tier_for_generation(generation: int) -> PowerTier:
	match clampi(generation, 1, 5):
		1:
			return PowerTier.COMMON
		2:
			return PowerTier.UNCOMMON
		3:
			return PowerTier.RARE
		4:
			return PowerTier.EPIC
		_:
			return PowerTier.LEGENDARY


static func tint_for_generation(generation: int) -> Color:
	return tint_for_tier(tier_for_generation(generation))


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


## Midpoint of the tier roll range (UI / expected hatch average before variance).
static func average_for_tier(tier: PowerTier) -> UnitStatsData:
	var stat_range: Vector2i = TIER_RANGES.get(tier, TIER_RANGES[PowerTier.COMMON])
	var mid := int(round((float(stat_range.x) + float(stat_range.y)) * 0.5))
	var stats := UnitStatsData.new()
	stats.strength = mid
	stats.dex = mid
	stats.con = mid
	stats.spd = mid
	return stats


## Roll each stat independently around `mean` by ±`variance` (clamped 1–99).
static func create_around(
	mean: UnitStatsData,
	variance: int = 1,
	rng: RandomNumberGenerator = null
) -> UnitStatsData:
	var generator := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		generator.randomize()
	var stats := UnitStatsData.new()
	var base_str := NEUTRAL_STAT
	var base_dex := NEUTRAL_STAT
	var base_con := NEUTRAL_STAT
	var base_spd := NEUTRAL_STAT
	if mean != null:
		base_str = mean.strength
		base_dex = mean.dex
		base_con = mean.con
		base_spd = mean.spd
	var v := maxi(variance, 0)
	stats.strength = clampi(base_str + generator.randi_range(-v, v), 1, 99)
	stats.dex = clampi(base_dex + generator.randi_range(-v, v), 1, 99)
	stats.con = clampi(base_con + generator.randi_range(-v, v), 1, 99)
	stats.spd = clampi(base_spd + generator.randi_range(-v, v), 1, 99)
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
