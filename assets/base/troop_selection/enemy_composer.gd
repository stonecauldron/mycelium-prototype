class_name EnemyComposer
extends RefCounted

## Day-curve procedural enemy specs + optional multi-variant skill-check overrides.

const _REROLL_CANDIDATE_COUNT := 8
const _MIDPOINT_SAMPLE_COUNT := 8


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
			UnitStatsData.PowerTier.AVERAGE:
				score += 2.0
			UnitStatsData.PowerTier.STRONG:
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
		if a[i].type != b[i].type or a[i].tier != b[i].tier or a[i].is_imago != b[i].is_imago:
			return false
	return true


static func _rng_for_day(day: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([GameState.run_seed, day])
	return rng


static func _skill_check_variants(day: int) -> Array:
	## Each entry is Array[EnemyUnitSpec]. Empty → use day curve.
	match day:
		5:
			return [_day_5_variant_a(), _day_5_variant_b()]
		10:
			return [_day_10_variant_a(), _day_10_variant_b()]
		_:
			return []


static func _u(
	unit_type: EnemyUnitSpec.UnitType,
	tier: UnitStatsData.PowerTier,
	imago: bool
) -> EnemyUnitSpec:
	return EnemyUnitSpec.make(unit_type, tier, imago)


static func _day_5_variant_a() -> Array[EnemyUnitSpec]:
	## Balanced three-weapon mid-run check.
	return [
		_u(EnemyUnitSpec.UnitType.MELEE, UnitStatsData.PowerTier.WEAK, true),
		_u(EnemyUnitSpec.UnitType.MELEE, UnitStatsData.PowerTier.AVERAGE, true),
		_u(EnemyUnitSpec.UnitType.SPEAR, UnitStatsData.PowerTier.WEAK, true),
		_u(EnemyUnitSpec.UnitType.SPEAR, UnitStatsData.PowerTier.AVERAGE, true),
		_u(EnemyUnitSpec.UnitType.BOW, UnitStatsData.PowerTier.WEAK, false),
	]


static func _day_5_variant_b() -> Array[EnemyUnitSpec]:
	## Bow-heavier pressure, fewer spears.
	return [
		_u(EnemyUnitSpec.UnitType.MELEE, UnitStatsData.PowerTier.AVERAGE, true),
		_u(EnemyUnitSpec.UnitType.MELEE, UnitStatsData.PowerTier.AVERAGE, true),
		_u(EnemyUnitSpec.UnitType.SPEAR, UnitStatsData.PowerTier.WEAK, true),
		_u(EnemyUnitSpec.UnitType.BOW, UnitStatsData.PowerTier.WEAK, true),
		_u(EnemyUnitSpec.UnitType.BOW, UnitStatsData.PowerTier.AVERAGE, false),
	]


static func _day_10_variant_a() -> Array[EnemyUnitSpec]:
	## Finale: melee-heavy STRONG imagos.
	return [
		_u(EnemyUnitSpec.UnitType.MELEE, UnitStatsData.PowerTier.STRONG, true),
		_u(EnemyUnitSpec.UnitType.MELEE, UnitStatsData.PowerTier.STRONG, true),
		_u(EnemyUnitSpec.UnitType.MELEE, UnitStatsData.PowerTier.AVERAGE, true),
		_u(EnemyUnitSpec.UnitType.MELEE, UnitStatsData.PowerTier.STRONG, true),
		_u(EnemyUnitSpec.UnitType.SPEAR, UnitStatsData.PowerTier.STRONG, true),
		_u(EnemyUnitSpec.UnitType.SPEAR, UnitStatsData.PowerTier.AVERAGE, false),
		_u(EnemyUnitSpec.UnitType.BOW, UnitStatsData.PowerTier.STRONG, true),
		_u(EnemyUnitSpec.UnitType.BOW, UnitStatsData.PowerTier.AVERAGE, false),
	]


static func _day_10_variant_b() -> Array[EnemyUnitSpec]:
	## Finale: spear/bow pressure with a thinner melee front.
	return [
		_u(EnemyUnitSpec.UnitType.MELEE, UnitStatsData.PowerTier.STRONG, true),
		_u(EnemyUnitSpec.UnitType.MELEE, UnitStatsData.PowerTier.STRONG, true),
		_u(EnemyUnitSpec.UnitType.MELEE, UnitStatsData.PowerTier.AVERAGE, true),
		_u(EnemyUnitSpec.UnitType.SPEAR, UnitStatsData.PowerTier.STRONG, true),
		_u(EnemyUnitSpec.UnitType.SPEAR, UnitStatsData.PowerTier.STRONG, true),
		_u(EnemyUnitSpec.UnitType.SPEAR, UnitStatsData.PowerTier.AVERAGE, false),
		_u(EnemyUnitSpec.UnitType.BOW, UnitStatsData.PowerTier.STRONG, true),
		_u(EnemyUnitSpec.UnitType.BOW, UnitStatsData.PowerTier.STRONG, true),
	]


static func _generate_from_curve(day: int, rng: RandomNumberGenerator) -> Array[EnemyUnitSpec]:
	var band := _band_for_day(day)
	var total: int = rng.randi_range(band.min_units, band.max_units)
	var types: Array = band.types
	var tier_weights: Array = band.tier_weights
	var imago_chance: float = band.imago_chance

	var specs: Array[EnemyUnitSpec] = []
	for i in total:
		var unit_type: EnemyUnitSpec.UnitType = _pick_type(types, i, total, rng)
		var tier: UnitStatsData.PowerTier = _pick_weighted_tier(tier_weights, rng)
		var imago := imago_chance > 0.0 and rng.randf() < imago_chance
		specs.append(EnemyUnitSpec.make(unit_type, tier, imago))
	return specs


static func _band_for_day(day: int) -> Dictionary:
	match day:
		1, 2:
			return {
				"min_units": 2,
				"max_units": 3,
				"types": [
					EnemyUnitSpec.UnitType.MELEE,
					EnemyUnitSpec.UnitType.SPEAR,
					EnemyUnitSpec.UnitType.BOW,
				],
				"imago_chance": 0.0,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.WEAK, "weight": 1.0},
				],
			}
		3, 4:
			return {
				"min_units": 3,
				"max_units": 5,
				"types": [
					EnemyUnitSpec.UnitType.MELEE,
					EnemyUnitSpec.UnitType.SPEAR,
					EnemyUnitSpec.UnitType.BOW,
				],
				"imago_chance": 0.4,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.WEAK, "weight": 2.0},
					{"tier": UnitStatsData.PowerTier.AVERAGE, "weight": 1.0},
				],
			}
		5, 6:
			return {
				"min_units": 4,
				"max_units": 6,
				"types": [
					EnemyUnitSpec.UnitType.MELEE,
					EnemyUnitSpec.UnitType.SPEAR,
					EnemyUnitSpec.UnitType.BOW,
				],
				"imago_chance": 0.5,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.WEAK, "weight": 1.0},
					{"tier": UnitStatsData.PowerTier.AVERAGE, "weight": 1.0},
				],
			}
		7, 8:
			return {
				"min_units": 5,
				"max_units": 8,
				"types": [
					EnemyUnitSpec.UnitType.MELEE,
					EnemyUnitSpec.UnitType.SPEAR,
					EnemyUnitSpec.UnitType.BOW,
				],
				"imago_chance": 0.6,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.AVERAGE, "weight": 2.0},
					{"tier": UnitStatsData.PowerTier.STRONG, "weight": 1.0},
				],
			}
		_:
			# Days 9–10 (day 10 normally overridden by skill check).
			return {
				"min_units": 6,
				"max_units": 10,
				"types": [
					EnemyUnitSpec.UnitType.MELEE,
					EnemyUnitSpec.UnitType.SPEAR,
					EnemyUnitSpec.UnitType.BOW,
				],
				"imago_chance": 0.7,
				"tier_weights": [
					{"tier": UnitStatsData.PowerTier.AVERAGE, "weight": 1.0},
					{"tier": UnitStatsData.PowerTier.STRONG, "weight": 1.0},
				],
			}


static func _pick_type(
	types: Array,
	slot_index: int,
	total: int,
	rng: RandomNumberGenerator
) -> EnemyUnitSpec.UnitType:
	if types.is_empty():
		return EnemyUnitSpec.UnitType.MELEE
	# Bias early slots toward melee when available so the front line isn't empty.
	if types.has(EnemyUnitSpec.UnitType.MELEE) and slot_index == 0:
		return EnemyUnitSpec.UnitType.MELEE
	if types.has(EnemyUnitSpec.UnitType.MELEE) and slot_index == 1 and total >= 3 and rng.randf() < 0.6:
		return EnemyUnitSpec.UnitType.MELEE
	return types[rng.randi() % types.size()] as EnemyUnitSpec.UnitType


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
