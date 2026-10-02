extends Node2D

## Natural battle spawns: stationary shooters land before firing; throws keep their jump.
const STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const SWORD := preload("res://assets/weapons/sword/sword.tres")
const SPEAR := preload("res://assets/weapons/spear/spear.tres")
const SOLAR_SWORD := preload("res://assets/units/enemies/solar_sword/solar_sword_unit.tres")
const ROSE_THORN := preload("res://assets/units/enemies/rose_thorn/rose_thorn_unit.tres")
const PLAYER_SHOOTERS := [
	preload("res://assets/weapons/crossbow/crossbow.tres"),
	preload("res://assets/weapons/bow/bow.tres"),
	preload("res://assets/weapons/great_bow/great_bow.tres"),
	preload("res://assets/weapons/mortar/mortar.tres"),
	preload("res://assets/weapons/giant_horn/giant_horn.tres"),
]
const ENEMY_SHOOTERS := [
	preload("res://assets/units/enemies/peashooter/peashooter_unit.tres"),
	preload("res://assets/units/enemies/seed_lobber/seed_lobber_unit.tres"),
]

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[GROUNDED-RANGED] " + message)


func _run() -> void:
	for speed in [1, 4]:
		for weapon: WeaponData in PLAYER_SHOOTERS:
			await _run_case(weapon, SOLAR_SWORD, false, true, speed)
		for enemy: EnemyUnitData in ENEMY_SHOOTERS:
			await _run_case(SWORD, enemy, true, true, speed)
		await _run_case(SPEAR, SOLAR_SWORD, false, false, speed)
		await _run_case(SWORD, ROSE_THORN, true, false, speed)
	print("[GROUNDED-RANGED] SUMMARY checks=", _checks, " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _run_case(
	weapon: WeaponData,
	enemy_data: EnemyUnitData,
	check_enemy: bool,
	expect_grounded: bool,
	speed: int
) -> void:
	seed(100126)
	GameState.reset_run()
	var stage := STAGE.instantiate()
	stage.sandboxed = true
	add_child(stage)
	var stats := UnitStatsData.new()
	stats.strength = 2
	stats.dex = 2
	stats.con = 2
	var player := RosterUnitData.create("Grounded release", stats, weapon)
	player.is_imago = true
	player.life_stage_id = RosterUnitData.STAGE_IMAGO
	var players: Array[RosterUnitData] = [player]
	var enemies: Array[RosterUnitData] = [RosterUnitData.create_enemy(
		enemy_data.display_name, enemy_data.stats.duplicate(true), enemy_data)]
	stage.start_battle(players, enemies)
	stage._set_fast_forward(speed)
	var shooter: Unit = stage.player_troop.get_units()[0]
	var label := "%s player speed=%d" % [weapon.display_name, speed]
	if check_enemy:
		shooter = stage.enemy_troop.get_units()[0]
		label = "%s enemy speed=%d" % [enemy_data.display_name, speed]
	_check(not shooter.is_on_floor(), label + " must begin above ground")
	var released := false
	for frame in 600:
		await get_tree().physics_frame
		for projectile: Projectile in get_tree().get_nodes_in_group("projectiles"):
			if projectile.owner_unit != shooter:
				continue
			released = true
			_check(shooter.is_on_floor() == expect_grounded,
				label + " first release grounded=%s; expected=%s" % [
					shooter.is_on_floor(), expect_grounded])
			print("[GROUNDED-RANGED] RELEASE ", label, " frame=", frame,
				" grounded=", shooter.is_on_floor())
			break
		if released:
			break
	_check(released, label + " did not emit a projectile within ten game seconds")
	stage.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0) and Engine.physics_ticks_per_second == 60,
		label + " leaked fast-forward timing")
