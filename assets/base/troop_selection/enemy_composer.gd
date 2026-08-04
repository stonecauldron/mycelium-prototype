class_name EnemyComposer
extends RefCounted

## Day-curve procedural enemy specs + optional multi-variant skill-check overrides.

enum ArmyArchetype { ONE_TRICK_PONY, HYBRID, GENERALIST }

const _REROLL_CANDIDATE_COUNT := 8
const _MIDPOINT_SAMPLE_COUNT := 8

const _ENEMY_UNIT_PATHS: Array[String] = [
	"res://assets/units/enemies/grunt/grunt_unit.tres",
	"res://assets/units/enemies/piker/piker_unit.tres",
	"res://assets/units/enemies/archer/archer_unit.tres",
	"res://assets/units/enemies/bulwark/bulwark_unit.tres",
	"res://assets/units/enemies/great_sword/great_sword_unit.tres",
	"res://assets/units/enemies/giant_hammer/giant_hammer_unit.tres",
	"res://assets/units/enemies/great_shield/great_shield_unit.tres",
	"res://assets/units/enemies/umbrella/umbrella_unit.tres",
	"res://assets/units/enemies/mortar/mortar_unit.tres",
	"res://assets/units/enemies/knight/knight_unit.tres",
]

const _ARCHETYPE_SHARES := {
	ArmyArchetype.ONE_TRICK_PONY: [0.9, 0.1],
	ArmyArchetype.HYBRID: [0.7, 0.3],
	ArmyArchetype.GENERALIST: [0.33, 0.33, 0.34],
}

static var _cached_enemy_pool: Array = []


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
			UnitStatsData.PowerTier.FEEBLE:
				score += 0.5
			UnitStatsData.PowerTier.WEAK:
				score += 1.0
			UnitStatsData.PowerTier.COMMON:
				score += 2.0
			UnitStatsData.PowerTier.UNCOMMON:
				score += 3.0
			_:
				score += 4.0
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
		if a[i].unit_data != b[i].unit_data or a[i].tier != b[i].tier:
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
	var unit_archetype: ArmyArchetype = (rng.randi() % 3) as ArmyArchetype
	var unit_slots := _distribute_mix(
		_enemy_pool_for_day(day),
		unit_archetype,
		total,
		rng,
		_enemy_pick_weight
	)

	var specs: Array[EnemyUnitSpec] = []
	for i in total:
		var unit_data: EnemyUnitData = unit_slots[i]
		var tier: UnitStatsData.PowerTier = _pick_weighted_tier(tier_weights, rng)
		specs.append(EnemyUnitSpec.make(unit_data, tier))
	return specs


static func _enemy_pool() -> Array:
	if not _cached_enemy_pool.is_empty():
		return _cached_enemy_pool
	var pool: Array = []
	for path in _ENEMY_UNIT_PATHS:
		var unit_data := load(path) as EnemyUnitData
		if unit_data != null:
			pool.append(unit_data)
	_cached_enemy_pool = pool
	return _cached_enemy_pool


static func _enemy_pool_for_day(day: int) -> Array:
	var pool: Array = []
	for entry in _enemy_pool():
		var unit_data := entry as EnemyUnitData
		if unit_data == null:
			continue
		if unit_data.min_day <= day:
			pool.append(unit_data)
	return pool


static func _enemy_pick_weight(entry) -> float:
	var unit_data := entry as EnemyUnitData
	if unit_data == null:
		return 1.0
	return maxf(unit_data.composition_weight, 0.0)


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
	return counts


static func _shuffle_array(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = values[i]
		values[i] = values[j]
		values[j] = tmp


static func _band_for_day(day: int) -> Dictionary:
	if GameState.is_elite_day(day):
		return _elite_band_for_day(day)
	match day:
		1, 2:
			return {
				"min_units": 2,
				"max_units": 3,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.FEEBLE, "weight": 1.0},
				],
			}
		3:
			return {
				"min_units": 3,
				"max_units": 4,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.WEAK, "weight": 1.0},
				],
			}
		4:
			return {
				"min_units": 4,
				"max_units": 5,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.WEAK, "weight": 1.0},
					{"tier": UnitStatsData.PowerTier.COMMON, "weight": 1.0},
				],
			}
		5:
			# Non-elite fallback (elite days use `_elite_band_for_day`).
			return {
				"min_units": 5,
				"max_units": 6,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.WEAK, "weight": 1.0},
					{"tier": UnitStatsData.PowerTier.COMMON, "weight": 2.0},
				],
			}
		6:
			return {
				"min_units": 6,
				"max_units": 8,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.COMMON, "weight": 1.0},
				],
			}
		7:
			return {
				"min_units": 7,
				"max_units": 10,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.COMMON, "weight": 2.0},
					{"tier": UnitStatsData.PowerTier.UNCOMMON, "weight": 1.0},
				],
			}
		8:
			return {
				"min_units": 9,
				"max_units": 12,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.COMMON, "weight": 2.0},
					{"tier": UnitStatsData.PowerTier.UNCOMMON, "weight": 1.0},
				],
			}
		9:
			return {
				"min_units": 11,
				"max_units": 15,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.COMMON, "weight": 1.0},
					{"tier": UnitStatsData.PowerTier.UNCOMMON, "weight": 1.0},
				],
			}
		_:
			# Day 10 non-elite fallback.
			return {
				"min_units": 14,
				"max_units": 18,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.COMMON, "weight": 1.0},
					{"tier": UnitStatsData.PowerTier.UNCOMMON, "weight": 1.0},
				],
			}


## Harder procedural armies for elite days (+units, tiers shifted up).
static func _elite_band_for_day(day: int) -> Dictionary:
	match day:
		5:
			return {
				"min_units": 7,
				"max_units": 10,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.WEAK, "weight": 1.0},
					{"tier": UnitStatsData.PowerTier.COMMON, "weight": 2.0},
					{"tier": UnitStatsData.PowerTier.UNCOMMON, "weight": 2.0},
				],
			}
		_:
			# Day 10 (and any other elite day).
			return {
				"min_units": 16,
				"max_units": 22,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.COMMON, "weight": 1.0},
					{"tier": UnitStatsData.PowerTier.UNCOMMON, "weight": 2.0},
					{"tier": UnitStatsData.PowerTier.RARE, "weight": 1.0},
				],
			}


static func _pick_weighted_tier(tier_weights: Array, rng: RandomNumberGenerator) -> UnitStatsData.PowerTier:
	if tier_weights.is_empty():
		return UnitStatsData.PowerTier.FEEBLE
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
