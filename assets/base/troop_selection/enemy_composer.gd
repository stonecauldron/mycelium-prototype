class_name EnemyComposer
extends RefCounted

## Day budget → pattern → eligible enemy types → affordable headcounts.

enum ArmyArchetype { ONE_TRICK_PONY, HYBRID, GENERALIST }

const _REROLL_CANDIDATE_COUNT := 8
## Initial tuning in Army-budget points, indexed by Day minus one.
const _DAY_BUDGET_RANGES: Array[Vector2i] = [
	Vector2i(12, 18),
	Vector2i(22, 30),
	Vector2i(28, 40),
	Vector2i(40, 56),
	Vector2i(82, 111), # Elite: Strong enemies only.
	Vector2i(90, 120),
	Vector2i(108, 144),
	Vector2i(132, 176),
	Vector2i(168, 216),
	Vector2i(240, 312), # Elite: Strong enemies only.
]

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
	return _generate_from_curve(clamped, _rng_for_day(clamped))


static func budget_range_for_day(day: int) -> Vector2i:
	return _DAY_BUDGET_RANGES[clampi(day, 1, GameState.WIN_DAYS) - 1]


static func difficulty_score(specs: Array[EnemyUnitSpec]) -> float:
	var score := 0.0
	for spec in specs:
		if spec == null or spec.unit_data == null:
			continue
		score += float(spec.unit_data.composition_cost)
	return score


## Actual army cost within the authored Day range; unspent points earn no reward.
static func difficulty_t_for_day(day: int, specs: Array[EnemyUnitSpec]) -> float:
	var score := difficulty_score(specs)
	var bounds := budget_range_for_day(day)
	var min_s := float(bounds.x)
	var max_s := float(bounds.y)
	if max_s <= min_s:
		return 0.5
	return clampf((score - min_s) / (max_s - min_s), 0.0, 1.0)


static func battle_reward_for(day: int, specs: Array[EnemyUnitSpec]) -> int:
	return BiomassData.battle_reward(day, difficulty_t_for_day(day, specs))


static func reroll_for_day(
	day: int,
	current_specs: Array[EnemyUnitSpec],
	rng: RandomNumberGenerator = null
) -> Array[EnemyUnitSpec]:
	var clamped := clampi(day, 1, GameState.WIN_DAYS)
	if GameState.is_elite_day(clamped):
		return current_specs
	var generator := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		generator.randomize()
	var candidates := _reroll_candidates(clamped, current_specs, generator)
	if candidates.is_empty():
		return current_specs
	var current_score := difficulty_score(current_specs)
	var bounds := budget_range_for_day(clamped)
	var midpoint := (float(bounds.x) + float(bounds.y)) * 0.5
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
	var roll := generator.randf() * total_weight
	var acc := 0.0
	for i in candidates.size():
		acc += weights[i]
		if roll <= acc:
			return candidates[i]
	return candidates[candidates.size() - 1]


static func _reroll_candidates(
	day: int,
	current_specs: Array[EnemyUnitSpec],
	rng: RandomNumberGenerator
) -> Array:
	var candidates: Array = []
	var bounds := budget_range_for_day(day)
	for i in _REROLL_CANDIDATE_COUNT:
		var budget := rng.randi_range(bounds.x, bounds.y)
		# Include both ends so Day 1 always offers the other Sword count.
		if i == 0:
			budget = bounds.x
		elif i == 1:
			budget = bounds.y
		var specs := _generate_with_budget(day, budget, rng)
		if not _specs_equal(specs, current_specs):
			candidates.append(specs)
	return candidates


static func _specs_equal(a: Array[EnemyUnitSpec], b: Array[EnemyUnitSpec]) -> bool:
	if a.size() != b.size():
		return false
	var counts: Dictionary = {}
	for spec in a:
		counts[spec.unit_data] = int(counts.get(spec.unit_data, 0)) + 1
	for spec in b:
		var count := int(counts.get(spec.unit_data, 0))
		if count == 0:
			return false
		counts[spec.unit_data] = count - 1
	return true


