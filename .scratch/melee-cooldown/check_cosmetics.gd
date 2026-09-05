extends Node2D

const STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const FONT := preload("res://assets/fonts/SpicyRice-Regular.ttf")
const ENEMIES := [
	"solar_sword", "rose_thorn", "peashooter", "stump", "solar_cleaver",
	"durian", "log", "canopy", "seed_lobber", "acorn_knight",
]
const MATCHUPS := [
	["sword", "solar_sword"], ["sword_and_shield", "stump"],
	["great_hammer", "solar_cleaver"], ["spear", "solar_sword"],
	["bow", "peashooter"], ["shield", "acorn_knight"],
]

var _failures: int = 0
var _pose_samples: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _enemy(id: String) -> EnemyUnitData:
	return load("res://assets/units/enemies/%s/%s_unit.tres" % [id, id]) as EnemyUnitData


func _weapon(id: String) -> WeaponData:
	return load("res://assets/weapons/%s/%s.tres" % [id, id]) as WeaponData


func _transforms(node: Node) -> Array:
	var result: Array = []
	if node is Node2D:
		result.append([node.transform, node.global_transform])
	for child in node.get_children():
		result.append_array(_transforms(child))
	return result


func _check_appearance(appearance: UnitAppearance) -> void:
	add_child(appearance)
	appearance.mount_weapon_appearance(_weapon("sword_and_shield"))
	appearance.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	appearance.play_idle(false)
	appearance.animation_player.advance(0.0)
	# Includes mirrored/scaled appearances, follow mounts, colliders and hurtboxes.
	appearance.scale = Vector2(-1.3, 1.3)
	var before := _transforms(appearance)
	seed(9817)
	var expected_random := randi()
	seed(9817)
	for duration in [0.03, 0.75, 3.0]:
		appearance.begin_melee_recovery(duration)
		for fraction in [0.99, 0.8, 0.5, 0.1, 0.01]:
			appearance.update_melee_pose(0.15, true, duration * fraction, 1.7)
			appearance._render_melee_pose()
			_check(_transforms(appearance) == before, "Cosmetics changed a Node2D transform")
		appearance.clear_melee_pose()
		_check(_transforms(appearance) == before, "Clearing cosmetics changed a transform")
		_check(not RenderingServer.frame_pre_draw.is_connected(appearance._render_melee_pose), "Draw callback leaked")
	_check(randi() == expected_random, "Cosmetics consumed the gameplay RNG")
	appearance.free()


func _unit_state(unit: Unit) -> Array:
	var target_name := ""
	if is_instance_valid(unit._target):
		target_name = String(unit._target.name)
		if unit._target is Unit and unit._target.roster_data != null:
			target_name = unit._target.roster_data.display_name
	var appearance := unit._appearance
	var geometry: Array = [unit._visual.transform, unit._body_shape.global_transform]
	if appearance != null:
		geometry.append(appearance.hurtbox.global_transform)
		geometry.append(appearance.weapon_mount.global_transform)
	if unit._hitbox != null:
		geometry.append([unit._hitbox.global_transform, unit._hitbox.monitoring])
	return [
		unit.roster_data.display_name, unit.position, unit.velocity, unit.current_hp,
		unit.damage_dealt, unit.damage_taken, unit._combat_phase, unit._charge_phase,
		unit._attack_timer, unit._throw_timer, unit._in_knockback, target_name, geometry,
	]


