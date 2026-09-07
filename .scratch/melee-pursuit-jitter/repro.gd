extends Node

## 5 bows vs 5 Canopies. Run with --headless --fixed-fps 60; add -- --speed2/--speed4.
## Before the fix, the front Canopy switched idle/walk on consecutive physics ticks.
const STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const BOW := preload("res://assets/weapons/bow/bow.tres")
const CANOPY := preload("res://assets/units/enemies/canopy/canopy_unit.tres")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(20260907)
	var stage := STAGE.instantiate()
	stage.sandboxed = true
	add_child(stage)
	var stats := UnitStatsData.new()
	stats.strength = 6
	stats.dex = 6
	stats.con = 99
	var bow := RosterUnitData.create("Bow", stats, BOW)
	bow.is_imago = true
	bow.life_stage_id = RosterUnitData.STAGE_IMAGO
	var players: Array[RosterUnitData] = [bow]
	var enemies: Array[RosterUnitData] = [RosterUnitData.create_enemy("Canopy", stats, CANOPY)]
	for index in 4:
		players.append(bow.duplicate(true))
		enemies.append(RosterUnitData.create_enemy("Canopy%d" % index, stats, CANOPY))
	stage.start_battle(players, enemies)
	stage._set_fast_forward(1)
	if "--speed2" in OS.get_cmdline_user_args():
		stage._set_fast_forward(2)
	if "--speed4" in OS.get_cmdline_user_args():
		stage._set_fast_forward(4)
	var pursuer: Unit = stage.enemy_troop.get_units().back()
	var archer: Unit = stage.player_troop.get_units()[0]
	var previous_animation := ""
	var previous_switch_frame := 0
	var rapid_switches := 0
	var retreat_frames := 0
	var stationary_frames: Dictionary[Unit, int] = {}
	var animation_violations := 0
	var attack_samples := 0
	var stop_samples := 0
	var combat_trace: Array = []
	var flag: FlagBearer = stage.player_troop.flag_bearer
	var flag_animation := ""
	var flag_switch_frame := 0
	var flag_rapid_switches := 0
	var flag_stopped_frames := 0
	var flag_animation_violations := 0
	var flag_trace: Array = []
	for frame in 900:
		await get_tree().physics_frame
		if not is_instance_valid(pursuer) or not is_instance_valid(archer):
			break
		var next_flag_animation := flag._animation_player.current_animation
		var flag_stopped := absf(flag.velocity.x) <= FlagBearer.WALK_SPEED_EPSILON
		flag_stopped_frames = flag_stopped_frames + 1 if flag_stopped else 0
		if flag.is_in_knockback() or not flag.is_on_floor() or flag_stopped_frames >= 8:
			if next_flag_animation != "idle":
				flag_animation_violations += 1
		if next_flag_animation != flag_animation:
			if frame - flag_switch_frame <= 3 and flag.is_on_floor() and not flag.is_in_knockback():
				flag_rapid_switches += 1
			flag_animation = next_flag_animation
			flag_switch_frame = frame
		flag_trace.append([flag.global_position, flag.velocity, flag.get_march_velocity_x(), flag.is_in_knockback()])
		var animation := pursuer._appearance.animation_player.current_animation
		var frame_trace: Array = []
		for unit: Unit in stage.player_troop.get_units() + stage.enemy_troop.get_units():
			var unit_animation := unit._appearance.animation_player.current_animation
			var stopped := absf(unit.velocity.x) <= Unit.WALK_SPEED_EPSILON
			stationary_frames[unit] = stationary_frames.get(unit, 0) + 1 if stopped else 0
			if unit._combat_phase == Unit.CombatPhase.ATTACKING or not unit.is_on_floor():
				attack_samples += 1
				if unit_animation != "idle":
					animation_violations += 1
			elif stationary_frames[unit] >= 8:
				stop_samples += 1
				if unit_animation != "idle":
					animation_violations += 1
			frame_trace.append([
				unit.global_position, unit.velocity, unit.current_hp, unit.damage_dealt, unit.damage_taken,
				unit._combat_phase, unit._attack_timer, unit._throw_timer, unit._in_knockback,
				unit._target.roster_data.display_name if unit._target is Unit else "",
				unit._body_shape.global_transform, unit._appearance.hurtbox.global_transform,
			])
		combat_trace.append(frame_trace)
		var retreating := archer._combat_phase == Unit.CombatPhase.RETREATING
		if retreating:
			retreat_frames += 1
		if animation != previous_animation:
			if (
				retreating and frame - previous_switch_frame <= 3
				and pursuer._combat_phase != Unit.CombatPhase.ATTACKING
				and not pursuer._in_knockback and pursuer.is_on_floor()
			):
				rapid_switches += 1
			previous_switch_frame = frame
			previous_animation = animation
	print("PURSUIT: retreat_frames=", retreat_frames, "; rapid_idle_walk_switches=", rapid_switches)
	print("IDLE: attack/air_samples=", attack_samples, "; stop_samples=", stop_samples,
		"; violations=", animation_violations)
	print("COMBAT TRACE: ", var_to_str(combat_trace).sha256_text(), "; rng=", randi())
	print("FLAG: rapid_switches=", flag_rapid_switches, "; idle_violations=", flag_animation_violations,
		"; trace=", var_to_str(flag_trace).sha256_text())
	var passed := (
		retreat_frames > 30 and rapid_switches <= 2 and animation_violations == 0
		and attack_samples > 0 and stop_samples > 0
		and flag_rapid_switches <= 2 and flag_animation_violations == 0
	)
	print("PASS" if passed else "FAIL")
	get_tree().quit(0 if passed else 1)
