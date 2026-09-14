extends Node

const _STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const _ENEMY := preload("res://assets/units/enemies/solar_sword/solar_sword_unit.tres")
const _SWORD := preload("res://assets/weapons/sword/sword.tres")
const _ZOMBIE := preload("res://assets/base/nursery/mutations/body/zombie.tres")

var _failures: int = 0


func _ready() -> void:
	get_tree().create_timer(180.0, true, false, true).timeout.connect(func() -> void: get_tree().quit(2))
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		_failures += 1


func _wait(seconds: float = 0.1) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _player(unit_name: String) -> RosterUnitData:
	var stats := UnitStatsData.new()
	stats.strength = 1
	stats.con = 5
	return RosterUnitData.create(unit_name, stats, _SWORD)


func _battle(player_count: int = 2, zombie: bool = false) -> Node:
	var stage := _STAGE.instantiate()
	add_child(stage)
	var players: Array[RosterUnitData] = []
	var names := ["Wilson II", "Darwin III", "Beatrice IV", "Rosalind V"]
	for i in player_count:
		players.append(_player(names[i]))
		if i > 0:
			players[i].is_imago = true
			players[i].life_stage_id = RosterUnitData.STAGE_IMAGO
	if zombie:
		players[0].body_mutation = _ZOMBIE
	var enemies: Array[RosterUnitData] = [
		RosterUnitData.create_enemy("Solar Sword", UnitStatsData.new(), _ENEMY),
		RosterUnitData.create_enemy("Solar Sword", UnitStatsData.new(), _ENEMY),
		RosterUnitData.create_enemy("Solar Sword", UnitStatsData.new(), _ENEMY),
		RosterUnitData.create_enemy("Solar Sword", UnitStatsData.new(), _ENEMY),
	]
	stage.start_battle(players, enemies)
	# Keep the combat fixture still while exercising dialogue timing and UI.
	stage.player_troop.process_mode = Node.PROCESS_MODE_DISABLED
	stage.enemy_troop.process_mode = Node.PROCESS_MODE_DISABLED
	return stage


func _visible_text(stage: Node, text: String) -> bool:
	for node in stage.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and label.text == text:
			return true
	return false


func _line_text(stage: Node) -> String:
	var line := stage.get_node("World/CombatBarks/BarkBubble/Line") as Label
	return line.text if line.is_visible_in_tree() else ""


func _speaker_text(stage: Node) -> String:
	var label := stage.get_node("World/CombatBarks/BarkBubble/SpeakerName") as Label
	return label.text if label.is_visible_in_tree() else ""


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/private/tmp/character-barks-" + label + ".png")


func _quiet_battle(player_count: int = 2, zombie: bool = false) -> Node:
	GameState.combat_fast_forward = 4
	var stage := _battle(player_count, zombie)
	await _speed_button(stage)
	var barks := stage.get_node("World/CombatBarks") as CombatBarks
	barks.kill_chance = 1.0
	barks.mourning_chance = 1.0
	return stage


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		get_tree().root.push_input(event, true)
	await _wait(0.04)


func _speed_button(stage: Node) -> void:
	var button := stage.get_node("%FastForwardButton") as Button
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		get_tree().root.push_input(event, true)
	await _wait(0.04)