func _run_matchup(weapon_id: String, enemy_id: String, speed: int, baseline: bool) -> Array:
	GameState.reset_run()
	seed(41721)
	GameState.combat_fast_forward = speed
	var stage := STAGE.instantiate()
	add_child(stage)
	var players: Array[RosterUnitData] = []
	var enemies: Array[RosterUnitData] = []
	for index in 2:
		var stats := UnitStatsData.new()
		stats.strength = 6
		stats.dex = 6
		stats.con = 25
		var player := RosterUnitData.create("Player%d" % index, stats, _weapon(weapon_id))
		player.is_imago = index == 0
		player.life_stage_id = RosterUnitData.STAGE_IMAGO if index == 0 else RosterUnitData.STAGE_JUVENILE
		players.append(player)
		enemies.append(RosterUnitData.create_enemy("Enemy%d" % index, stats.duplicate(), _enemy(enemy_id)))
	stage.start_battle(players, enemies)
	for unit in get_tree().get_nodes_in_group("units"):
		unit.set_process(not baseline)
	var frames: Array = []
	for frame in 720:
		await get_tree().physics_frame
		var units: Array = []
		for unit: Unit in get_tree().get_nodes_in_group("units"):
			units.append(_unit_state(unit))
			if unit._appearance != null and unit._appearance._melee_guard_weight > 0.0:
				_pose_samples += 1
		var projectiles: Array = []
		for projectile: Projectile in get_tree().get_nodes_in_group("projectiles"):
			projectiles.append([projectile.global_transform, projectile._velocity, projectile._lifetime, projectile._spent])
		frames.append([units, projectiles, stage._battle_over])
	var result: Array = [weapon_id, enemy_id, speed, frames, randi()]
	stage.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0) and Engine.physics_ticks_per_second == 60, "Timing leaked after battle")
	print("TRACE ", speed, "x ", weapon_id, " vs ", enemy_id, " recorded")
	return result


func _label(text: String, at: Vector2, width: float, size: int = 28) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("293c39"))
	add_child(label)


func _preview() -> void:
	RenderingServer.set_default_clear_color(Color("ebe4d3"))
	_label("Melee cooldown poses", Vector2(0, 25), 1920, 42)
	var titles := ["Ordinary idle", "Recover", "Guard", "Prepare next strike"]
	for column in 4:
		_label(titles[column], Vector2(column * 480, 100), 480)
		for row in 3:
			var appearance: UnitAppearance
			if row == 0:
				appearance = UnitAppearance.compose_player(true)
			elif row == 1:
				appearance = _enemy("solar_sword").instantiate_appearance()
			else:
				appearance = _enemy("stump").instantiate_appearance()
			add_child(appearance)
			appearance.position = Vector2(column * 480 + 240, row * 260 + 390)
			appearance.scale = Vector2(1.8, 1.8)
			if row < 2:
				appearance.mount_weapon_appearance(_weapon("sword_and_shield" if row == 0 else "sword"))
			appearance.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			appearance.play_idle(false)
			appearance.animation_player.advance(0.2)
			if column > 0:
				appearance.begin_melee_recovery(1.25)
				appearance.update_melee_pose(0.12, true, [0.0, 1.13, 0.6, 0.025][column], 1.2)
	_label("Render offsets only · original combat timing and collision geometry", Vector2(0, 990), 1920, 24)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.scratch/melee-cooldown/preview.png")
	get_tree().quit()


func _run() -> void:
	if "--preview" in OS.get_cmdline_user_args():
		await _preview()
		return
	_check_appearance(UnitAppearance.compose_player(false))
	_check_appearance(UnitAppearance.compose_player(true))
	for id in ENEMIES:
		_check_appearance(_enemy(id).instantiate_appearance())
	print("ISOLATION: 12 appearances, short/normal/long cooldowns; failures=", _failures)
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var trace: Array = []
	for speed in [1, 2, 4]:
		for matchup in MATCHUPS:
			trace.append(await _run_matchup(matchup[0], matchup[1], speed, baseline))
	var path := "/private/tmp/melee-baseline.trace" if baseline else "/private/tmp/melee-cosmetics.trace"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var(trace)
	_check(baseline or _pose_samples > 0, "Combat never exercised a cosmetic pose")
	print("COSMETIC CHECK: failures=", _failures, "; pose samples=", _pose_samples, "; trace=", path)
	get_tree().quit(0 if _failures == 0 else 1)
