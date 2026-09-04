extends Node

const _STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const _ENEMY := preload("res://assets/units/enemies/solar_sword/solar_sword_unit.tres")
const _IDS := ["warhammer", "polehammer", "sling", "sword_and_shield", "mace_and_shield", "spear_and_shield"]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameState.reset_run()
	var failures := 0
	for speed in [1, 4]:
		for id in _IDS:
			seed(12345)
			GameState.combat_fast_forward = speed
			var stage := _STAGE.instantiate()
			add_child(stage)
			var weapon := load("res://assets/weapons/%s/%s.tres" % [id, id]) as WeaponData
			var player_stats := UnitStatsData.new()
			player_stats.strength = 12
			player_stats.dex = 12
			player_stats.con = 99
			var roster := RosterUnitData.create("Weapon test", player_stats, weapon)
			roster.is_imago = true
			roster.life_stage_id = RosterUnitData.STAGE_IMAGO
			var enemy_stats := UnitStatsData.new()
			enemy_stats.strength = 1
			enemy_stats.con = 99
			var foe := RosterUnitData.create_enemy("Target", enemy_stats, _ENEMY)
			var players: Array[RosterUnitData] = [roster]
			var enemies: Array[RosterUnitData] = [foe]
			stage.start_battle(players, enemies)
			var fighter: Unit = stage.player_troop.get_units()[0]
			var saw_projectile := false
			var saw_shield_throw := false
			var shield_lost := false
			var game_time := 0.0
			while game_time < 18.0:
				await get_tree().physics_frame
				game_time += 1.0 / 60.0
				if not is_instance_valid(fighter):
					break
				for projectile in get_tree().get_nodes_in_group("projectiles"):
					if projectile.owner_unit == fighter:
						saw_projectile = true
				if weapon.offhand_appearance_scene != null:
					if not fighter._appearance.offhand_mount.is_visible_in_tree():
						shield_lost = true
					if not fighter._appearance.weapon_mount.visible:
						saw_shield_throw = true
			var dealt := fighter.damage_dealt if is_instance_valid(fighter) else 0
			var passed := dealt > 0 and not shield_lost
			if weapon.uses_projectile():
				passed = passed and saw_projectile
			if id == "spear_and_shield":
				passed = passed and saw_shield_throw
			print("COMBAT ", speed, "x ", id, ": ", "PASS" if passed else "FAIL",
				" damage=", dealt, " projectile=", saw_projectile, " shield_throw=", saw_shield_throw)
			if not passed:
				failures += 1
			stage.queue_free()
			await get_tree().process_frame
			await get_tree().process_frame
			if not is_equal_approx(Engine.time_scale, 1.0) or Engine.physics_ticks_per_second != 60:
				failures += 1
				push_error("Combat timing not restored")
	print("COMBAT SMOKE: 12 scenarios, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
