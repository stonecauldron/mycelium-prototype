extends Node

const _REGULAR_UNLOCKS := {&"solar_sword": 1, &"rose_thorn": 2, &"peashooter": 2, &"stump": 4}
const _STRONG_IDS := [&"solar_cleaver", &"durian", &"log", &"canopy", &"seed_lobber", &"acorn_knight"]
const _SCOUT_SCENE := preload("res://assets/base/troop_selection/scout_bubble/scout_bubble.tscn")
const _COMBAT_SCRIPT := preload("res://assets/combat/combat_stage/combat_stage.gd")

var _failed: int = 0
var _assertions: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_fitting()
	_check_generation()
	_check_reward_bounds()
	_check_reroll_bias()
	await _check_scout_and_combat()
	print("enemy_generation_check: %d assertions, %d failures" % [_assertions, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check_generation() -> void:
	var rng := RandomNumberGenerator.new()
	for day in range(1, 11):
		var bounds := EnemyComposer.budget_range_for_day(day)
		var seen: Dictionary = {}
		var sizes: Dictionary = {}
		var min_cost := INF
		var max_cost := 0.0
		var empty_strong_seen := false
		var one_strong_seen := false
		var two_strong_seen := false
		for sample in 128:
			GameState.run_seed = sample + 1
			var specs := EnemyComposer.specs_for_day(day)
			_check_army(day, specs, bounds.y)
			var ids := _ordered_ids(specs)
			EnemyComposer.specs_for_day(11 - day)
			_expect(ids == _ordered_ids(EnemyComposer.specs_for_day(day)), "seed repeatability day %d" % day)
			var strong: Dictionary = {}
			for spec in specs:
				seen[spec.unit_data.id] = true
				if spec.unit_data.is_strong:
					strong[spec.unit_data.id] = true
			empty_strong_seen = empty_strong_seen or strong.is_empty()
			one_strong_seen = one_strong_seen or strong.size() == 1
			two_strong_seen = two_strong_seen or strong.size() == 2
			sizes[specs.size()] = true
			min_cost = minf(min_cost, EnemyComposer.difficulty_score(specs))
			max_cost = maxf(max_cost, EnemyComposer.difficulty_score(specs))
			rng.seed = sample + day * 1000
			var rerolled := EnemyComposer.reroll_for_day(day, specs, rng)
			_check_army(day, rerolled, bounds.y)
			if GameState.is_elite_day(day):
				_expect(_ordered_ids(rerolled) == ids, "elite cannot reroll")
			else:
				_expect(_composition(rerolled) != _composition(specs), "reroll changes type counts day %d" % day)
			# Check the actual allocation, not only the Day maximum.
			var allocation := bounds.x + sample % (bounds.y - bounds.x + 1)
			rng.seed = sample + day * 2000
			_check_army(day, EnemyComposer._generate_with_budget(day, allocation, rng), allocation)
		for id in _REGULAR_UNLOCKS:
			if not GameState.is_elite_day(day) and day >= int(_REGULAR_UNLOCKS[id]):
				_expect(seen.has(id), "unlocked regular appears: %s day %d" % [id, day])
		if GameState.is_elite_day(day):
			for id in _STRONG_IDS:
				if day == 5 and id == &"durian":
					_expect(not seen.has(id), "Durian excluded from Day 5")
				else:
					_expect(seen.has(id), "elite pool covers %s" % id)
		if day >= 6 and day <= 9:
			_expect(empty_strong_seen and one_strong_seen and two_strong_seen, "mixed day supports zero, one, or two Strong types")
		if day == 1:
			_expect(sizes.has(2) and sizes.has(3) and sizes.size() == 2, "Day 1 supports two or three Swords")
		print("Day %d: allocation %d..%d, observed cost %.0f..%.0f, sizes %s" % [day, bounds.x, bounds.y, min_cost, max_cost, str(sizes.keys())])
	GameState.run_seed = 71
	_expect(_ordered_ids(EnemyComposer.specs_for_day(0)) == _ordered_ids(EnemyComposer.specs_for_day(1)), "low Day clamped")
	_expect(_ordered_ids(EnemyComposer.specs_for_day(11)) == _ordered_ids(EnemyComposer.specs_for_day(10)), "high Day clamped")


func _check_army(day: int, specs: Array[EnemyUnitSpec], budget: int) -> void:
	_expect(not specs.is_empty(), "nonempty army day %d" % day)
	_expect(EnemyComposer.difficulty_score(specs) <= float(budget), "army fits allocation day %d" % day)
	var strong: Dictionary = {}
	var types: Dictionary = {}
	var previous_line := 2
	for spec in specs:
		var unit := spec.unit_data
		_expect(unit.composition_cost > 0, "positive enemy cost")
		_expect(unit.min_day <= day, "authored unlock respected")
		types[unit.id] = true
		if unit.is_strong:
			strong[unit.id] = true
			_expect(_STRONG_IDS.has(unit.id), "correct Strong classification")
		else:
			_expect(_REGULAR_UNLOCKS.has(unit.id), "correct Regular classification")
			_expect(day >= int(_REGULAR_UNLOCKS.get(unit.id, 99)), "requested early unlock respected")
		var line := int(unit.get_combat_profile().formation_line)
		_expect(line <= previous_line, "rear-to-front Home order")
		previous_line = line
	_expect(types.size() <= 3, "at most three pattern types")
	if day <= 4:
		_expect(strong.is_empty(), "no Strong enemies before Day 5")
	elif GameState.is_elite_day(day):
		_expect(strong.size() == types.size(), "elite is Strong-only")
		if day == 5:
			_expect(strong.size() <= 1, "Day 5 has at most one Strong type")
	else:
		_expect(strong.size() <= 2, "mixed day has at most two Strong types")


func _check_fitting() -> void:
	var cheap := _type_with_cost(10)
	var other_cheap := _type_with_cost(10)
	var expensive := _type_with_cost(40)
	var cheap_counts := EnemyComposer._fit_counts_to_budget([cheap, other_cheap], [0.9, 0.1], 100)
	var strong_counts := EnemyComposer._fit_counts_to_budget([expensive, cheap], [0.9, 0.1], 100)
	_expect(cheap_counts == [9, 1], "cheap one-trick pony preserves 90/10")
	_expect(strong_counts == [2, 0], "expensive majority reduces army size; minority may round away")
	_expect(EnemyComposer._fit_counts_to_budget([cheap, other_cheap], [0.7, 0.3], 100) == [7, 3], "hybrid preserves 70/30")
	_expect(EnemyComposer._fit_counts_to_budget([cheap, other_cheap, expensive], [0.33, 0.33, 0.34], 60) == [1, 1, 1], "generalist fits all three types")
	_expect(EnemyComposer._fit_counts_to_budget([cheap], [0.33], 35) == [3], "single eligible type uses full normalized share")
	_expect(EnemyComposer._fit_counts_to_budget([expensive], [1.0], 39).is_empty(), "cannot buy an unaffordable unit")
	_expect(EnemyComposer._fit_counts_to_budget([], [], 100).is_empty(), "empty pool is handled")
	_expect(EnemyComposer._fit_counts_to_budget([cheap], [1.0], 0).is_empty(), "zero budget is handled")
	var a: Array[EnemyUnitSpec] = [EnemyUnitSpec.make(cheap), EnemyUnitSpec.make(expensive)]
	var b: Array[EnemyUnitSpec] = [a[1], a[0]]
	_expect(EnemyComposer._specs_equal(a, b), "shuffling does not count as a new Scout army")


func _check_reward_bounds() -> void:
	for day in range(1, 11):
		var bounds := EnemyComposer.budget_range_for_day(day)
		var midpoint := floori((float(bounds.x) + float(bounds.y)) * 0.5)
		var midpoint_t := float(midpoint - bounds.x) / float(bounds.y - bounds.x)
		var costs := [bounds.x - 2, bounds.x, midpoint, bounds.y, bounds.y + 2]
		var expected_t := [0.0, 0.0, midpoint_t, 1.0, 1.0]
		for i in costs.size():
			var unit := _type_with_cost(costs[i])
			var specs: Array[EnemyUnitSpec] = [EnemyUnitSpec.make(unit)]
			_expect(is_equal_approx(EnemyComposer.difficulty_t_for_day(day, specs), expected_t[i]), "authored reward bound day %d" % day)
			var reward := EnemyComposer.battle_reward_for(day, specs)
			_expect(reward == BiomassData.battle_reward(day, expected_t[i]), "reward uses actual cost")
			unit.stats = UnitStatsData.new()
			unit.stats.add_all(50)
			GameState.run_seed += 123
			_expect(EnemyComposer.battle_reward_for(day, specs) == reward, "reward independent of stats and run seed")


func _check_reroll_bias() -> void:
	var rng := RandomNumberGenerator.new()
	var sword := load("res://assets/units/enemies/solar_sword/solar_sword_unit.tres") as EnemyUnitData
	var easy: Array[EnemyUnitSpec] = [EnemyUnitSpec.make(sword), EnemyUnitSpec.make(sword)]
	var hard: Array[EnemyUnitSpec] = [easy[0], easy[1], EnemyUnitSpec.make(sword)]
	for sample in 64:
		rng.seed = sample
		_expect(EnemyComposer.reroll_for_day(1, easy, rng).size() == 3, "Day 1 easier army rerolls harder")
		rng.seed = sample
		_expect(EnemyComposer.reroll_for_day(1, hard, rng).size() == 2, "Day 1 harder army rerolls easier")
	var bounds := EnemyComposer.budget_range_for_day(6)
	var low: Array[EnemyUnitSpec] = [EnemyUnitSpec.make(_type_with_cost(bounds.x))]
	var high: Array[EnemyUnitSpec] = [EnemyUnitSpec.make(_type_with_cost(bounds.y))]
	var easier := 0
	var harder := 0
	for sample in 128:
		rng.seed = sample
		if EnemyComposer.difficulty_score(EnemyComposer.reroll_for_day(6, high, rng)) < float(bounds.y):
			easier += 1
		rng.seed = sample
		if EnemyComposer.difficulty_score(EnemyComposer.reroll_for_day(6, low, rng)) > float(bounds.x):
			harder += 1
	_expect(easier > 110 and harder > 110, "rerolls bias toward the opposite difficulty")


func _check_scout_and_combat() -> void:
	GameState.current_day = 0
	GameState.run_seed = 42
	GameState.clear_upcoming_enemy_formation()
	GameState.reset_scout_reroll_cost()
	GameState.biomass.amount = 100
	var scout: ScoutBubble = _SCOUT_SCENE.instantiate()
	add_child(scout)
	var before := _composition(GameState.upcoming_enemy_formation)
	_expect(scout._reroll_allowed(), "Day 1 Scout reroll remains available")
	scout._on_scout_reroll_pressed()
	_expect(GameState.biomass.amount == 98 and GameState.current_scout_reroll_cost() == 3, "Scout charges existing price and increments counter")
	_expect(before != _composition(GameState.upcoming_enemy_formation), "paid Day 1 reroll changes army")
	var label := scout.get_node("%ScoutRewardLabel") as Label
	_expect(label.text == "+%d" % EnemyComposer.battle_reward_for(1, GameState.upcoming_enemy_formation), "Scout displays matching reward")
	var cached_ids := _ordered_ids(GameState.upcoming_enemy_formation)
	var preview := _ordered_ids(EnemyComposer.specs_for_day(5))
	scout.preview_elite_for_day(5)
	_expect(_ordered_ids(GameState.upcoming_enemy_formation) == cached_ids, "elite preview preserves upcoming army")
	_expect(label.text == "+%d" % EnemyComposer.battle_reward_for(5, EnemyComposer.specs_for_day(5)), "elite preview uses elite reward")
	_expect(not scout._reroll_allowed(), "elite preview disables reroll")
	GameState.current_day = 4
	GameState.clear_upcoming_enemy_formation()
	scout.refresh()
	_expect(_ordered_ids(GameState.upcoming_enemy_formation) == preview, "actual elite matches advance preview")
	_expect(not scout._reroll_allowed(), "elite Day disables reroll")
	var selection := TroopSelectionScreen.new()
	var roster := selection._make_default_enemy_roster()
	_expect(roster.size() == preview.size(), "combat roster preserves army size")
	for i in roster.size():
		_expect(roster[i].enemy_unit_data == GameState.upcoming_enemy_formation[i].unit_data, "combat roster preserves type order")
		var mean := roster[i].enemy_unit_data.stats
		_expect(absi(roster[i].stats.strength - mean.strength) <= 1 and absi(roster[i].stats.dex - mean.dex) <= 1 and absi(roster[i].stats.con - mean.con) <= 1, "combat stat variance remains separate")
	BattleLaunch.set_enemy_roster(roster)
	var handed_off := BattleLaunch.take_enemy_roster()
	_expect(handed_off.size() == roster.size() and not BattleLaunch.has_enemy_roster(), "BattleLaunch handoff consumes roster")
	var combat: Node2D = _COMBAT_SCRIPT.new()
	var reward: int = combat.call("_compute_battle_reward", handed_off)
	_expect(label.text == "+%d" % reward, "actual Scout and combat rewards agree")
	GameState.clear_upcoming_enemy_formation()
	_expect(int(combat.call("_compute_battle_reward", handed_off)) == reward, "combat roster fallback has same reward")
	selection.free()
	combat.free()
	scout.queue_free()
	await get_tree().process_frame


func _type_with_cost(cost: int) -> EnemyUnitData:
	var unit := EnemyUnitData.new()
	unit.composition_cost = cost
	return unit


func _ordered_ids(specs: Array[EnemyUnitSpec]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for spec in specs:
		ids.append(spec.unit_data.id)
	return ids


func _composition(specs: Array[EnemyUnitSpec]) -> Dictionary:
	var counts: Dictionary = {}
	for spec in specs:
		var id := spec.unit_data.id
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


func _expect(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failed += 1
		push_error("FAIL: " + label)
