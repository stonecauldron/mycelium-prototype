extends Node

const STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const RANGED := ["bow", "crossbow", "sniper", "sling", "mortar", "giant_horn"]
const MELEE := [
	"great_sword", "great_hammer", "warhammer", "spear", "spear_and_shield",
	"halberd", "polehammer", "lance",
]
const FRAMES := 1080


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := 0
	if "--enemy-tuning" in OS.get_cmdline_user_args():
		for ranged_id in ["peashooter", "seed_lobber"]:
			failures += await _shield_case(ranged_id, "stump", "sword", 3, true)
		for enemy_id in ["solar_cleaver", "durian", "rose_thorn", "acorn_knight"]:
			failures += await _melee_case(enemy_id, true)
		print("[RANGE-TUNING] SUMMARY enemy_cases=6 failures=", failures)
		get_tree().quit(1 if failures > 0 else 0)
		return
	if "--edge-cases" in OS.get_cmdline_user_args():
		for enemy_id in ["solar_cleaver", "durian"]:
			failures += await _shield_case("bow", "shield", enemy_id, 3)
		failures += await _shield_case("bow", "umbrella", "solar_sword", 3)
		print("[RANGE-TUNING] SUMMARY cases=3 failures=", failures)
		get_tree().quit(1 if failures > 0 else 0)
		return
	for weapon_id in RANGED:
		failures += await _shield_case(weapon_id, "shield", "solar_sword", 3)
	for enemy_id in ["solar_cleaver", "durian", "acorn_knight"]:
		failures += await _shield_case("bow", "shield", enemy_id, 3)
	for shield_id in ["great_shield", "umbrella"]:
		failures += await _shield_case("bow", shield_id, "solar_sword", 3)
	for weapon_id in MELEE:
		failures += await _melee_case(weapon_id)
	print("[RANGE-TUNING] SUMMARY cases=19 failures=", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _shield_case(
	ranged_id: String, shield_id: String, enemy_id: String, count: int, mirrored: bool = false
) -> int:
	seed(20260905)
	var stage := STAGE.instantiate()
	stage.sandboxed = true
	add_child(stage)
	await get_tree().process_frame
	var players: Array[RosterUnitData] = []
	var enemies: Array[RosterUnitData] = []
	if mirrored:
		enemies.assign([_enemy(ranged_id), _enemy(shield_id)])
		for _i in count:
			players.append(_player(enemy_id))
	else:
		players.assign([_player(ranged_id), _player(shield_id)])
		for _i in count:
			enemies.append(_enemy(enemy_id))
	stage.start_battle(players, enemies)
	stage._set_fast_forward(1)
	var defenders: Troop = stage.enemy_troop if mirrored else stage.player_troop
	var attackers: Troop = stage.player_troop if mirrored else stage.enemy_troop
	var facing := defenders.get_facing()
	var rear: Unit = defenders.get_units()[0]
	var shield: Unit = defenders.get_units()[1]
	var no_knockback := "--no-knockback" in OS.get_cmdline_user_args()
	if no_knockback:
		for unit: Unit in stage.player_troop.get_units() + stage.enemy_troop.get_units():
			unit.combat = unit.combat.duplicate(true)
			unit.combat.knockback_force = 0.0
	var engaged := false
	var kite_frames := 0
	var first_kite_gap := -1.0
	var rear_knockback_frames := 0
	var shield_knockback_frames := 0
	var samples: Array[Vector2] = []
	var whole_squad_retreat := false
	var rear_max_back := 0.0
	var shield_max_back := 0.0
	for _frame in FRAMES:
		await get_tree().physics_frame
		if not is_instance_valid(rear) or not is_instance_valid(shield):
			break
		var front: Unit = attackers.get_frontmost_living_unit()
		if front == null:
			break
		var gap := facing * (front.global_position.x - shield.global_position.x)
		if rear._in_knockback:
			rear_knockback_frames += 1
		if shield._in_knockback:
			shield_knockback_frames += 1
		if gap < 200.0:
			engaged = true
		if facing * rear.velocity.x < -8.0 and not rear._in_knockback:
			kite_frames += 1
			if first_kite_gap < 0.0:
				first_kite_gap = gap
				print("[RANGE-TUNING] first_kite=", ranged_id, "+", shield_id, " vs ", enemy_id,
					" rear_to_shield_x=", facing * (shield.global_position.x - rear.global_position.x),
					" rear_to_target=", rear.global_position.distance_to(rear._target.global_position),
					" rear_damage_taken=", rear.damage_taken, " shield_damage_taken=", shield.damage_taken)
		if engaged:
			samples.append(Vector2(rear.global_position.x, shield.global_position.x) * facing)
			if samples.size() > 60:
				var displacement: Vector2 = samples.back() - samples.pop_front()
				rear_max_back = maxf(rear_max_back, -displacement.x)
				shield_max_back = maxf(shield_max_back, -displacement.y)
				if displacement.x < -40.0 and displacement.y < -40.0:
					whole_squad_retreat = true
	var alive := is_instance_valid(rear) and is_instance_valid(shield)
	var damage: int = rear.damage_dealt if is_instance_valid(rear) else 0
	var passed := alive and engaged and damage > 0 and not whole_squad_retreat
	print("[RANGE-TUNING] shield_case=", ranged_id, "+", shield_id, " vs ", count, " ", enemy_id,
		" mirrored=", mirrored,
		" result=", "PASS" if passed else "FAIL", " engaged=", engaged, " alive=", alive,
		" ranged_damage=", damage, " kite_frames=", kite_frames,
		" first_kite_shield_gap=", snappedf(first_kite_gap, 0.1),
		" knockback_frames=", Vector2i(rear_knockback_frames, shield_knockback_frames),
		" no_knockback=", no_knockback,
		" max_one_second_back=", Vector2(rear_max_back, shield_max_back),
		" whole_squad_retreat=", whole_squad_retreat)
	stage.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return 0 if passed else 1


func _melee_case(weapon_id: String, mirrored: bool = false) -> int:
	seed(20260905)
	var stage := STAGE.instantiate()
	stage.sandboxed = true
	add_child(stage)
	await get_tree().process_frame
	var players: Array[RosterUnitData] = [_player("sword" if mirrored else weapon_id)]
	var enemies: Array[RosterUnitData] = [_enemy(weapon_id if mirrored else "solar_sword")]
	stage.start_battle(players, enemies)
	stage._set_fast_forward(1)
	var attackers: Troop = stage.enemy_troop if mirrored else stage.player_troop
	var unit: Unit = attackers.get_units()[0]
	var melee_frames := 0
	var charge_frames := 0
	for _frame in FRAMES:
		await get_tree().physics_frame
		if not is_instance_valid(unit):
			break
		if unit._charge_phase == Unit.ChargePhase.RUSHING:
			charge_frames += 1
		elif unit._combat_phase == Unit.CombatPhase.ATTACKING and not unit._projectile_attack_active:
			melee_frames += 1
	var damage: int = unit.damage_dealt if is_instance_valid(unit) else 0
	var attack_seen := charge_frames > 0 if weapon_id in ["lance", "acorn_knight"] else melee_frames > 0
	var passed := damage > 0 and attack_seen
	print("[RANGE-TUNING] melee_case=", weapon_id, " result=", "PASS" if passed else "FAIL",
		" mirrored=", mirrored,
		" damage=", damage, " melee_frames=", melee_frames, " charge_frames=", charge_frames)
	stage.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return 0 if passed else 1


func _player(weapon_id: String) -> RosterUnitData:
	var weapon := load("res://assets/weapons/%s/%s.tres" % [weapon_id, weapon_id]) as WeaponData
	var unit := RosterUnitData.create(weapon.display_name, _stats(), weapon, UnitStatsData.PowerTier.COMMON)
	unit.is_imago = true
	unit.life_stage_id = RosterUnitData.STAGE_IMAGO
	return unit


func _enemy(enemy_id: String) -> RosterUnitData:
	var data := load("res://assets/units/enemies/%s/%s_unit.tres" % [enemy_id, enemy_id]) as EnemyUnitData
	return RosterUnitData.create_enemy(data.display_name, _stats(), data)


func _stats() -> UnitStatsData:
	var stats := UnitStatsData.new()
	stats.strength = 5
	stats.dex = 5
	stats.con = 99
	return stats