static func _rng_for_day(day: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([GameState.run_seed, day])
	return rng


static func _generate_from_curve(day: int, rng: RandomNumberGenerator) -> Array[EnemyUnitSpec]:
	var bounds := budget_range_for_day(day)
	return _generate_with_budget(day, rng.randi_range(bounds.x, bounds.y), rng)


static func _generate_with_budget(
	day: int,
	budget: int,
	rng: RandomNumberGenerator
) -> Array[EnemyUnitSpec]:
	var unit_archetype: ArmyArchetype = (rng.randi() % 3) as ArmyArchetype
	var max_strong_types := 3 if GameState.is_elite_day(day) else 2
	if day == 5:
		max_strong_types = 1
	var unit_slots := _distribute_mix(
		_enemy_pool_for_day(day),
		unit_archetype,
		budget,
		rng,
		max_strong_types
	)

	var specs: Array[EnemyUnitSpec] = []
	for unit_data: EnemyUnitData in unit_slots:
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
	var elite := GameState.is_elite_day(day)
	for entry in _enemy_pool():
		var unit_data := entry as EnemyUnitData
		if unit_data == null or unit_data.composition_cost <= 0:
			continue
		if unit_data.min_day > day:
			continue
		if elite and not unit_data.is_strong:
			continue
		if day < 5 and unit_data.is_strong:
			continue
		pool.append(unit_data)
	return pool


static func _distribute_mix(
	pool: Array,
	archetype: ArmyArchetype,
	budget: int,
	rng: RandomNumberGenerator,
	max_strong_types: int
) -> Array:
	var shares: Array = _ARCHETYPE_SHARES[archetype]
	var pick_count: int = mini(shares.size(), pool.size())
	var picked := _pick_distinct(pool, pick_count, rng, max_strong_types)
	var counts := _fit_counts_to_budget(picked, shares.slice(0, picked.size()), budget)
	var slots: Array = []
	for i in counts.size():
		for _j in counts[i]:
			slots.append(picked[i])
	_shuffle_array(slots, rng)
	return slots


static func _pick_distinct(
	pool: Array,
	count: int,
	rng: RandomNumberGenerator,
	max_strong_types: int
) -> Array:
	var remaining: Array = pool.duplicate()
	var picked: Array = []
	var strong_count := 0
	var n := mini(count, remaining.size())
	for _i in n:
		if remaining.is_empty():
			break
		var index := _weighted_index(remaining, rng)
		var unit_data: EnemyUnitData = remaining[index]
		picked.append(unit_data)
		remaining.remove_at(index)
		if unit_data.is_strong:
			strong_count += 1
		if strong_count >= max_strong_types:
			remaining = remaining.filter(func(entry: EnemyUnitData) -> bool:
				return not entry.is_strong
			)
	return picked


static func _weighted_index(
	pool: Array,
	rng: RandomNumberGenerator
) -> int:
	if pool.is_empty():
		return 0
	var total_weight := 0.0
	var weights: Array[float] = []
	for entry: EnemyUnitData in pool:
		var weight := maxf(entry.composition_weight, 0.0)
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


## Largest affordable headcount with the pattern's rounded shares. No filler types.
static func _fit_counts_to_budget(picked: Array, shares: Array, budget: int) -> Array[int]:
	if picked.is_empty() or budget <= 0:
		return []
	var cheapest: int = picked[0].composition_cost
	for unit_data: EnemyUnitData in picked:
		cheapest = mini(cheapest, unit_data.composition_cost)
	if cheapest <= 0:
		return []
	var max_count := floori(float(budget) / float(cheapest))
	for total in range(max_count, 0, -1):
		var counts := _shares_to_counts(shares, total)
		var cost := 0
		for i in counts.size():
			cost += counts[i] * int(picked[i].composition_cost)
		if cost <= budget:
			return counts
	return []


static func _shares_to_counts(shares: Array, total: int) -> Array[int]:
	var counts: Array[int] = []
	if shares.is_empty() or total <= 0:
		return counts
	var share_sum := 0.0
	for share in shares:
		share_sum += float(share)
	var raw: Array[float] = []
	var floored_sum := 0
	for share in shares:
		var value := float(share) / share_sum * float(total)
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