func _run() -> void:
	GameState.reset_run()
	if "--visual-only" in OS.get_cmdline_user_args():
		await _visuals()
		get_tree().quit(0 if _failures == 0 else 1)
		return
	if "--normal-outcomes" in OS.get_cmdline_user_args():
		await _normal_outcomes()
		get_tree().quit(0 if _failures == 0 else 1)
		return
	GameState.combat_fast_forward = 1
	var stage := _battle()
	await _wait(0.2)
	_check(_visible_text(stage, "Flag bearer"), "Battle starts with the Flag bearer's named bubble")
	await _capture("opening")
	await _key(KEY_ESCAPE)
	_check(get_tree().paused, "The actual combat menu pauses the Battle")
	await _wait(3.2)
	_check(_visible_text(stage, "Flag bearer"), "Menu pause preserves Bark reading time")
	await _key(KEY_ESCAPE)
	await _speed_button(stage)
	_check(GameState.combat_fast_forward == 2, "Speed button selects 2x")
	_check(not _visible_text(stage, "Flag bearer"), "Selecting 2x clears an active Bark")
	await _speed_button(stage)
	await _speed_button(stage)
	_check(GameState.combat_fast_forward == 1, "Speed button returns to 1x")
	_check(not _visible_text(stage, "Flag bearer"), "Returning to 1x does not replay the opening")
	var barks := stage.get_node("World/CombatBarks")
	barks.set("kill_chance", 1.0)
	var killer: Unit = stage.player_troop.get_units()[0]
	var victim: Unit = stage.enemy_troop.get_units()[0]
	victim.take_damage(99999, Vector2.ZERO, 0.0, killer)
	await _wait()
	_check(_visible_text(stage, "Wilson II"), "A living player killer speaks after its enemy kill")
	var original_line := _line_text(stage)
	var bubble := stage.get_node("World/CombatBarks/BarkBubble") as Node2D
	var original_position := bubble.global_position
	killer.global_position.x += 60.0
	await _wait()
	_check(is_equal_approx(bubble.global_position.x - original_position.x, 60.0), "Bubble follows its speaker in world space")
	barks.set("mourning_chance", 1.0)
	stage.player_troop.get_units()[1].take_damage(99999)
	await _wait()
	_check(_line_text(stage) == original_line, "Mourning does not interrupt an active kill line")
	await _wait(3.1)
	_check(_line_text(stage).is_empty(), "Normal Bark ends after three seconds with no queued mourning")
	stage.enemy_troop.get_units()[1].take_damage(99999, Vector2.ZERO, 0.0, killer)
	await _wait()
	_check(_line_text(stage).is_empty(), "Reaction cooldown drops fresh kills during the quiet gap")
	await _wait(3.1)
	stage.enemy_troop.get_units()[2].take_damage(99999, Vector2.ZERO, 0.0, killer)
	await _wait()
	_check(not _line_text(stage).is_empty() and _line_text(stage) != original_line, "A fresh kill after cooldown uses a different line")
	killer.global_position.x = -10000.0
	await _wait()
	_check(_line_text(stage).is_empty(), "Offscreen speakers lose their bubble")
	stage.queue_free()
	await _wait()
	GameState.combat_fast_forward = 4
	stage = _battle()
	barks = stage.get_node("World/CombatBarks")
	barks.set("mourning_chance", 1.0)
	await _speed_button(stage)
	var fallen: Unit = stage.player_troop.get_units()[0]
	fallen.take_damage(99999)
	await _wait()
	_check(_visible_text(stage, "Darwin III"), "A surviving Unit mourns a permanent friendly death")
	for enemy: Unit in stage.enemy_troop.get_units():
		enemy.take_damage(99999)
	await _wait()
	_check(_line_text(stage) in BarkData.LINES[BarkData.Kind.VICTORY], "Victory interrupts mourning with a survivor's victory line")
	await _wait(2.1)
	_check(_line_text(stage).is_empty(), "Victory Bark ends after two seconds")
	stage.queue_free()
	await _wait()
	await _priority_and_survival()
	await _zombie()
	await _uncredited_kills()
	await _fast_victory()
	await _opening_pool()
	await _normal_outcomes()
	print("BARK CHECK: ", _failures, " failures")
	get_tree().quit(0 if _failures == 0 else 1)


func _priority_and_survival() -> void:
	var stage := await _quiet_battle(4)
	var killer: Unit = stage.player_troop.get_units()[1]
	stage.enemy_troop.get_units()[0].take_damage(99999, Vector2.ZERO, 0.0, killer)
	stage.player_troop.get_units()[0].take_damage(99999)
	await _wait()
	var first_speaker := _speaker_text(stage)
	_check(not first_speaker.is_empty() and _line_text(stage) not in BarkData.LINES[BarkData.Kind.KILL], "Mourning wins over a kill from the same frame")
	await _capture("mourning")
	for enemy: Unit in stage.enemy_troop.get_living_units():
		enemy.take_damage(99999)
	await _wait()
	_check(not _speaker_text(stage).is_empty() and _speaker_text(stage) != first_speaker, "Victory chooses another surviving speaker when possible")
	await _capture("victory")
	stage.queue_free()
	await _wait()
	stage = await _quiet_battle()
	killer = stage.player_troop.get_units()[0]
	stage.enemy_troop.get_units()[0].take_damage(99999, Vector2.ZERO, 0.0, killer)
	await _wait()
	_check(not _line_text(stage).is_empty(), "Speaker-death fixture has an active Bark")
	killer.take_damage(99999)
	await _wait()
	_check(_line_text(stage).is_empty(), "Dying speaker clears its Bark while the Battle continues")
	stage.player_troop.get_living_units()[0].take_damage(99999)
	await _wait()
	_check(_line_text(stage).is_empty(), "Defeat leaves no final-death Bark")
	stage.queue_free()
	await _wait()


