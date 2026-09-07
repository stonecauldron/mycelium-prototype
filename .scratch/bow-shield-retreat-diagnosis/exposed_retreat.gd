extends "res://.scratch/bow-shield-retreat-diagnosis/evaluate_tuning.gd"


func _run() -> void:
	var findings := 0
	for count in [1, 2]:
		findings += await _exposed_case("bow", "solar_sword", count)
		if "--bow-sword" not in OS.get_cmdline_user_args():
			if "--sword-only" not in OS.get_cmdline_user_args():
				findings += await _exposed_case("bow", "solar_cleaver", count)
				if "--extra-melee" in OS.get_cmdline_user_args():
					for melee_id in ["durian", "acorn_knight"]:
						findings += await _exposed_case("bow", melee_id, count)
			findings += await _exposed_case("peashooter", "sword", count, true)
	print("[EXPOSED-RETREAT] SUMMARY damaged_units_without_retreat=", findings)
	get_tree().quit(1 if findings > 0 else 0)


func _exposed_case(ranged_id: String, melee_id: String, count: int, mirrored: bool = false) -> int:
	seed(20260905)
	var stage := STAGE.instantiate()
	stage.sandboxed = true
	add_child(stage)
	await get_tree().process_frame
	var players: Array[RosterUnitData] = []
	var enemies: Array[RosterUnitData] = []
	var args := OS.get_cmdline_user_args()
	var melee_count := 3 if "--three-melee" in args else 1
	for _i in count:
		if mirrored:
			enemies.append(_enemy(ranged_id))
		else:
			players.append(_player(ranged_id))
	for _i in melee_count:
		if mirrored:
			players.append(_player(melee_id))
		else:
			enemies.append(_enemy(melee_id))
	stage.start_battle(players, enemies)
	stage._set_fast_forward(1)
	var defenders: Troop = stage.enemy_troop if mirrored else stage.player_troop
	var subjects := defenders.get_units()
	if "--retreat-192" in args:
		for actor in subjects:
			actor.combat = actor.combat.duplicate(true)
			actor.combat.skirmish_distance = 192.0
	if "--no-knockback" in args:
		for actor: Unit in stage.player_troop.get_units() + stage.enemy_troop.get_units():
			actor.combat = actor.combat.duplicate(true)
			actor.combat.knockback_force = 0.0
	var samples: Array[Dictionary] = []
	for actor in subjects:
		samples.append({"min_distance": INF, "min_ai_distance": INF, "retreat_frames": 0,
			"within_entry_frames": 0, "within_entry_attacking": 0, "within_entry_knockback": 0,
			"damage_taken": 0, "slot": actor.squad_index, "entry": actor._get_skirmish_distance(),
			"alive": true, "retreat_distance": 0.0, "previous_x": actor.global_position.x})
	for _frame in FRAMES:
		await get_tree().physics_frame
		for index in subjects.size():
			var actor: Unit = subjects[index]
			var sample: Dictionary = samples[index]
			if not is_instance_valid(actor):
				sample.alive = false
				continue
			sample.damage_taken = actor.damage_taken
			sample.alive = actor.current_hp > 0
			if not sample.alive:
				continue
			var retreating := (actor._combat_phase == Unit.CombatPhase.RETREATING
				and not actor._in_knockback and defenders.get_facing() * actor.velocity.x < -8.0)
			if retreating:
				sample.retreat_distance += maxf(0.0, defenders.get_facing() * (sample.previous_x - actor.global_position.x))
			sample.previous_x = actor.global_position.x
			if not is_instance_valid(actor._target):
				continue
			var distance := actor.global_position.distance_to(actor._target.global_position)
			var attacking := actor._combat_phase == Unit.CombatPhase.ATTACKING
			sample.min_distance = minf(sample.min_distance, distance)
			if not attacking and not actor._in_knockback:
				sample.min_ai_distance = minf(sample.min_ai_distance, distance)
			if retreating:
				sample.retreat_frames += 1
			if distance <= actor._get_skirmish_distance():
				sample.within_entry_frames += 1
				if attacking:
					sample.within_entry_attacking += 1
				if actor._in_knockback:
					sample.within_entry_knockback += 1
	var findings := 0
	for index in subjects.size():
		var sample: Dictionary = samples[index]
		var finding: bool = sample.damage_taken > 0 and sample.retreat_frames == 0
		if finding:
			findings += 1
		sample.erase("previous_x")
		print("[EXPOSED-RETREAT] ", ranged_id, " count=", count, " vs ", melee_count, " ", melee_id,
			" findings=", finding,
			" samples=", sample, " probes=", args)
	stage.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return findings


func _stats() -> UnitStatsData:
	var stats := super._stats()
	if "--normal-health" in OS.get_cmdline_user_args():
		stats.con = 5
	return stats
