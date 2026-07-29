class_name EnemyComposer
extends RefCounted

## Day-curve procedural enemy specs + optional multi-variant skill-check overrides.

enum ArmyArchetype { ONE_TRICK_PONY, HYBRID, GENERALIST }

const _REROLL_CANDIDATE_COUNT := 8
const _MIDPOINT_SAMPLE_COUNT := 8

const _WEAPON_POOL: Array[EnemyUnitSpec.UnitType] = [
	EnemyUnitSpec.UnitType.MELEE,
	EnemyUnitSpec.UnitType.SPEAR,
	EnemyUnitSpec.UnitType.BOW,
	EnemyUnitSpec.UnitType.SHIELD,
]

const _GENERALIST_STRAIN_PATH := "res://assets/units/generalist/generalist_strain.tres"
## Relative weight when picking strains for army mix (other strains = 1).
const _GENERALIST_STRAIN_WEIGHT := 3.0
const _STRAIN_PATHS: Array[String] = [
	_GENERALIST_STRAIN_PATH,
	"res://assets/units/death_cap/death_cap_strain.tres",
	"res://assets/units/inky_cap/inky_cap_strain.tres",
	"res://assets/units/boom_cap/boom_cap_strain.tres",
	"res://assets/units/mini_cap/mini_cap_strain.tres",
	"res://assets/units/lanky_cap/lanky_cap_strain.tres",
	"res://assets/units/fat_cap/fat_cap_strain.tres",
	"res://assets/units/magi_cap/magi_cap_strain.tres",
	"res://assets/units/chad_cap/chad_cap_strain.tres",
	"res://assets/units/rush_cap/rush_cap_strain.tres",
	"res://assets/units/wall_cap/wall_cap_strain.tres",
	"res://assets/units/zombie_cap/zombie_cap_strain.tres",
	"res://assets/units/rubber_cap/rubber_cap_strain.tres",
]

## Excluded from procedural enemies on days 1–3.
const _EARLY_DAY_EXCLUDED_STRAIN_PATHS: Array[String] = [
	"res://assets/units/magi_cap/magi_cap_strain.tres",
	"res://assets/units/chad_cap/chad_cap_strain.tres",
]
const _EARLY_DAY_STRAIN_LOCKOUT := 3

const _ARCHETYPE_SHARES := {
	ArmyArchetype.ONE_TRICK_PONY: [0.9, 0.1],
	ArmyArchetype.HYBRID: [0.7, 0.3],
	ArmyArchetype.GENERALIST: [0.33, 0.33, 0.34],
}

static var _cached_strain_pool: Array = []


static func specs_for_day(day: int) -> Array[EnemyUnitSpec]:
	var clamped := clampi(day, 1, GameState.WIN_DAYS)
	var rng := _rng_for_day(clamped)
	var variants := _skill_check_variants(clamped)
	if not variants.is_empty():
		var pick := rng.randi() % variants.size()
		return variants[pick]
	return _generate_from_curve(clamped, rng)


static func difficulty_score(specs: Array[EnemyUnitSpec]) -> float:
	var score := 0.0
	for spec in specs:
		match spec.tier:
			UnitStatsData.PowerTier.WEAK:
				score += 1.0
			UnitStatsData.PowerTier.COMMON:
				score += 2.0
			UnitStatsData.PowerTier.UNCOMMON:
				score += 3.0
		if spec.is_imago:
			score += 1.0
	return score


static func reroll_for_day(day: int, current_specs: Array[EnemyUnitSpec]) -> Array[EnemyUnitSpec]:
	var clamped := clampi(day, 1, GameState.WIN_DAYS)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var candidates := _reroll_candidates(clamped, current_specs, rng)
	if candidates.is_empty():
		return current_specs
	var current_score := difficulty_score(current_specs)
	var midpoint := _midpoint_for_day(clamped)
	var total_weight := 0.0
	var weights: Array[float] = []
	for candidate in candidates:
		var score := difficulty_score(candidate)
		var weight: float
		if current_score >= midpoint:
			weight = maxf(0.05, current_score - score)
		else:
			weight = maxf(0.05, score - current_score)
		weights.append(weight)
		total_weight += weight
	var roll := rng.randf() * total_weight
	var acc := 0.0
	for i in candidates.size():
		acc += weights[i]
		if roll <= acc:
			return candidates[i]
	return candidates[candidates.size() - 1]


