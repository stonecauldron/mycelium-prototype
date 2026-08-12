extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _expect(BiomassData.base_battle_reward(1) == 10, "day1 base 10")
	failed += _expect(BiomassData.base_battle_reward(2) == 15, "day2 base 15")
	failed += _expect(BiomassData.base_battle_reward(10) == 55, "day10 base 55")
	failed += _expect(BiomassData.battle_reward(1, 0.0) == 9, "day1 easiest 9")
	failed += _expect(BiomassData.battle_reward(1, 1.0) == 11, "day1 hardest 11")
	failed += _expect(BiomassData.battle_reward(1, 0.5) == 10, "day1 mid 10")
	failed += _expect(BiomassData.battle_reward(2, 0.0) == 14, "day2 easiest roundi(13.5)->14")
	failed += _expect(BiomassData.battle_reward(2, 1.0) == 17, "day2 hardest roundi(16.5)->17")

	GameState.run_seed = 42
	GameState.current_day = 0
	var day := 1
	var specs := EnemyComposer.specs_for_day(day)
	var reward := EnemyComposer.battle_reward_for(day, specs)
	failed += _expect(reward >= 9 and reward <= 11, "day1 composer reward in 9..11 got %d" % reward)
	var t := EnemyComposer.difficulty_t_for_day(day, specs)
	failed += _expect(t >= 0.0 and t <= 1.0, "difficulty_t in 0..1 got %s" % str(t))

	# Scout/combat agreement: same day + specs → same reward.
	var again := EnemyComposer.battle_reward_for(day, specs)
	failed += _expect(again == reward, "reward stable for same specs")

	if failed > 0:
		push_error("battle_reward_check failed: %d assertion(s)" % failed)
		get_tree().quit(1)
	else:
		print("battle_reward_check OK")
		get_tree().quit(0)


func _expect(cond: bool, label: String) -> int:
	if cond:
		return 0
	push_error("FAIL: %s" % label)
	return 1
