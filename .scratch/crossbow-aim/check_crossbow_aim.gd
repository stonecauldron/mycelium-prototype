extends Node2D

const STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const CROSSBOW := preload("res://assets/weapons/crossbow/crossbow.tres")
const BOW := preload("res://assets/weapons/bow/bow.tres")

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[CROSSBOW] " + message)


func _run() -> void:
	seed(100126)
	_check_flight()
	for speed in [1, 2, 4]:
		for enemy_id in ["solar_sword", "peashooter", "stump"]:
			await _check_combat(enemy_id, speed)
	print("[CROSSBOW] SUMMARY checks=", _checks, " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check_flight() -> void:
	var origin := Vector2(0.0, 400.0)
	var displacements: Array[Vector2] = [
		Vector2.ZERO, Vector2(0.001, -0.001), Vector2(0.0, -30.0),
		Vector2(30.0, -3.0), Vector2(400.0, -16.0), Vector2(1200.0, -16.0),
		Vector2(400.0, -80.0), Vector2(400.0, 30.0), Vector2(400.0, 0.0),
	]
	for direction in [-1.0, 1.0]:
		for displacement in displacements:
			var aim := origin + Vector2(displacement.x * direction, displacement.y)
			for hz in [60, 120, 240]:
				var bolt := CROSSBOW.projectile_scene.instantiate() as Projectile
				add_child(bolt)
				bolt.set_physics_process(false)
				bolt.launch(origin, aim, 1, 0.0, null)
				var flight_time := bolt.flight_time_to(origin, aim)
				var label := "%s @ %d Hz" % [aim - origin, hz]
				_check(bolt._velocity.is_finite() and bolt._gravity_vector().is_finite()
					and is_finite(flight_time) and flight_time > 0.0, label + " nonfinite launch")
				var elapsed := 0.0
				while elapsed < flight_time:
					var delta := minf(1.0 / float(hz), flight_time - elapsed)
					bolt._physics_flight(delta)
					elapsed += delta
				_check(bolt.global_position.distance_to(aim) < 0.02, label + " missed apex position")
				_check(absf(bolt._velocity.y) < 0.05, label + " nonzero vertical apex velocity")
				bolt.free()
	# Bow keeps the existing authored angle, gravity, and semi-implicit integration.
	var arrow := BOW.projectile_scene.instantiate() as Projectile
	add_child(arrow)
	arrow.set_physics_process(false)
	arrow.launch(origin, origin + Vector2(600.0, 0.0), 1, 0.0, null)
	_check(not arrow.apex_at_target, "Bow unexpectedly uses crossbow flight")
	_check(absf(rad_to_deg(arrow._velocity.angle()) + 60.0) < 0.01, "Bow launch angle changed")
	var initial_velocity := arrow._velocity
	var bow_delta := 1.0 / 60.0
	var expected := origin + (initial_velocity + arrow._gravity_vector() * bow_delta) * bow_delta
	arrow._physics_flight(bow_delta)
	_check(arrow.global_position.distance_to(expected) < 0.001, "Bow integration changed")
	arrow.free()


func _stats() -> UnitStatsData:
	var stats := UnitStatsData.new()
	stats.strength = 2
	stats.dex = 2
	stats.con = 999
	return stats


func _check_combat(enemy_id: String, speed: int) -> void:
	GameState.reset_run()
	var stage := STAGE.instantiate()
	stage.sandboxed = true
	add_child(stage)
	var enemy := load("res://assets/units/enemies/%s/%s_unit.tres" % [enemy_id, enemy_id]) as EnemyUnitData
	var player := RosterUnitData.create("Crossbow check", _stats(), CROSSBOW)
	player.is_imago = true
	player.life_stage_id = RosterUnitData.STAGE_IMAGO
	var players: Array[RosterUnitData] = [player]
	var enemies: Array[RosterUnitData] = [RosterUnitData.create_enemy("Target", _stats(), enemy)]
	stage.start_battle(players, enemies)
	stage._set_fast_forward(speed)
	stage.set_physics_process(false)
	stage.player_troop.set_physics_process(false)
	stage.enemy_troop.set_physics_process(false)
	var shooter: Unit = stage.player_troop.get_units()[0]
	var target: Unit = stage.enemy_troop.get_units()[0]
	for unit: Unit in [shooter, target]:
		unit.set_physics_process(false)
		unit._appearance.animation_player.pause()
	shooter.global_position = Vector2(1600.0, 780.0)
	target.global_position = Vector2(2200.0, 780.0)
	target.velocity = Vector2.ZERO
	# Troop discovers its opponent in a deferred _ready callback.
	await get_tree().process_frame
	_check(shooter._troop.get_opponent() == stage.enemy_troop, "Troop opponent not initialized")
	if speed == 1 and enemy_id == "solar_sword":
		_check_aim_and_release(shooter, target)
	for direction in [-1.0, 1.0]:
		for moving in [false, true]:
			shooter._visual.scale.x = direction * absf(shooter._visual.scale.x)
			target.global_position = shooter.global_position + Vector2(direction * 800.0, 0.0)
			target.velocity = Vector2(-direction * 80.0, 0.0) if moving else Vector2.ZERO
			await get_tree().physics_frame
			var origin := shooter._get_ranged_spawn_global()
			var aim := shooter._lead_aim_point(origin, target)
			var bolt := CROSSBOW.projectile_scene.instantiate() as Projectile
			stage.get_node("World").add_child(bolt)
			bolt.launch(origin, aim, 1, 0.0, shooter)
			var before := target.current_hp
			for _frame in 90:
				# Fast-forward scales physics ticks too: game-time delta remains 1/60.
				target.global_position += target.velocity / 60.0
				await get_tree().physics_frame
				if target.current_hp < before or not is_instance_valid(bolt):
					break
			var label := "%s %dx direction=%s moving=%s" % [enemy_id, speed, direction, moving]
			_check(target.current_hp == before - 1, label + " collision did not deal exactly one hit")
			if is_instance_valid(bolt):
				bolt.queue_free()
	stage.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0) and Engine.physics_ticks_per_second == 60,
		"Stage leaked fast-forward timing")
	print("[CROSSBOW] collision ", enemy_id, " ", speed, "x done")


