extends Node2D

const STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const SWORD := preload("res://assets/weapons/sword/sword.tres")
const ENEMY := preload("res://assets/units/enemies/solar_sword/solar_sword_unit.tres")

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: ", message)


func _players(count: int) -> Array[RosterUnitData]:
	var roster: Array[RosterUnitData] = []
	for index in count:
		var unit := RosterUnitData.create("Player%d" % index, UnitStatsData.new(), SWORD)
		unit.is_imago = index % 2 == 0
		unit.life_stage_id = RosterUnitData.STAGE_IMAGO if unit.is_imago else RosterUnitData.STAGE_JUVENILE
		roster.append(unit)
	return roster


func _enemies(count: int) -> Array[RosterUnitData]:
	var roster: Array[RosterUnitData] = []
	for index in count:
		roster.append(RosterUnitData.create_enemy("Enemy%d" % index, UnitStatsData.new(), ENEMY))
	return roster


func _run() -> void:
	if "--preview" in OS.get_cmdline_user_args():
		await _preview()
		return
	seed(74123)
	var stage := STAGE.instantiate()
	add_child(stage)
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	var small_right_edge := 0.0
	for pair in [[1, 1], [1, 23], [12, 24], [10, 36], [24, 24], [1, 1]]:
		stage.start_battle(_players(pair[0]), _enemies(pair[1]))
		_check_placement(stage, str(pair))
		if pair == [1, 1]:
			var right_edge: float = stage.get_node("World/WorldBoundary/RightEdge").global_position.x
			_check(is_zero_approx(small_right_edge) or is_equal_approx(right_edge, small_right_edge), "Arena expansion accumulated across restarts")
			small_right_edge = right_edge

	# Actual Run battles retain empty War Chamber slots, unlike the sandbox.
	var saved_squad: Array = GameState.troop.squad.duplicate()
	GameState.troop.squad.resize(TroopData.SQUAD_SLOT_COUNT)
	GameState.troop.squad.fill(null)
	var sparse := _players(2)
	GameState.troop.squad[0] = sparse[0]
	GameState.troop.squad[9] = sparse[1]
	stage.sandboxed = false
	stage.start_battle(sparse, _enemies(36))
	_check_placement(stage, "slots 0/9 vs 36")
	_check(stage.player_troop.get_frontmost_living_unit().squad_index == 9, "Sparse squad was compacted")
	GameState.troop.squad = saved_squad
	stage.sandboxed = true

	stage.start_battle(_players(2), _enemies(1))
	var enemy: Unit = stage.enemy_troop.get_frontmost_living_unit()
	for unit: Unit in stage.player_troop.get_units():
		var appearance := unit._appearance
		var body := appearance.sprite
		var mount := appearance.get_node("Body/CapMount") as Node2D
		var follow := body.get_node("CapMountFollow") as Node2D
		appearance.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for animation in [&"idle", &"walk"]:
			appearance.animation_player.play(animation)
			for direction in [1.0, -1.0, 1.0, -1.0]:
				enemy.global_position.x = unit.global_position.x + direction * 100.0
				unit._face_toward(enemy.global_position)
				appearance.animation_player.advance(0.13)
				await get_tree().process_frame
				await get_tree().process_frame
				var aligned := (
					mount.global_transform.x.normalized().dot(body.global_transform.x.normalized()) > 0.999
					and mount.global_transform.y.normalized().dot(body.global_transform.y.normalized()) > 0.999
				)
				_check(aligned, "%s %s facing %s: cap inverted relative to body" % [unit.roster_data.life_stage_id, animation, direction])
				_check(mount.global_position.distance_to(follow.global_position) < 0.01, "Cap detached from its mount")
		# Bow/throw lean and body scaling must keep the same attachment too.
		appearance.scale *= 1.3
		for angle in [-0.3, 0.3, 0.0]:
			appearance.rotation = angle
			await get_tree().process_frame
			await get_tree().process_frame
			_check(mount.global_transform.is_equal_approx(follow.global_transform), "Leaning/scaling detached or inverted the cap")

	# Let combat choose its own facing after an enemy crosses behind the squad.
	stage.start_battle(_players(2), _enemies(1))
	stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	for frame in 45:
		await get_tree().physics_frame
	enemy = stage.enemy_troop.get_frontmost_living_unit()
	var rear: Unit = stage.player_troop.get_rearmost_living_unit()
	enemy.global_position = rear.global_position + Vector2(-50.0, 0.0)
	var left_facing_samples := 0
	for frame in 120:
		await get_tree().physics_frame
		for unit: Unit in stage.player_troop.get_living_units():
			if unit._visual.transform.x.x < 0.0:
				left_facing_samples += 1
				var body := unit._appearance.sprite
				var mount := unit._appearance.get_node("Body/CapMount") as Node2D
				_check(mount.global_transform.y.normalized().dot(body.global_transform.y.normalized()) > 0.999, "Live combat inverted a cap when flanked")
	_check(left_facing_samples > 0, "Flanking scenario never turned a player unit left")
	print("LIVE FLANK: left-facing samples=", left_facing_samples)
	stage.free()
	Audio.stop_gameplay_sfx()
	await get_tree().create_timer(1.0).timeout
	print("SPAWN/FACING CHECK: failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check_placement(stage: Node2D, scenario: String) -> void:
	var player: Unit = stage.player_troop.get_frontmost_living_unit()
	var enemy: Unit = stage.enemy_troop.get_frontmost_living_unit()
	var gap := enemy.global_position.x - player.global_position.x
	print("SPAWN ", scenario, ": front gap=", gap)
	_check(is_equal_approx(gap, get_viewport_rect().size.x * 0.5), "Armies do not start half a screen apart")
	var right_edge := stage.get_node("World/WorldBoundary/RightEdge") as Node2D
	for troop: Troop in [stage.player_troop, stage.enemy_troop]:
		for unit in troop.get_units():
			_check(unit.global_position.is_equal_approx(unit._get_home_global()), "Unit was separated from its Home")
			_check(unit.global_position.x < right_edge.global_position.x - 50.0, "Unit spawned outside the arena")
	var camera := stage.get_node("World/MainCamera") as Camera2D
	var background_end := 0.0
	for child in stage.get_node("World/Background").get_children():
		if String(child.name).begins_with("Segment"):
			background_end = maxf(background_end, child.global_position.x + 1920.0)
	_check(background_end >= camera.limit_right, "Expanded arena has no background")
	_check(camera.limit_right > right_edge.global_position.x, "Camera cannot follow the expanded arena")


func _preview() -> void:
	RenderingServer.set_default_clear_color(Color("ebe4d3"))
	for row in 2:
		for column in 4:
			var adult := row == 1
			var left := column % 2 == 1
			var walking := column >= 2
			var appearance := UnitAppearance.compose_player(adult)
			add_child(appearance)
			appearance.position = Vector2(240 + column * 480, 440 + row * 480)
			appearance.scale = Vector2(-2.0 if left else 2.0, 2.0)
			appearance.mount_weapon_appearance(SWORD)
			appearance.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			appearance.animation_player.play(&"walk" if walking else &"idle")
			appearance.animation_player.advance(0.13)
			var label := Label.new()
			label.text = "%s · %s · %s" % ["Adult" if adult else "Child", "walk" if walking else "idle", "left" if left else "right"]
			label.position = Vector2(column * 480, 50 + row * 480)
			label.size.x = 480
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_color_override("font_color", Color("293c39"))
			label.add_theme_font_size_override("font_size", 28)
			add_child(label)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/private/tmp/enemy-spawn-facing-preview.png")
	get_tree().quit()