func _zombie() -> void:
	var stage := await _quiet_battle(2, true)
	stage.player_troop.get_units()[0].take_damage(99999)
	await _wait()
	_check(_line_text(stage).is_empty(), "Temporary Zombie death does not trigger mourning")
	await _wait(2.2)
	var revived: Unit = null
	for unit: Unit in stage.player_troop.get_living_units():
		if unit.roster_data.display_name == "Wilson II":
			revived = unit
	_check(revived != null and _line_text(stage).is_empty(), "Zombie revival does not replay opening dialogue")
	if revived != null:
		revived.take_damage(99999)
		await _wait()
		_check(_speaker_text(stage) == "Darwin III", "The Zombie's permanent death can be mourned")
	stage.queue_free()
	await _wait()


func _uncredited_kills() -> void:
	var stage := await _quiet_battle(3)
	var barks := stage.get_node("World/CombatBarks") as CombatBarks
	barks.mourning_chance = 0.0
	var killer: Unit = stage.player_troop.get_units()[0]
	stage.player_troop.get_units()[1].take_damage(99999, Vector2.ZERO, 0.0, killer)
	await _wait()
	_check(_line_text(stage).is_empty(), "Friendly sacrifice never gets a kill celebration")
	stage.enemy_troop.get_units()[0].take_damage(99999)
	await _wait()
	_check(_line_text(stage).is_empty(), "Environmental enemy death has no credited-speaker Bark")
	killer.take_damage(99999)
	stage.enemy_troop.get_units()[1].take_damage(99999, Vector2.ZERO, 0.0, killer)
	await _wait()
	_check(_line_text(stage).is_empty(), "A dead killer cannot speak for a delayed kill")
	stage.queue_free()
	await _wait()


func _fast_victory() -> void:
	GameState.combat_fast_forward = 4
	var stage := _battle()
	await _wait()
	_check(_line_text(stage).is_empty(), "Starting at 4x skips the opening")
	for enemy: Unit in stage.enemy_troop.get_units():
		enemy.take_damage(99999)
	await _wait()
	_check(Engine.time_scale == 1.0 and _line_text(stage).is_empty(), "End-of-Battle timing reset does not reveal a fast-forwarded victory Bark")
	stage.queue_free()
	await _wait()


func _opening_pool() -> void:
	GameState.reset_run()
	GameState.combat_fast_forward = 1
	var seen: Array[String] = []
	var previous := ""
	var pool: Array = BarkData.LINES[BarkData.Kind.OPENING]
	for i in pool.size() + 1:
		var stage := _battle()
		# Spawning is complete; the next frame displays the opening. Its
		# cosmetic selection must leave the global combat RNG untouched.
		seed(90210)
		var expected := randi()
		seed(90210)
		await _wait(0.15)
		_check(randi() == expected, "Opening dialogue leaves gameplay randomness unchanged")
		var line := _line_text(stage)
		if i < pool.size():
			_check(not line.is_empty() and line in pool and line not in seen, "Opening pool does not repeat across Battles before exhaustion")
			seen.append(line)
		else:
			_check(line in seen and (pool.size() == 1 or line != previous), "Exhausted pool starts a new cycle without repeating immediately when possible")
		previous = line
		stage.queue_free()
		await _wait(0.02)