static func _midpoint_for_day(day: int) -> float:
	var scores: Array[float] = []
	var variants := _skill_check_variants(day)
	if not variants.is_empty():
		for variant in variants:
			scores.append(difficulty_score(variant))
	else:
		for i in _MIDPOINT_SAMPLE_COUNT:
			var sample_rng := RandomNumberGenerator.new()
			sample_rng.seed = hash([GameState.run_seed, day, &"midpoint", i])
			scores.append(difficulty_score(_generate_from_curve(day, sample_rng)))
	if scores.is_empty():
		return 0.0
	var sum := 0.0
	for score in scores:
		sum += score
	return sum / float(scores.size())


static func _reroll_candidates(
	day: int,
	current_specs: Array[EnemyUnitSpec],
	rng: RandomNumberGenerator
) -> Array:
	var candidates: Array = []
	var variants := _skill_check_variants(day)
	if not variants.is_empty():
		for variant in variants:
			var specs: Array[EnemyUnitSpec] = variant
			if not _specs_equal(specs, current_specs):
				candidates.append(specs)
		if candidates.is_empty():
			for variant in variants:
				candidates.append(variant)
		return candidates
	for _i in _REROLL_CANDIDATE_COUNT:
		var sample_rng := RandomNumberGenerator.new()
		sample_rng.seed = rng.randi()
		candidates.append(_generate_from_curve(day, sample_rng))
	return candidates