func _check_aim_and_release(shooter: Unit, target: Unit) -> void:
	var origin := shooter._get_ranged_spawn_global()
	var first := shooter._lead_aim_point(origin, target)
	for _sample in 32:
		_check(shooter._lead_aim_point(origin, target).is_equal_approx(first), "Crossbow aim jitters")
	var bolt := CROSSBOW.projectile_scene.instantiate() as Projectile
	var initial_velocity := bolt._compute_launch_velocity(origin, first)
	_check(absf(rad_to_deg(initial_velocity.angle())) <= 12.01, "Crossbow arc exceeds shallow angle")
	bolt.free()
	shooter.combat = BOW.get_combat_profile()
	var bow_first := shooter._lead_aim_point(origin, target)
	var bow_varied := false
	for _sample in 32:
		if not shooter._lead_aim_point(origin, target).is_equal_approx(bow_first):
			bow_varied = true
	_check(bow_varied, "Bow lost its existing aim spread")
	shooter.combat = CROSSBOW.get_combat_profile()
	shooter._ranged_aim = shooter._lead_aim_point(origin, target)
	target.global_position += Vector2(120.0, -10.0)
	target.velocity = Vector2(-60.0, 0.0)
	shooter.global_position.x += 25.0
	# Selected aim target survives a change to the melee/chase target during windup.
	shooter._target = shooter
	origin = shooter._get_ranged_spawn_global()
	var refreshed := shooter._lead_aim_point(origin, target)
	for freed_target in [false, true]:
		if freed_target:
			var vanished := Unit.new()
			shooter._ranged_apex_target = vanished
			shooter._ranged_aim = Vector2(-3000.0, -3000.0)
			vanished.free()
		shooter._spawn_arrow_projectile()
		var emitted := false
		for projectile: Projectile in get_tree().get_nodes_in_group("projectiles"):
			if projectile.owner_unit != shooter:
				continue
			emitted = true
			projectile.set_physics_process(false)
			var flight_time := projectile.flight_time_to(origin, refreshed)
			projectile._physics_flight(flight_time)
			_check(projectile.global_position.distance_to(refreshed) < 0.02,
				"Release used stale aim or wrong target; freed_target=%s" % freed_target)
			projectile.free()
		_check(emitted, "Release did not spawn a crossbow projectile")
