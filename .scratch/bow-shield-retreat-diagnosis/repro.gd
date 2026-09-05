extends Node

const STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const BOW := preload("res://assets/weapons/bow/bow.tres")
const SHIELD := preload("res://assets/weapons/shield/shield.tres")
const ENEMY := preload("res://assets/units/enemies/solar_sword/solar_sword_unit.tres")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(20260905)
	var args := OS.get_cmdline_user_args()
	var stage := STAGE.instantiate()
	stage.sandboxed = true
	add_child(stage)
	await get_tree().process_frame
	var players: Array[RosterUnitData] = [
		_player("Bow 1", BOW), _player("Bow 2", BOW), _player("Shield", SHIELD),
	]
	if "--minimal" in args:
		players.remove_at(1)
	var enemy_stats := UnitStatsData.new()
	enemy_stats.strength = 5
	enemy_stats.dex = 5
	enemy_stats.con = 99
	var enemies: Array[RosterUnitData] = [
		RosterUnitData.create_enemy("Solar Sword", enemy_stats, ENEMY),
	]
	stage.start_battle(players, enemies)
	stage._set_fast_forward(1)
	var units: Array[Unit] = stage.player_troop.get_units()
	var enemy: Unit = stage.enemy_troop.get_units()[0]
	if "--no-knockback" in args:
		for unit: Unit in units + [enemy]:
			unit.combat = unit.combat.duplicate(true)
			unit.combat.knockback_force = 0.0
	if "--short-skirmish" in args:
		for unit in units:
			if unit.weapon == BOW:
				unit.combat = unit.combat.duplicate(true)
				unit.combat.skirmish_distance = 48.0
	var retreat_frames := 0
	var max_retreat_frames := 0
	var contact_seen := false
	var snapshots: Array[Vector3] = []
	var displacement := Vector3.ZERO
	var whole_squad_moved_back := false
	var anchor_frozen := false
	var first_kite_seen := false
	var first_shield_back_seen := false
	var shield_knockback_frames := 0
	for frame in 900:
		await get_tree().physics_frame
		if not is_instance_valid(enemy) or stage.player_troop.get_living_unit_count() != players.size():
			break
		var shield: Unit = units.back()
		var gap := enemy.global_position.x - shield.global_position.x
		if "--fixed-anchor" in args and gap < 500.0 and not anchor_frozen:
			stage.player_troop.set_physics_process(false)
			stage.player_troop.flag_bearer.stop()
			anchor_frozen = true
		if shield._in_knockback:
			shield_knockback_frames += 1
		if not first_kite_seen and units[0].velocity.x < -8.0 and not units[0]._in_knockback:
			first_kite_seen = true
			print("[BOW-SHIELD] first_bow_retreat frame=", frame,
				" enemy_bow_distance=", units[0].global_position.distance_to(enemy.global_position),
				" enemy_shield_gap=", gap, " shield_damage_taken=", shield.damage_taken,
				" bow_threshold=", units[0]._preferred_skirmish_distance(),
				" bow_phase=", units[0]._combat_phase)
		if not first_shield_back_seen and shield.velocity.x < -8.0 and not shield._in_knockback:
			first_shield_back_seen = true
			print("[BOW-SHIELD] first_shield_retreat frame=", frame,
				" x=", shield.global_position.x, " hold_x=", shield._get_hold_line_global().x,
				" enemy_shield_gap=", gap, " shield_damage_taken=", shield.damage_taken)
		if gap < 100.0:
			contact_seen = true
		if contact_seen:
			snapshots.append(Vector3(units[0].global_position.x, units[1].global_position.x, shield.global_position.x))
			if snapshots.size() > 60:
				displacement = snapshots.back() - snapshots.pop_front()
				whole_squad_moved_back = displacement.x < -40.0 and displacement.y < -40.0 and displacement.z < -40.0
		var all_retreat := contact_seen
		for unit in units:
			all_retreat = all_retreat and unit.velocity.x < -8.0 and not unit._in_knockback
		if all_retreat:
			retreat_frames += 1
			max_retreat_frames = maxi(max_retreat_frames, retreat_frames)
		else:
			retreat_frames = 0
		if frame % 60 == 0:
			print("[BOW-SHIELD] frame=", frame, " gap=", snappedf(gap, 0.1),
				" bow1_x=", snappedf(units[0].global_position.x, 0.1),
				" slot1_x=", snappedf(units[1].global_position.x, 0.1),
				" shield_x=", snappedf(shield.global_position.x, 0.1),
				" vx=", Vector3(units[0].velocity.x, units[1].velocity.x, shield.velocity.x),
				" flag_x=", snappedf(stage.player_troop.get_flag_global_x(), 0.1),
				" shield_home_x=", snappedf(shield._get_home_global().x, 0.1))
		if whole_squad_moved_back:
			break
	print("[BOW-SHIELD] contact_seen=", contact_seen,
		" consecutive_whole_squad_retreat_frames=", max_retreat_frames,
		" one_second_displacement=", displacement,
		" shield_knockback_frames=", shield_knockback_frames)
	if whole_squad_moved_back:
		print("[BOW-SHIELD] FAIL whole_squad_retreats_with_living_shield")
		get_tree().quit(1)
	else:
		print("[BOW-SHIELD] PASS symptom_not_observed")
		get_tree().quit(0)


func _player(label: String, weapon_data: WeaponData) -> RosterUnitData:
	var stats := UnitStatsData.new()
	stats.strength = 5
	stats.dex = 5
	stats.con = 99
	var unit := RosterUnitData.create(label, stats, weapon_data, UnitStatsData.PowerTier.COMMON)
	unit.is_imago = true
	unit.life_stage_id = RosterUnitData.STAGE_IMAGO
	return unit