static func _specs_equal(a: Array[EnemyUnitSpec], b: Array[EnemyUnitSpec]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if (
			a[i].type != b[i].type
			or a[i].tier != b[i].tier
			or a[i].is_imago != b[i].is_imago
			or a[i].strain != b[i].strain
		):
			return false
	return true


static func _rng_for_day(day: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([GameState.run_seed, day])
	return rng


static func _skill_check_variants(_day: int) -> Array:
	## Each entry is Array[EnemyUnitSpec]. Empty → use day curve.
	## Hook for future authored turn overrides.
	return []


static func _generate_from_curve(day: int, rng: RandomNumberGenerator) -> Array[EnemyUnitSpec]:
	var band := _band_for_day(day)
	var total: int = rng.randi_range(band.min_units, band.max_units)
	var tier_weights: Array = band.tier_weights
	var imago_chance: float = band.imago_chance

	var weapon_archetype: ArmyArchetype = (rng.randi() % 3) as ArmyArchetype
	var strain_archetype: ArmyArchetype = (rng.randi() % 3) as ArmyArchetype
	var weapon_slots := _distribute_mix(_WEAPON_POOL, weapon_archetype, total, rng)
	var strain_slots := _distribute_mix(
		_strain_pool_for_day(day),
		strain_archetype,
		total,
		rng,
		_strain_pick_weight
	)

	var specs: Array[EnemyUnitSpec] = []
	for i in total:
		var unit_type: EnemyUnitSpec.UnitType = weapon_slots[i]
		var unit_strain: UnitStrain = strain_slots[i]
		var tier: UnitStatsData.PowerTier = _pick_weighted_tier(tier_weights, rng)
		var imago := imago_chance > 0.0 and rng.randf() < imago_chance
		specs.append(EnemyUnitSpec.make(unit_type, tier, imago, unit_strain))
	return specs


static func _strain_pool() -> Array:
	if not _cached_strain_pool.is_empty():
		return _cached_strain_pool
	var pool: Array = []
	for path in _STRAIN_PATHS:
		var strain := load(path) as UnitStrain
		if strain != null:
			pool.append(strain)
	_cached_strain_pool = pool
	return _cached_strain_pool


static func _strain_pool_for_day(day: int) -> Array:
	var pool := _strain_pool()
	if day > _EARLY_DAY_STRAIN_LOCKOUT:
		return pool
	var filtered: Array = []
	for strain in pool:
		var unit_strain := strain as UnitStrain
		if unit_strain == null:
			continue
		if _EARLY_DAY_EXCLUDED_STRAIN_PATHS.has(unit_strain.resource_path):
			continue
		filtered.append(unit_strain)
	return filtered


static func _distribute_mix(
	pool: Array,
	archetype: ArmyArchetype,
	total: int,
	rng: RandomNumberGenerator,
	weight_for_entry: Callable = Callable()
) -> Array:
	var shares: Array = _ARCHETYPE_SHARES[archetype]
	var pick_count: int = mini(shares.size(), pool.size())
	var picked := _pick_distinct(pool, pick_count, rng, weight_for_entry)
	var counts := _shares_to_counts(shares.slice(0, picked.size()), total)
	var slots: Array = []
	for i in picked.size():
		for _j in counts[i]:
			slots.append(picked[i])
	_shuffle_array(slots, rng)
	return slots


static func _strain_pick_weight(entry) -> float:
	var unit_strain := entry as UnitStrain
	if unit_strain != null and unit_strain.resource_path == _GENERALIST_STRAIN_PATH:
		return _GENERALIST_STRAIN_WEIGHT
	return 1.0


static func _pick_distinct(
	pool: Array,
	count: int,
	rng: RandomNumberGenerator,
	weight_for_entry: Callable = Callable()
) -> Array:
	var remaining: Array = pool.duplicate()
	var picked: Array = []
	var n := mini(count, remaining.size())
	for _i in n:
		var index := _weighted_index(remaining, rng, weight_for_entry)
		picked.append(remaining[index])
		remaining.remove_at(index)
	return picked


static func _weighted_index(
	pool: Array,
	rng: RandomNumberGenerator,
	weight_for_entry: Callable
) -> int:
	if pool.is_empty():
		return 0
	if not weight_for_entry.is_valid():
		return rng.randi() % pool.size()
	var total_weight := 0.0
	var weights: Array[float] = []
	for entry in pool:
		var weight: float = maxf(float(weight_for_entry.call(entry)), 0.0)
		weights.append(weight)
		total_weight += weight
	if total_weight <= 0.0:
		return rng.randi() % pool.size()
	var roll := rng.randf() * total_weight
	var acc := 0.0
	for i in weights.size():
		acc += weights[i]
		if roll <= acc:
			return i
	return weights.size() - 1


static func _shares_to_counts(shares: Array, total: int) -> Array[int]:
	var counts: Array[int] = []
	if shares.is_empty() or total <= 0:
		return counts
	var raw: Array[float] = []
	var floored_sum := 0
	for share in shares:
		var value := float(share) * float(total)
		raw.append(value)
		var floored := int(floor(value))
		counts.append(floored)
		floored_sum += floored
	var remainder := total - floored_sum
	var order: Array[int] = []
	for i in shares.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return (raw[a] - float(counts[a])) > (raw[b] - float(counts[b]))
	)
	for i in remainder:
		counts[order[i % order.size()]] += 1
	# Prefer primary when secondary would be zero on tiny armies — already handled
	# by flooring; if everything landed on primary, that is intentional.
	return counts


static func _shuffle_array(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = values[i]
		values[i] = values[j]
		values[j] = tmp


static func _band_for_day(day: int) -> Dictionary:
	match day:
		1, 2:
			return {
				"min_units": 2,
				"max_units": 3,
				"imago_chance": 0.0,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.WEAK, "weight": 1.0},
				],
			}
		3, 4:
			return {
				"min_units": 3,
				"max_units": 5,
				"imago_chance": 0.4,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.WEAK, "weight": 2.0},
					{"tier": UnitStatsData.PowerTier.COMMON, "weight": 1.0},
				],
			}
		5, 6:
			return {
				"min_units": 4,
				"max_units": 6,
				"imago_chance": 0.5,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.WEAK, "weight": 1.0},
					{"tier": UnitStatsData.PowerTier.COMMON, "weight": 1.0},
				],
			}
		7, 8:
			return {
				"min_units": 5,
				"max_units": 8,
				"imago_chance": 0.6,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.COMMON, "weight": 2.0},
					{"tier": UnitStatsData.PowerTier.UNCOMMON, "weight": 1.0},
				],
			}
		_:
			# Days 9–10.
			return {
				"min_units": 6,
				"max_units": 10,
				"imago_chance": 0.7,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.COMMON, "weight": 1.0},
					{"tier": UnitStatsData.PowerTier.UNCOMMON, "weight": 1.0},
				],
			}


static func _pick_weighted_tier(tier_weights: Array, rng: RandomNumberGenerator) -> UnitStatsData.PowerTier:
	if tier_weights.is_empty():
		return UnitStatsData.PowerTier.WEAK
	var total_weight := 0.0
	for entry in tier_weights:
		total_weight += float(entry["weight"])
	var roll := rng.randf() * total_weight
	var acc := 0.0
	for entry in tier_weights:
		acc += float(entry["weight"])
		if roll <= acc:
			return entry["tier"] as UnitStatsData.PowerTier
	return tier_weights[tier_weights.size() - 1]["tier"] as UnitStatsData.PowerTier
