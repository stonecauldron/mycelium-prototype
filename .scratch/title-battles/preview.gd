extends Node

var _failures: int = 0
var _damage_seen: bool = false


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		_failures += 1


func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.scratch/title-battles/" + filename)


func _wait_for_phase(battle: Node, phase: int, seconds: float = 60.0) -> bool:
	for i in ceili(seconds * 20.0):
		if battle._phase == phase:
			return true
		await get_tree().create_timer(0.05).timeout
	return false


func _check_entrance(battle: Node) -> void:
	var offscreen := true
	var children := 0
	var adults := 0
	for unit in battle._all_living_units():
		var facing: float = unit._troop.get_facing()
		if facing * (unit.global_position.x - battle._screen_edge(-facing)) >= 0.0:
			offscreen = false
		if unit.roster_data.enemy_unit_data == null:
			if unit.roster_data.is_adult_stage():
				adults += 1
			else:
				children += 1
	_check(offscreen, "New armies start outside opposite screen edges")
	_check(children > 0 and adults > 0, "Matchup includes children and adults")


func _verify_winner_exit(battle: Node, enemy_wins: bool) -> void:
	var loser: Troop = battle._player_troop if enemy_wins else battle._enemy_troop
	var winner: Troop = battle._enemy_troop if enemy_wins else battle._player_troop
	var survivors := winner.get_living_units()
	_check(not survivors.is_empty(), "Winning side has survivors")
	for unit in loser.get_living_units():
		unit.take_damage(10000, Vector2.ZERO, 0.0, null, WeaponData.DamageType.BLUNT)
	_check(await _wait_for_phase(battle, battle.Phase.EXITING, 2.0), "Wipe triggers victory march")
	var survivor: Unit = survivors.front()
	var start_x := survivor.global_position.x
	var round_index: int = battle._round_index
	await get_tree().create_timer(0.75).timeout
	_check(winner.get_facing() * (survivor.global_position.x - start_x) > 100.0,
		"Enemy winners march left" if enemy_wins else "Player winners march right")
	_check(battle._round_index == round_index, "Next matchup waits for departing winners")
	if not enemy_wins:
		await _capture("victory-march.png")
	_check(await _wait_for_phase(battle, battle.Phase.INTERMISSION, 15.0), "Winners finish marching without hitting edge walls")
	var all_out := true
	for unit in survivors:
		var facing := winner.get_facing()
		if facing * (unit.global_position.x - battle._screen_edge(facing)) < 200.0:
			all_out = false
	_check(all_out, "Entire winning side clears the opposite screen edge")
	_check(await _wait_for_phase(battle, battle.Phase.ENTERING, 2.0), "Next matchup walks in")
	_check_entrance(battle)


func _run() -> void:
	var title: Control = load("res://assets/title/title.tscn").instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	var battle: SubViewportContainer = title.get_node("TitleBattle")
	var day := GameState.current_day
	var biomass := GameState.biomass.amount
	var troop := GameState.troop
	var physics_ticks := Engine.physics_ticks_per_second
	_check_entrance(battle)
	var first_player: Unit = battle._player_troop.get_units().back()
	var start_position := first_player.position
	for unit in battle._enemy_troop.get_units():
		unit.health_changed.connect(func(current: int, maximum: int) -> void:
			if current < maximum:
				_damage_seen = true
		)
	await get_tree().create_timer(1.8).timeout
	await _capture("entrance.png")
	_check(await _wait_for_phase(battle, battle.Phase.FIGHTING, 8.0), "Both armies enter before combat starts")
	await get_tree().create_timer(2.5).timeout
	_check(not is_instance_valid(first_player) or first_player.position != start_position, "Melee units advance into combat")
	_check(_damage_seen, "Combat deals damage")
	_check(battle.get_node("Viewport").world_2d != get_viewport().world_2d, "Demo has isolated physics")
	print("Battle rect: ", battle.get_rect(), "; viewport: ", battle.get_node("Viewport").size)
	await _capture("title.png")
	title.get_node("%CreditsButton").pressed.emit()
	await get_tree().create_timer(0.3).timeout
	_check(title.get_node("%CreditsPage").visible, "Credits open")
	await _capture("credits.png")
	title.get_node("%CreditsBackButton").pressed.emit()
	var menu: RunMenu = title.get_node("RunMenu")
	menu.open_menu()
	var elapsed: float = battle._round_elapsed
	await get_tree().create_timer(0.5).timeout
	_check(is_equal_approx(battle._round_elapsed, elapsed), "Settings pause the demo")
	menu.close_menu()
	await _verify_winner_exit(battle, false)
	_check(await _wait_for_phase(battle, battle.Phase.FIGHTING, 8.0), "Tier 2 army enters")
	await get_tree().create_timer(0.7).timeout
	await _capture("tier2.png")
	if "--visual-only" in OS.get_cmdline_user_args():
		get_tree().quit(_failures)
		return
	await _verify_winner_exit(battle, true)
	var seen_weapons: Dictionary = {}
	var seen_round := 0
	for i in 1600:
		if battle._round_index != seen_round:
			seen_round = battle._round_index
			print("Natural matchup ", seen_round)
			for unit in battle._player_troop.get_units():
				seen_weapons[unit.weapon.display_name] = true
		if battle._round_index >= 7:
			break
		await get_tree().create_timer(0.25).timeout
	_check(battle._round_index >= 7, "All six matchups cycle and restart")
	_check(seen_weapons.has("Spore Mortar") and seen_weapons.has("Crossbow") and seen_weapons.has("Lance"), "Additional tier 2 weapons appear in the rotation")
	_check(GameState.current_day == day and GameState.biomass.amount == biomass and GameState.troop == troop, "Demo leaves run state untouched")
	_check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == physics_ticks, "Demo leaves engine timing untouched")
	await _capture("later-round.png")
	title.get_node("%NewRunButton").pressed.emit()
	await get_tree().create_timer(1.5).timeout
	_check(get_tree().current_scene.scene_file_path == GameState.BASE_SCENE_PATH, "New Run opens the base")
	_check(get_tree().get_nodes_in_group("troops").is_empty(), "Demo troops are removed on leaving title")
	_check(get_tree().get_nodes_in_group("projectiles").is_empty(), "Demo projectiles are removed on leaving title")
	print("TITLE CHECKS COMPLETE; failures=", _failures)
	get_tree().quit(_failures)
