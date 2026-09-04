extends Node

const HIT_TIMEOUT_FRAMES := 360
const OBSERVE_FRAMES := 240
const MIN_SLOW_RETREAT_FRAMES := 180
const MIN_PAST_HOME_DISTANCE := 60.0
const SLOW_SPEED_MAX := 60.0

const COMBAT_STAGE_SCENE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const SHIELD := preload("res://assets/weapons/shield/shield.tres")
const GREAT_SHIELD := preload("res://assets/weapons/great_shield/great_shield.tres")
const SWORD := preload("res://assets/weapons/sword/sword.tres")
const SEED_LOBBER := preload("res://assets/units/enemies/seed_lobber/seed_lobber_unit.tres")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(20260831)
	var variant := _variant_from_args()
	var stage := COMBAT_STAGE_SCENE.instantiate()
	stage.sandboxed = true
	add_child(stage)
	await get_tree().process_frame

	var test_weapon: WeaponData = SWORD if variant == "unshielded" else SHIELD
	if variant == "great_shield":
		test_weapon = GREAT_SHIELD
	var player_roster: Array[RosterUnitData] = [
		_make_player("Unit Under Test", test_weapon),
	]
	if variant == "with_ally":
		player_roster.append(_make_player("Non-HOLD Ally", SWORD))
	var enemy_roster: Array[RosterUnitData] = [_make_seed_lobber()]
	stage.start_battle(player_roster, enemy_roster)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ff="):
			stage._set_fast_forward(int(argument.trim_prefix("--ff=")))
	await get_tree().physics_frame

	var player_troop: Troop = stage.player_troop
	player_troop.march_speed = 0.0
	var shield: Unit = player_troop.get_units()[0]
	var ally: Unit = player_troop.get_units()[1] if player_troop.get_units().size() > 1 else null
	var lobber: Unit = stage.enemy_troop.get_units()[0]
	if ally != null:
		ally.set_physics_process(false)
	lobber.set_physics_process(false)
	if variant.begins_with("celebration"):
		shield.begin_victory_celebration()
	if variant == "fixed_anchor":
		player_troop.set_physics_process(false)
	lobber.global_position = shield.global_position + Vector2(500.0, 0.0)

	for _frame in 3:
		await get_tree().physics_frame
	var normal_hold_x := shield._get_hold_line_global().x
	var hp_before := shield.current_hp
	var hit_counter: Array[int] = [0]
	shield.health_changed.connect(func(_current: int, _maximum: int) -> void:
		hit_counter[0] += 1
	)
	var launch_force := lobber.combat.knockback_force
	if variant == "strong_knockback" or variant == "celebration_strong":
		launch_force = 400.0
	elif variant == "no_knockback":
		launch_force = 0.0
	elif variant == "boundary_grounded":
		launch_force = 128.0
	elif variant == "boundary_airborne":
		launch_force = 132.0
	_launch_seed_projectile(stage, lobber, shield, launch_force)

	var hit_detected := false
	for _frame in HIT_TIMEOUT_FRAMES:
		await get_tree().physics_frame
		if shield.current_hp < hp_before:
			hit_detected = true
			break
	if not hit_detected:
		print("[SEED-SHIELD-REPRO] ERROR projectile_did_not_hit")
		get_tree().quit(2)
		return

	print(
		"[SEED-SHIELD-REPRO] variant=", variant,
		" hit=true",
		" knockback_force=", launch_force,
		" shield_knockback_mult=", shield.combat.incoming_knockback_multiplier,
		" initial_velocity=", shield.velocity,
		" hit_events=", hit_counter[0],
		" status_count=", (shield.get("_statuses") as Array).size(),
		" status_move_mult=", shield._status_move_mult()
	)

	var slow_retreat_run := 0
	var max_slow_retreat_run := 0
	var max_past_home := 0.0
	var knockback_frames := 0
	var airborne_frames := 0
	var premature_recovery := false
	var facing := player_troop.get_facing()
	for frame in OBSERVE_FRAMES:
		await get_tree().physics_frame
		var forward_velocity := shield.velocity.x * facing
		var speed := absf(forward_velocity)
		var past_home := facing * (normal_hold_x - shield.global_position.x)
		max_past_home = maxf(max_past_home, past_home)
		if bool(shield.get("_in_knockback")):
			knockback_frames += 1
		if not shield.is_on_floor():
			airborne_frames += 1
			if not bool(shield.get("_in_knockback")):
				premature_recovery = true
		if forward_velocity < -1.0 and speed <= SLOW_SPEED_MAX:
			slow_retreat_run += 1
			max_slow_retreat_run = maxi(max_slow_retreat_run, slow_retreat_run)
		else:
			slow_retreat_run = 0
		if frame < 5:
			print(
				"[SEED-SHIELD-REPRO] frame=", frame,
				" x=", snappedf(shield.global_position.x, 0.01),
				" vx=", snappedf(shield.velocity.x, 0.01),
				" on_floor=", shield.is_on_floor(),
				" in_knockback=", shield.get("_in_knockback")
			)

	print(
		"[SEED-SHIELD-REPRO] max_slow_retreat_frames=", max_slow_retreat_run,
		" knockback_frames=", knockback_frames,
		" airborne_frames=", airborne_frames,
		" max_past_home=", snappedf(max_past_home, 0.01),
		" final_velocity=", shield.velocity
	)
	if (
		max_slow_retreat_run >= MIN_SLOW_RETREAT_FRAMES
		and max_past_home >= MIN_PAST_HOME_DISTANCE
		and knockback_frames == OBSERVE_FRAMES
	):
		print("[SEED-SHIELD-REPRO] FAIL slow_unbounded_retreat")
		get_tree().quit(1)
		return
	var expects_airborne := variant in [
		"unshielded", "strong_knockback", "celebration_strong", "boundary_airborne",
	]
	if (
		bool(shield.get("_in_knockback"))
		or not is_zero_approx(shield.velocity.x)
		or not shield.is_on_floor()
		or premature_recovery
		or (expects_airborne and airborne_frames == 0)
		or hit_counter[0] != 1
	):
		print("[SEED-SHIELD-REPRO] FAIL knockback_recovery_contract")
		get_tree().quit(1)
		return
	print("[SEED-SHIELD-REPRO] PASS no_slow_unbounded_retreat")
	get_tree().quit(0)


func _launch_seed_projectile(
	stage: Node2D,
	lobber: Unit,
	shield: Unit,
	knockback_force: float
) -> void:
	var projectile := lobber.combat.resolve_projectile_scene().instantiate() as Projectile
	stage.get_node("World").add_child(projectile)
	projectile.launch(
		lobber.global_position + Vector2(0.0, -40.0),
		shield.global_position + Vector2(40.0, 0.0),
		1,
		knockback_force,
		lobber
	)


func _variant_from_args() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--variant="):
			return argument.trim_prefix("--variant=")
	return "repro"


func _make_player(display_name: String, weapon: WeaponData) -> RosterUnitData:
	var stats := UnitStatsData.new()
	stats.strength = 5
	stats.dex = 5
	stats.con = 99
	return RosterUnitData.create(
		display_name,
		stats,
		weapon,
		UnitStatsData.PowerTier.COMMON
	)


func _make_seed_lobber() -> RosterUnitData:
	var stats := SEED_LOBBER.stats.duplicate(true) as UnitStatsData
	stats.con = 99
	return RosterUnitData.create_enemy("Seed Lobber", stats, SEED_LOBBER)
