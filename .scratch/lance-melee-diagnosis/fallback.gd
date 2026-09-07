extends Node

const STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const STEP := 1.0 / 60.0

var _checks := 0
var _failures := 0
var _label := ""


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for mirrored in [false, true]:
		for scenario in ["close", "behind", "boundary", "windup_closes", "rush", "shield"]:
			await _run_case(mirrored, scenario)
	print("[LANCE-FALLBACK] SUMMARY checks=", _checks, " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _run_case(mirrored: bool, scenario: String) -> void:
	seed(20260905)
	_label = ("Acorn Knight" if mirrored else "Lance") + " " + scenario
	var stage := STAGE.instantiate()
	stage.sandboxed = true
	add_child(stage)
	await get_tree().process_frame
	var player_id := "lance"
	var enemy_id := "solar_sword"
	if mirrored:
		player_id = "shield" if scenario == "shield" else "sword"
		enemy_id = "acorn_knight"
	elif scenario == "shield":
		enemy_id = "stump"
	var players: Array[RosterUnitData] = [_player(player_id)]
	var enemies: Array[RosterUnitData] = [_enemy(enemy_id)]
	stage.start_battle(players, enemies)
	stage._set_fast_forward(1)
	for actor: Unit in stage.player_troop.get_units() + stage.enemy_troop.get_units():
		# Exercise real AI selection, tweens, physics overlaps and damage at fixed distances.
		actor.set_physics_process(false)
	var subject: Unit = (stage.enemy_troop if mirrored else stage.player_troop).get_units()[0]
	var target: Unit = (stage.player_troop if mirrored else stage.enemy_troop).get_units()[0]
	var facing := subject._troop.get_facing()
	var distance := 60.0
	if scenario == "behind":
		distance = -60.0
	elif scenario == "boundary":
		distance = subject._get_melee_engage_range()
	elif scenario in ["windup_closes", "rush", "shield"]:
		distance = subject._get_melee_engage_range() + 1.0
	subject.global_position = Vector2(3500.0, 750.0)
	target.global_position = subject.global_position + Vector2(facing * distance, 0.0)
	subject._process_combat(STEP)
	if scenario in ["windup_closes", "rush", "shield"]:
		_check(subject._charge_phase == Unit.ChargePhase.WINDUP, "winds up outside melee range")
		subject._process_lance_charge(STEP)
		_check(subject._charge_phase == Unit.ChargePhase.WINDUP and not subject._hitbox.monitoring,
			"keeps winding up while target stays outside melee range")
		if scenario == "windup_closes":
			target.global_position = subject.global_position + Vector2(facing * 60.0, 0.0)
			subject._process_lance_charge(STEP)
		else:
			subject._process_lance_charge(subject._effective_attack_interval())
			_check(subject._charge_phase == Unit.ChargePhase.RUSHING and subject._hitbox._is_charge_strike,
				"completes distant windup as a charge")
			# Bring the hurtbox into the running charge; retain actual Area2D detection.
			target.global_position = subject.global_position + Vector2(facing * 100.0, 0.0)
	var charging := scenario in ["rush", "shield"]
	if not charging:
		_check(subject._charge_phase == Unit.ChargePhase.NONE
			and subject._combat_phase == Unit.CombatPhase.ATTACKING and subject._hitbox.monitoring,
			"starts ordinary melee with an active hitbox")
		_check(is_zero_approx(subject._charge_timer), "clears pending charge timer")
		_check(is_zero_approx(subject._attack_timer), "does not add a cooldown before the strike")
	var hp_before := target.current_hp
	var expected_damage := subject._get_attack_damage(false)
	if scenario == "shield":
		expected_damage = maxi(roundi(float(expected_damage) * 0.5), 0)
	expected_damage = maxi(roundi(float(expected_damage) * target.combat.incoming_damage_multiplier), 1)
	for _frame in 24:
		await get_tree().physics_frame
	_check(hp_before - target.current_hp == expected_damage, "lands exactly one hit")
	_check(subject.damage_dealt == expected_damage, "credits damage to the attacker")
	if scenario == "rush":
		_check(subject._charge_phase == Unit.ChargePhase.RUSHING, "continues charging after an unshielded hit")
		subject._end_lance_charge()
	else:
		_check(subject._charge_phase == Unit.ChargePhase.NONE
			and subject._combat_phase == Unit.CombatPhase.READY, "finishes ready")
		_check(is_equal_approx(subject._attack_timer, subject._effective_attack_interval()),
			"applies normal cooldown after the hit")
		_check(not subject._hitbox.monitoring, "disables hitbox after the attack")
	print("[LANCE-FALLBACK] completed ", _label)
	stage.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("[LANCE-FALLBACK] FAIL ", _label, " ", label)


func _player(id: String) -> RosterUnitData:
	var weapon := load("res://assets/weapons/%s/%s.tres" % [id, id]) as WeaponData
	var unit := RosterUnitData.create(id, _stats(), weapon, UnitStatsData.PowerTier.COMMON)
	unit.is_imago = true
	unit.life_stage_id = RosterUnitData.STAGE_IMAGO
	return unit


func _enemy(id: String) -> RosterUnitData:
	var data := load("res://assets/units/enemies/%s/%s_unit.tres" % [id, id]) as EnemyUnitData
	return RosterUnitData.create_enemy(id, _stats(), data)


func _stats() -> UnitStatsData:
	var stats := UnitStatsData.new()
	stats.strength = 5
	stats.dex = 5
	stats.con = 99
	return stats