func _visuals() -> void:
	GameState.combat_fast_forward = 1
	var stage := _battle()
	await _wait(0.4)
	await _capture("opening")
	stage.queue_free()
	await _wait()

	stage = await _quiet_battle()
	var fallen: Unit = stage.player_troop.get_units()[0]
	fallen.roster_data.display_name = "Alexandria XXVIII"
	stage.player_troop.get_units()[1].roster_data.display_name = "Bartholomew XXXVIII"
	# Select from the current copy so editing/removing a line cannot leave
	# this fixture searching forever for an obsolete phrase.
	var mourning_pool: Array = BarkData.LINES[BarkData.Kind.MOURNING]
	var longest_template := ""
	var expected_line := ""
	for template: String in mourning_pool:
		var personalized := template.replace("{fallen_name}", fallen.roster_data.display_name)
		if "{fallen_name}" in template and personalized.length() > expected_line.length():
			longest_template = template
			expected_line = personalized
	_check(not expected_line.is_empty(), "Mourning pool has a personalized line to verify")
	for _i in mourning_pool.size():
		if GameState.barks.line_for(BarkData.Kind.MOURNING) == longest_template:
			break
		GameState.barks.mark_shown(BarkData.Kind.MOURNING)
	fallen.take_damage(fallen.current_hp)
	await _wait(0.8)
	_check(_line_text(stage) == expected_line, "Named mourning substitutes the full fallen name")
	_check(_speaker_text(stage) == "Bartholomew XXXVIII", "Full long speaker name is shown in the header")
	await _capture("mourning-long-names")
	var camera := stage.get_node("World/MainCamera") as Camera2D
	camera.set_physics_process(false)
	camera.zoom = Vector2(0.55, 0.55)
	await _wait(0.1)
	await _capture("mourning-zoomed-out")
	var line := stage.get_node("World/CombatBarks/BarkBubble/Line") as Label
	var paper := stage.get_node("World/CombatBarks/BarkBubble/Paper") as Sprite2D
	var paper_body := paper.transform * paper.get_rect()
	# Exclude the texture's 44 px tail, then require a 16 px paper inset.
	# Labels can grow beyond their authored height when longer copy wraps.
	paper_body.size.y -= 44.0
	_check(paper_body.grow(-16.0).encloses(line.get_rect()), "Longest personalized line fits within the paper")
	var header := stage.get_node("World/CombatBarks/BarkBubble/SpeakerName") as Label
	_check(header.get_minimum_size().y <= 52.0, "Long speaker name fits within the teal header")
	stage.queue_free()
	await _wait()


func _normal_outcomes() -> void:
	# Keep the driver beside the real current scene, exercising the normal
	# victory celebration and transition rather than sandbox outcome handling.
	get_tree().current_scene = null
	for speed in [1, 4]:
		while SceneTransition.is_transitioning():
			await get_tree().process_frame
		GameState.reset_run()
		GameState.current_day = 1
		GameState.combat_fast_forward = speed
		GameState.troop.try_add_unit(_player("Wilson II"))
		BattleLaunch.set_enemy_roster([
			RosterUnitData.create_enemy("Solar Sword", UnitStatsData.new(), _ENEMY),
		])
		get_tree().change_scene_to_packed(_STAGE)
		await get_tree().scene_changed
		var stage := get_tree().current_scene
		stage.player_troop.process_mode = Node.PROCESS_MODE_DISABLED
		stage.enemy_troop.process_mode = Node.PROCESS_MODE_DISABLED
		await _wait(0.2)
		var shown_lines: Array[String] = []
		stage.enemy_troop.get_units()[0].take_damage(99999)
		# Observe the whole celebration: its lead-in runs on physics ticks,
		# so a fixed wall-clock sample can fall before the line starts.
		while not SceneTransition.is_transitioning():
			await get_tree().process_frame
			var line := _line_text(stage)
			if not line.is_empty() and line not in shown_lines:
				shown_lines.append(line)
		_check(shown_lines.size() == 1 and shown_lines[0] in BarkData.LINES[BarkData.Kind.VICTORY] if speed == 1 else shown_lines.is_empty(), "Normal victory dialogue honors selected " + str(speed) + "x speed")
		_check(_line_text(stage).is_empty(), "Victory Bark finishes before the existing scene fade")
		await get_tree().scene_changed
		_check(get_tree().current_scene.scene_file_path.ends_with("day_summary.tscn"), "Normal victory reaches the Day summary")
		_check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Normal scene exit restores combat timing")
