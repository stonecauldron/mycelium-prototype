class_name EnemyComposer
extends RefCounted

## Day-curve procedural enemy specs + optional multi-variant skill-check overrides.

enum ArmyArchetype { ONE_TRICK_PONY, HYBRID, GENERALIST }

const _REROLL_CANDIDATE_COUNT := 8
## Seeded day-curve samples for midpoint and Battle-reward difficulty bounds.
const _DIFFICULTY_SAMPLE_COUNT := 8

const _ENEMY_UNIT_PATHS: Array[String] = [
	"res://assets/units/enemies/solar_sword/solar_sword_unit.tres",
	"res://assets/units/enemies/rose_thorn/rose_thorn_unit.tres",
	"res://assets/units/enemies/peashooter/peashooter_unit.tres",
	"res://assets/units/enemies/stump/stump_unit.tres",
	"res://assets/units/enemies/solar_cleaver/solar_cleaver_unit.tres",
	"res://assets/units/enemies/durian/durian_unit.tres",
	"res://assets/units/enemies/log/log_unit.tres",
	"res://assets/units/enemies/canopy/canopy_unit.tres",
	"res://assets/units/enemies/seed_lobber/seed_lobber_unit.tres",
	"res://assets/units/enemies/acorn_knight/acorn_knight_unit.tres",
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
		var chosen: Array[EnemyUnitSpec] = variants[pick]
		return _ordered_copy(chosen)
	return _generate_from_curve(clamped, rng)


static func difficulty_score(specs: Array[EnemyUnitSpec]) -> float:
	var score := 0.0
	for spec in specs:
		if spec.unit_data == null:
			continue
		score += float(spec.unit_data.average_stat_sum())
	return score


## 0 = easiest sampled army for the day, 1 = hardest. Flat day → 0.5 (×1.0 reward).
static func difficulty_t_for_day(day: int, specs: Array[EnemyUnitSpec]) -> float:
	var score := difficulty_score(specs)
	var bounds := _difficulty_bounds_for_day(day)
	var min_s: float = bounds.min
	var max_s: float = bounds.max
	if max_s <= min_s:
		return 0.5
	return clampf((score - min_s) / (max_s - min_s), 0.0, 1.0)


static func battle_reward_for(day: int, specs: Array[EnemyUnitSpec]) -> int:
	return BiomassData.battle_reward(day, difficulty_t_for_day(day, specs))


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
	var scores := _difficulty_scores_for_day(day)
	if scores.is_empty():
		return 0.0
	var sum := 0.0
	for score in scores:
		sum += score
	return sum / float(scores.size())


static func _difficulty_bounds_for_day(day: int) -> Dictionary:
	var scores := _difficulty_scores_for_day(day)
	if scores.is_empty():
		return {"min": 0.0, "max": 0.0}
	var min_s := scores[0]
	var max_s := scores[0]
	for score in scores:
		min_s = minf(min_s, score)
		max_s = maxf(max_s, score)
	return {"min": min_s, "max": max_s}


static func _difficulty_scores_for_day(day: int) -> Array[float]:
	var scores: Array[float] = []
	var variants := _skill_check_variants(day)
	if not variants.is_empty():
		for variant in variants:
			scores.append(difficulty_score(variant))
		return scores
	for i in _DIFFICULTY_SAMPLE_COUNT:
		var sample_rng := RandomNumberGenerator.new()
		sample_rng.seed = hash([GameState.run_seed, day, &"midpoint", i])
		scores.append(difficulty_score(_generate_from_curve(day, sample_rng)))
	return scores


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
				candidates.append(_ordered_copy(specs))
		if candidates.is_empty():
			for variant in variants:
				var fallback: Array[EnemyUnitSpec] = variant
				candidates.append(_ordered_copy(fallback))
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
		if a[i].unit_data != b[i].unit_data:
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
		specs.append(EnemyUnitSpec.make(unit_data))
	return _order_by_range_class(specs)


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


## Home order: Ranged (rear), Mid, Melee (toward the player). Shuffle within a Range class is kept.
static func _ordered_copy(specs: Array[EnemyUnitSpec]) -> Array[EnemyUnitSpec]:
	var copy: Array[EnemyUnitSpec] = []
	copy.assign(specs)
	return _order_by_range_class(copy)


static func _order_by_range_class(specs: Array[EnemyUnitSpec]) -> Array[EnemyUnitSpec]:
	var keyed: Array[Dictionary] = []
	for i in specs.size():
		keyed.append({"i": i, "spec": specs[i]})
	keyed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var key_a := _spec_range_sort_key(a["spec"])
		var key_b := _spec_range_sort_key(b["spec"])
		if key_a != key_b:
			return key_a < key_b
		return int(a["i"]) < int(b["i"])
	)
	for i in keyed.size():
		specs[i] = keyed[i]["spec"]
	return specs


static func _spec_range_sort_key(spec: EnemyUnitSpec) -> int:
	if spec == null or spec.unit_data == null:
		return 99
	match spec.unit_data.get_combat_profile().formation_line:
		WeaponData.FormationLine.BACK:
			return 0
		WeaponData.FormationLine.MID:
			return 1
		WeaponData.FormationLine.FRONT:
			return 2
		_:
			return 99


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
			return {"min_units": 2, "max_units": 3}
		3:
			return {"min_units": 3, "max_units": 4}
		4:
			return {"min_units": 4, "max_units": 5}
		5:
			# Non-elite fallback (elite days use `_elite_band_for_day`).
			return {"min_units": 5, "max_units": 6}
		6:
			return {"min_units": 6, "max_units": 8}
		7:
			return {"min_units": 7, "max_units": 10}
		8:
			return {"min_units": 9, "max_units": 12}
		9:
			return {"min_units": 11, "max_units": 15}
		_:
			# Day 10 non-elite fallback.
			return {"min_units": 14, "max_units": 18}


## Harder procedural armies for elite days (more units; typed stats come from EnemyUnitData).
static func _elite_band_for_day(day: int) -> Dictionary:
	match day:
		5:
			return {"min_units": 7, "max_units": 10}
		_:
			# Day 10 (and any other elite day).
			return {"min_units": 16, "max_units": 22}
