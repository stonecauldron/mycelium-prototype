extends Node2D

## Real battle startup regression: never freeze or reposition either army.
## Run this scene with optional -- --child --speed=2 --count=4 --seed=100126.
## --all covers Adult/Child at 1x/2x/4x and an Adult against four Solar Swords.
const STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const CROSSBOW := preload("res://assets/weapons/crossbow/crossbow.tres")
const SOLAR_SWORD := preload("res://assets/units/enemies/solar_sword/solar_sword_unit.tres")

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[OPENING-SHOT] " + message)


func _run() -> void:
	var adult := true
	var speed := 1
	var enemy_count := 1
	var random_seed := 100126
	var run_all := false
	for argument in OS.get_cmdline_user_args():
		if argument == "--all":
			run_all = true
		elif argument == "--child":
			adult = false
		elif argument.begins_with("--speed="):
			speed = int(argument.get_slice("=", 1))
		elif argument.begins_with("--count="):
			enemy_count = maxi(1, int(argument.get_slice("=", 1)))
		elif argument.begins_with("--seed="):
			random_seed = int(argument.get_slice("=", 1))
	if run_all:
		for is_adult in [true, false]:
			for fast_forward in [1, 2, 4]:
				await _run_case(is_adult, fast_forward, 1, random_seed)
		await _run_case(true, 1, 4, random_seed)
	else:
		await _run_case(adult, speed, enemy_count, random_seed)
	print("[OPENING-SHOT] SUMMARY checks=", _checks, " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _run_case(adult: bool, speed: int, enemy_count: int, random_seed: int) -> void:
	var failures_before := _failures
	var checks_before := _checks
	seed(random_seed)
	GameState.reset_run()
	var stage := STAGE.instantiate()
	stage.sandboxed = true
	add_child(stage)
	var stats := UnitStatsData.new()
	stats.strength = 2
	stats.dex = 2
	stats.con = 2
	var player := RosterUnitData.create("Opening crossbow", stats, CROSSBOW)
	player.is_imago = adult
	player.life_stage_id = RosterUnitData.STAGE_IMAGO if adult else RosterUnitData.STAGE_JUVENILE
	var players: Array[RosterUnitData] = [player]
	var enemies: Array[RosterUnitData] = []
	for index in enemy_count:
		enemies.append(RosterUnitData.create_enemy("Solar Sword %d" % index,
			SOLAR_SWORD.stats.duplicate(true), SOLAR_SWORD))
	stage.start_battle(players, enemies)
	stage._set_fast_forward(speed)
	var shooter: Unit = stage.player_troop.get_units()[0]
	var targets: Array[Unit] = stage.enemy_troop.get_units()
	var target: Unit = targets[0]
	var initial_hp := _total_hp(targets)
	var shot: Projectile = null
	var released := false
	var first_shot_count := 0
	var crossed := false
	var shot_ids: Dictionary = {}
	var elapsed := 0.0
	var closest_x := INF
	var closest_sample := ""
	var last_sample := ""
	var label := "%s speed=%d count=%d seed=%d" % ["adult" if adult else "child",
		speed, enemy_count, random_seed]
	print("[OPENING-SHOT] START ", label, " ", _sample(shooter, target, null))
	for _frame in 360:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
		for candidate: Projectile in get_tree().get_nodes_in_group("projectiles"):
			if candidate.owner_unit != shooter or shot_ids.has(candidate.get_instance_id()):
				continue
			shot_ids[candidate.get_instance_id()] = true
			first_shot_count += 1
			if released:
				continue
			released = true
			shot = candidate
			if is_instance_valid(shooter._ranged_apex_target):
				target = shooter._ranged_apex_target
			print("[OPENING-SHOT] RELEASE t=", elapsed, " ", _sample(shooter, target, shot))
			_check(shooter.is_on_floor(), label + " first bolt released before shooter landed")
		if released:
			# Preserve normal movement/recovery while excluding damage from a later shot.
			shooter._attack_timer = 999.0
		if is_instance_valid(shot):
			last_sample = _sample(shooter, target, shot)
			var distance_x := absf(shot.global_position.x - target.global_position.x)
			if distance_x < closest_x:
				closest_x = distance_x
				closest_sample = last_sample
			if not crossed and shot.global_position.x >= target.global_position.x:
				crossed = true
				print("[OPENING-SHOT] CROSSED t=", elapsed, " ", last_sample)
		if released and (_total_hp(targets) < initial_hp or not is_instance_valid(shot)
				or shot._spent):
			break
	print("[OPENING-SHOT] CLOSEST ", closest_sample)
	print("[OPENING-SHOT] END t=", elapsed, " hp=", initial_hp, "->", _total_hp(targets),
		" released=", released, " shots=", first_shot_count, " ", last_sample)
	_check(released, label + " did not release its first bolt within six seconds")
	_check(first_shot_count == 1, label + " expected exactly one released bolt")
	_check(_total_hp(targets) < initial_hp, label + " first bolt missed before landing/expiry")
	stage.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0) and Engine.physics_ticks_per_second == 60,
		"Stage leaked fast-forward timing")
	print("[OPENING-SHOT] CASE ", label, " checks=", _checks - checks_before,
		" failures=", _failures - failures_before)


func _total_hp(targets: Array[Unit]) -> int:
	var total := 0
	for target in targets:
		if is_instance_valid(target):
			total += target.current_hp
	return total


func _sample(shooter: Unit, target: Unit, shot: Projectile) -> String:
	var bounds := Rect2()
	if target._appearance != null and target._appearance.hurtbox != null:
		var shape := target._appearance.hurtbox.get_node("CollisionShape2D") as CollisionShape2D
		bounds = shape.global_transform * shape.shape.get_rect()
	var result := "shooter=%s v=%s floor=%s target=%s v=%s floor=%s body=%s hp=%d" % [
		shooter.global_position, shooter.velocity, shooter.is_on_floor(),
		target.global_position, target.velocity, target.is_on_floor(), bounds, target.current_hp]
	if is_instance_valid(shot):
		result += " bolt=%s v=%s g=%s age=%.3f spent=%s" % [shot.global_position,
			shot._velocity, shot._gravity_vector(), shot._lifetime, shot._spent]
	return result
