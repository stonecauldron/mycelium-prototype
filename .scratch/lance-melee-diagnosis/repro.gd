extends Node

const STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const LANCE := preload("res://assets/weapons/lance/lance.tres")
const ENEMY := preload("res://assets/units/enemies/solar_sword/solar_sword_unit.tres")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(20260905)
	var stage := STAGE.instantiate()
	stage.sandboxed = true
	add_child(stage)
	await get_tree().process_frame
	var player := RosterUnitData.create("Lance", _stats(), LANCE, UnitStatsData.PowerTier.COMMON)
	player.is_imago = true
	player.life_stage_id = RosterUnitData.STAGE_IMAGO
	var players: Array[RosterUnitData] = [player]
	var enemies: Array[RosterUnitData] = [RosterUnitData.create_enemy("Solar Sword", _stats(), ENEMY)]
	stage.start_battle(players, enemies)
	stage._set_fast_forward(1)
	var lance: Unit = stage.player_troop.get_units()[0]
	var enemy: Unit = stage.enemy_troop.get_units()[0]
	lance.global_position = Vector2(3500.0, 750.0)
	enemy.global_position = Vector2(3560.0, 750.0)
	var args := OS.get_cmdline_user_args()
	if "--no-knockback" in args:
		enemy.combat = enemy.combat.duplicate(true)
		enemy.combat.knockback_force = 0.0
	if "--passive-enemy" in args:
		enemy.set_physics_process(false)
	if "--melee-stance" in args:
		lance.roster_data.forced_engagement_stance = WeaponData.EngagementStance.PRESS_FORWARD
	if "--trace" in args:
		lance.health_changed.connect(func(_hp: int, _maximum: int) -> void:
			print("[LANCE-MELEE] incoming_hit charge_phase=", lance._charge_phase,
				" windup_remaining=", snappedf(lance._charge_timer, 0.001),
				" hitbox_active=", lance._hitbox.monitoring)
		)
	var windups := 0
	var rush_frames := 0
	var melee_frames := 0
	var last_phase := Unit.ChargePhase.NONE
	for frame in 600:
		await get_tree().physics_frame
		if lance._charge_phase == Unit.ChargePhase.WINDUP and last_phase != Unit.ChargePhase.WINDUP:
			windups += 1
		last_phase = lance._charge_phase
		if lance._charge_phase == Unit.ChargePhase.RUSHING:
			rush_frames += 1
		if lance._combat_phase == Unit.CombatPhase.ATTACKING and lance._charge_phase == Unit.ChargePhase.NONE:
			melee_frames += 1
	print("[LANCE-MELEE] windups=", windups, " rush_frames=", rush_frames,
		" melee_frames=", melee_frames, " damage_dealt=", lance.damage_dealt,
		" damage_taken=", lance.damage_taken, " enemy_hp_lost=", enemy.get_effective_max_hp() - enemy.current_hp)
	var connected := lance.damage_dealt > 0 and enemy.current_hp < enemy.get_effective_max_hp()
	print("[LANCE-MELEE] ", "PASS close_attack_connects" if connected else "FAIL windup_without_damage")
	get_tree().quit(0 if connected else 1)


func _stats() -> UnitStatsData:
	var stats := UnitStatsData.new()
	stats.strength = 5
	stats.dex = 5
	stats.con = 99
	return stats
