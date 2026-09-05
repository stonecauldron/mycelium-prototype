extends Node

const STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const STEP := 1.0 / 60.0

var _failures := 0
var _checks := 0
var _case_label := ""


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for mirrored in [false, true]:
		for slot in [0, 1]:
			await _run_case(mirrored, slot)
	print("[RETREAT-STATE] SUMMARY checks=", _checks, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _run_case(mirrored: bool, slot: int) -> void:
	seed(20260905)
	_case_label = ("enemy" if mirrored else "player") + " slot=" + str(slot)
	var stage := STAGE.instantiate()
	stage.sandboxed = true
	add_child(stage)
	await get_tree().process_frame
	var players: Array[RosterUnitData] = [_player("bow"), _player("bow"), _player("shield")]
	var enemies: Array[RosterUnitData] = [_enemy("solar_sword"), _enemy("solar_sword")]
	if mirrored:
		players.assign([_player("sword"), _player("sword")])
		enemies.assign([_enemy("peashooter"), _enemy("peashooter"), _enemy("stump")])
	stage.start_battle(players, enemies)
	stage._set_fast_forward(1)
	# Freeze world motion and drive real attack/AI callbacks at controlled distances.
	for actor: Unit in stage.player_troop.get_units() + stage.enemy_troop.get_units():
		actor.set_physics_process(false)
	var defenders: Troop = stage.enemy_troop if mirrored else stage.player_troop
	var attackers: Troop = stage.player_troop if mirrored else stage.enemy_troop
	var subject: Unit = defenders.get_units()[slot]
	var threat: Unit = attackers.get_units()[0]
	var replacement: Unit = attackers.get_units()[1]
	var facing := defenders.get_facing()
	var entry := 80.0 if slot == 0 else 48.0
	subject.global_position = Vector2(2000.0, 700.0)
	_place_threat(subject, replacement, 1500.0, facing)
	_place_threat(subject, threat, entry + 20.0, facing)

	# Finishing a real shot must not activate the retreat continuation band.
	subject._process_combat(STEP)
	_check(subject._combat_phase == Unit.CombatPhase.ATTACKING, "starts shot")
	subject._process_ranged_attack(Unit.RANGED_RELEASE_DELAY)
	_check(subject._throw_released, "releases projectile")
	subject._process_ranged_attack(Unit.RANGED_RECOVERY_TIME)
	_check(subject._combat_phase == Unit.CombatPhase.READY, "finishes shot ready")
	subject._process_combat(STEP)
	_check(is_zero_approx(subject.velocity.x), "holds after shot outside entry range")

	subject._attack_timer = 0.0
	subject._process_combat(STEP)
	subject._cancel_attack()
	_check(subject._combat_phase == Unit.CombatPhase.READY, "cancels attack ready")
	subject._attack_timer = 10.0
	subject._process_combat(STEP)
	_check(is_zero_approx(subject.velocity.x), "holds after cancellation")
	subject._return_home()
	subject._process_combat(STEP)
	_check(is_zero_approx(subject.velocity.x), "Home return does not activate retreat buffer")

	_place_threat(subject, threat, entry + 0.5, facing)
	subject._process_combat(STEP)
	_check(is_zero_approx(subject.velocity.x), "holds just outside entry range")
	_place_threat(subject, threat, entry, facing)
	subject._process_combat(STEP)
	_check(facing * subject.velocity.x < 0.0, "retreats at entry range")
	_place_threat(subject, threat, entry + 23.5, facing)
	subject._process_combat(STEP)
	_check(facing * subject.velocity.x < 0.0, "continues retreat inside 24 px buffer")
	_place_threat(subject, threat, entry + 24.0, facing)
	subject._process_combat(STEP)
	_check(is_zero_approx(subject.velocity.x), "stops at entry plus 24 px")
	_place_threat(subject, threat, entry + 20.0, facing)
	subject._process_combat(STEP)
	_check(is_zero_approx(subject.velocity.x), "does not restart inside continuation band")

	# An unrelated replacement target must meet the normal entry threshold.
	_place_threat(subject, threat, entry, facing)
	subject._process_combat(STEP)
	_place_threat(subject, threat, 1500.0, facing)
	_place_threat(subject, replacement, entry + 20.0, facing)
	subject._process_combat(STEP)
	_check(subject._target == replacement, "acquires replacement target")
	_check(is_zero_approx(subject.velocity.x), "replacement does not inherit retreat buffer")
	_place_threat(subject, replacement, entry, facing)
	subject._process_combat(STEP)
	_check(facing * subject.velocity.x < 0.0, "retreats from replacement at entry range")
	_place_threat(subject, replacement, 2000.0, facing)
	_place_threat(subject, threat, 2100.0, facing)
	subject._process_combat(STEP)
	_check(subject._target == null and facing * subject.velocity.x > 0.0, "resumes march after target loss")
	_place_threat(subject, replacement, entry + 20.0, facing)
	subject._process_combat(STEP)
	_check(is_zero_approx(subject.velocity.x), "reacquisition uses normal entry range")
	print("[RETREAT-STATE] completed ", _case_label)
	stage.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _place_threat(subject: Unit, threat: Unit, distance: float, facing: float) -> void:
	threat.global_position = subject.global_position + Vector2(facing * distance, 0.0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("[RETREAT-STATE] FAIL ", _case_label, " ", label)


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
