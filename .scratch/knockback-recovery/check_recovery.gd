extends Node

const STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const SWORD := preload("res://assets/weapons/sword/sword.tres")
const FORCE := 280.0

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("[KNOCKBACK] " + message)


func _stats() -> UnitStatsData:
	var stats := UnitStatsData.new()
	stats.strength = 2
	stats.dex = 2
	stats.con = 999
	return stats


func _hit(unit: Unit) -> void:
	unit.take_damage(1, unit.global_position - Vector2(100.0, 0.0), FORCE)


func _run() -> void:
	for speed in [1, 4]:
		for enemy_id in ["solar_sword", "peashooter"]:
			await _run_case(enemy_id, speed)
	print("[KNOCKBACK] SUMMARY cases=4 failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _run_case(enemy_id: String, speed: int) -> void:
	GameState.reset_run()
	seed(93026)
	var stage := STAGE.instantiate()
	stage.sandboxed = true
	add_child(stage)
	await get_tree().process_frame
	var data := load("res://assets/units/enemies/%s/%s_unit.tres" % [enemy_id, enemy_id]) as EnemyUnitData
	var players: Array[RosterUnitData] = [RosterUnitData.create("Passive target", _stats(), SWORD)]
	var enemies: Array[RosterUnitData] = [RosterUnitData.create_enemy("Under test", _stats(), data)]
	stage.start_battle(players, enemies)
	stage._set_fast_forward(speed)
	stage.player_troop.set_physics_process(false)
	stage.enemy_troop.set_physics_process(false)
	var target: Unit = stage.player_troop.get_units()[0]
	var unit: Unit = stage.enemy_troop.get_units()[0]
	target._attack_timer = 1000.0
	unit._attack_timer = 1000.0
	for _frame in 40:
		await get_tree().physics_frame
		if target.is_on_floor() and unit.is_on_floor():
			break
	target.set_physics_process(false)
	var label := "%s %dx" % [enemy_id, speed]
	_check(unit.is_on_floor(), label + " did not settle on the combat floor")
	var ground_y := unit.global_position.y
	var start_hp := unit.current_hp
	var hits := 0
	var cooldown_before := unit._attack_timer
	_hit(unit)
	hits += 1
	_check(unit._in_knockback, label + " initial hit did not knock back")
	var landed := false
	var airborne_frames := 0
	for _frame in 120:
		await get_tree().physics_frame
		if not unit._in_knockback:
			landed = true
			break
		airborne_frames += 1
		var velocity_before := unit.velocity
		_hit(unit)
		hits += 1
		_check(unit.velocity.is_equal_approx(velocity_before), label + " hit relaunched an airborne unit")
	_check(landed and airborne_frames > 0, label + " rapid hits prevented landing")
	_check(unit._attack_timer < cooldown_before - 0.1, label + " cooldown did not advance during knockback")
	var protected_frames := 0
	var protection_expired := false
	if landed:
		# Keep hitting on every physics step: damage must land during the grace period,
		# and knockback must become available again after that bounded protection.
		for _frame in 90:
			_hit(unit)
			hits += 1
			if unit._in_knockback:
				protection_expired = true
				break
			protected_frames += 1
			await get_tree().physics_frame
	_check(protected_frames >= 10, label + " landing did not provide a useful recovery window")
	_check(protection_expired, label + " recovery protection never expired")
	_check(start_hp - unit.current_hp == hits, label + " knockback protection suppressed damage")

	# Give the enemy a reachable, passive opponent while hits continue every step.
	# Follow horizontally to isolate recovery from chase/range tuning.
	# For ranged attacks, an owned projectile proves the windup reached release:
	# this artificial target movement can dodge a correctly launched ballistic shot.
	unit._attack_timer = 0.1
	var ranged := unit.combat.uses_projectile()
	var distance := 400.0 if ranged else unit._get_melee_engage_range() - 8.0
	var damage_before := unit.damage_dealt
	var attacks_seen := 0
	var projectile_emitted := false
	var previous_phase := unit._combat_phase
	for _frame in 600:
		target.global_position = Vector2(unit.global_position.x - distance, ground_y)
		_hit(unit)
		hits += 1
		await get_tree().physics_frame
		if unit._combat_phase == Unit.CombatPhase.ATTACKING and previous_phase != unit._combat_phase:
			attacks_seen += 1
		previous_phase = unit._combat_phase
		if ranged:
			for projectile: Projectile in get_tree().get_nodes_in_group("projectiles"):
				if projectile.owner_unit == unit:
					projectile_emitted = true
					break
		if projectile_emitted or unit.damage_dealt > damage_before:
			break
	_check(projectile_emitted if ranged else unit.damage_dealt > damage_before,
		label + " could not retaliate under rapid hits")
	_check(start_hp - unit.current_hp == hits, label + " sustained hits lost damage")
	_check(unit.current_hp > 0 and target.current_hp > 0, label + " test unexpectedly killed a combatant")
	print("[KNOCKBACK] ", label, " landing_frames=", airborne_frames,
		" protected_frames=", protected_frames, " hits=", hits,
		" attacks=", attacks_seen, " projectile_emitted=", projectile_emitted,
		" retaliation_damage=", unit.damage_dealt - damage_before)
	stage.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0) and Engine.physics_ticks_per_second == 60,
		label + " leaked fast-forward timing")
