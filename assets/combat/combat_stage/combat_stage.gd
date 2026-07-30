extends Node2D

signal battle_ended(player_won: bool)

const FLOOR_SURFACE_Y := 786.0
const _MELEE_UNIT_SCENE := preload("res://assets/units/melee_unit/melee_unit.tscn")
const _SPEAR_UNIT_SCENE := preload("res://assets/units/spear_unit/spear_unit.tscn")
const _GAME_OVER_SCENE_PATH := "res://assets/game_over/game_over.tscn"
const _VICTORY_SCENE_PATH := "res://assets/victory/victory.tscn"
const _DAY_SUMMARY_SCENE_PATH := "res://assets/day_summary/day_summary.tscn"
const _FAST_FORWARD_SCALES: Array[int] = [1, 2, 4]
const _FAST_FORWARD_COLOR_2X := Color(1.0, 0.85, 0.35, 1.0)
const _FAST_FORWARD_COLOR_4X := Color(1.0, 0.25, 0.25, 1.0)
const _HITSTOP_SCALE := 0.05
const _HITSTOP_DURATION := 0.05
const _ZOMBIE_RESPAWN_DELAY := 2.0
## Keep physics step size fixed under time_scale so 2×/4× don't change combat outcomes.
const _BASE_PHYSICS_TICKS := 60
const _BIOMASS_NUMBER_SCENE := preload("res://assets/vfx/biomass_number/biomass_number.tscn")
const _COMBAT_CALLOUT_SCENE := preload("res://assets/vfx/combat_callout/combat_callout.tscn")
const _BIOMASS_DIGITS := 4
const _VICTORY_HITSTOP_SCALE := 0.12
const _VICTORY_HITSTOP_DURATION := 0.7
const _VICTORY_CELEBRATE_SEC := 3.8
## Beat after the wipe before flag death / callout / tosses.
const _VICTORY_LEAD_IN_SEC := 0.5

@export var sandboxed: bool = false

@onready var player_troop: Troop = $World/PlayerTroop
@onready var enemy_troop: Troop = $World/EnemyTroop
@onready var _fast_forward_button: Button = %FastForwardButton
@onready var _biomass_amount: Label = %BiomassAmount

var _player_spawn: Vector2
var _enemy_spawn: Vector2
var _battle_over: bool = false
var _fallen_units: Array[RosterUnitData] = []
var _biomass_earned_this_fight: int = 0
var _fast_forward_scale: int = 1
var _hitstop_active: bool = false
var _combat_paused: bool = false
var _saved_physics_ticks: int = _BASE_PHYSICS_TICKS
var _saved_max_physics_steps: int = 8
var _pending_player_zombie_respawns: int = 0
var _pending_enemy_zombie_respawns: int = 0
var _victory_celebrating: bool = false
var _victory_director: VictoryCelebrationDirector = null


func _ready() -> void:
	if get_tree().current_scene != self:
		sandboxed = true

	_victory_director = VictoryCelebrationDirector.new()
	add_child(_victory_director)

	_saved_physics_ticks = Engine.physics_ticks_per_second
	_saved_max_physics_steps = Engine.max_physics_steps_per_frame
	_player_spawn = player_troop.flag_bearer.global_position
	_enemy_spawn = enemy_troop.flag_bearer.global_position
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fast_forward_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_fast_forward_button.pressed.connect(_on_fast_forward_pressed)
	_set_fast_forward(GameState.combat_fast_forward)
	_refresh_biomass_hud()

	if sandboxed:
		return

	var player_roster := GameState.troop.get_squad_roster()
	if player_roster.is_empty():
		push_error("CombatStage requires a non-empty player squad in GameState.troop.")
		return

	if not BattleLaunch.has_enemy_roster():
		push_error("CombatStage requires an enemy roster via BattleLaunch.")
		return

	start_battle(player_roster, BattleLaunch.take_enemy_roster())


func _exit_tree() -> void:
	_hitstop_active = false
	_victory_celebrating = false
	if _victory_director != null:
		_victory_director.stop()
	_set_combat_paused(false)
	_restore_engine_timing()


func _unhandled_input(event: InputEvent) -> void:
	if _battle_over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_toggle_combat_pause()
			get_viewport().set_input_as_handled()


func _toggle_combat_pause() -> void:
	if _battle_over:
		return
	_set_combat_paused(not _combat_paused)


func _set_combat_paused(paused: bool) -> void:
	_combat_paused = paused
	if is_inside_tree():
		get_tree().paused = paused
	if not paused:
		_apply_simulation_rate()


func start_battle(
	player_roster: Array[RosterUnitData],
	enemy_roster: Array[RosterUnitData]
) -> void:
	_run_battle(player_roster, enemy_roster)


func _on_fast_forward_pressed() -> void:
	var idx := _FAST_FORWARD_SCALES.find(_fast_forward_scale)
	if idx < 0:
		idx = 0
	var next_scale := _FAST_FORWARD_SCALES[(idx + 1) % _FAST_FORWARD_SCALES.size()]
	_set_fast_forward(next_scale)


func _set_fast_forward(ff_scale: int) -> void:
	if ff_scale not in _FAST_FORWARD_SCALES:
		ff_scale = 1
	_fast_forward_scale = ff_scale
	GameState.combat_fast_forward = ff_scale
	_apply_simulation_rate()
	if _fast_forward_button != null:
		match ff_scale:
			2:
				_fast_forward_button.modulate = _FAST_FORWARD_COLOR_2X
			4:
				_fast_forward_button.modulate = _FAST_FORWARD_COLOR_4X
			_:
				_fast_forward_button.modulate = Color.WHITE


## time_scale alone enlarges each physics delta; also raise tick rate so game-time
## step size stays ~1/_BASE_PHYSICS_TICKS (projectiles/collisions stay consistent).
func _apply_simulation_rate() -> void:
	var ff := 1 if _battle_over else _fast_forward_scale
	Engine.physics_ticks_per_second = _saved_physics_ticks * ff
	# 4× at 60fps needs 4 steps/frame; headroom if render FPS dips.
	Engine.max_physics_steps_per_frame = maxi(_saved_max_physics_steps, ff * 4)
	if _hitstop_active:
		return
	Engine.time_scale = 1.0 if _battle_over else float(ff)


func _restore_time_scale() -> void:
	_apply_simulation_rate()


func _restore_engine_timing() -> void:
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = _saved_physics_ticks
	Engine.max_physics_steps_per_frame = _saved_max_physics_steps


func request_hitstop() -> void:
	if _battle_over or _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = _HITSTOP_SCALE
	var timer := get_tree().create_timer(_HITSTOP_DURATION, true, false, true)
	await timer.timeout
	if not is_inside_tree():
		return
	# Victory celebration owns hitstop / time_scale after the killing blow.
	if _victory_celebrating:
		return
	_hitstop_active = false
	if _battle_over:
		return
	_restore_time_scale()


func _run_battle(
	player_roster: Array[RosterUnitData],
	enemy_roster: Array[RosterUnitData]
) -> void:
	_battle_over = false
	_hitstop_active = false
	_victory_celebrating = false
	if _victory_director != null:
		_victory_director.stop()
	_fallen_units.clear()
	_biomass_earned_this_fight = 0
	_pending_player_zombie_respawns = 0
	_pending_enemy_zombie_respawns = 0
	_clear_world_vfx()
	_reset_troop_from_roster(
		player_troop,
		_player_spawn,
		player_roster,
		Color.WHITE,
		true
	)
	_reset_troop_from_roster(
		enemy_troop,
		_enemy_spawn,
		enemy_roster,
		Color(0.85, 0.25, 0.3, 1.0),
		false
	)
	_refresh_unit_process_order()
	_notify_battle_start()
	_set_fast_forward(_fast_forward_scale)


func _notify_battle_start() -> void:
	for unit in player_troop.get_living_units():
		unit.notify_battle_start()
	for unit in enemy_troop.get_living_units():
		unit.notify_battle_start()


func _notify_battle_end() -> void:
	if _victory_director != null:
		_victory_director.stop()
	for unit in player_troop.get_living_units():
		unit.notify_battle_end()
	for unit in enemy_troop.get_living_units():
		unit.notify_battle_end()


func _award_kill_biomass(victim: Unit) -> int:
	var is_imago := victim.roster_data != null and victim.roster_data.is_imago
	var reward := BiomassData.reward_for_kill(is_imago)
	GameState.biomass.add(reward)
	_biomass_earned_this_fight += reward
	_notify_biomass_from_combat_death(reward, victim)
	_refresh_biomass_hud()
	_spawn_biomass_number(victim.global_position, reward)
	return reward


func record_biomass_yield(amount: int) -> void:
	if amount <= 0:
		return
	_biomass_earned_this_fight += amount
	_refresh_biomass_hud()


func _spawn_biomass_number(at_global: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	var world := get_node_or_null("World") as Node2D
	if world == null:
		return
	var number: BiomassNumber = _BIOMASS_NUMBER_SCENE.instantiate()
	world.add_child(number)
	number.global_position = at_global + Vector2(0, -128)
	number.display(amount)


func _refresh_biomass_hud() -> void:
	if _biomass_amount == null:
		return
	_biomass_amount.text = "%0*d kg" % [_BIOMASS_DIGITS, GameState.biomass.amount]


func _notify_biomass_from_combat_death(amount: int, victim: Unit) -> void:
	if amount <= 0:
		return
	for unit in player_troop.get_living_units():
		if unit.roster_data != null and unit.roster_data.strain != null:
			unit.roster_data.strain.call_effect(
				&"on_combat_biomass_awarded",
				[unit, amount, victim]
			)
	for unit in enemy_troop.get_living_units():
		if unit.roster_data != null and unit.roster_data.strain != null:
			unit.roster_data.strain.call_effect(
				&"on_combat_biomass_awarded",
				[unit, amount, victim]
			)

func _reset_troop_from_roster(
	troop: Troop,
	spawn_global: Vector2,
	roster: Array[RosterUnitData],
	body_color: Color,
	is_player: bool
) -> void:
	var units_root: Node2D = troop.get_node("Units")
	_clear_units(units_root)
	troop.reset_for_scenario(spawn_global)

	# Player homes use War Chamber slot indices (nulls leave gaps). Enemies and
	# sandbox battles use compact order from the passed roster.
	if is_player and not sandboxed:
		var squad: Array = GameState.troop.squad
		for slot_index in squad.size():
			var data := squad[slot_index] as RosterUnitData
			if data == null:
				continue
			var scene := _scene_for_attack_style(data.get_attack_style())
			_spawn_unit(scene, units_root, data, body_color, slot_index, is_player)
	else:
		var index := 0
		for data in roster:
			if data == null:
				continue
			var scene := _scene_for_attack_style(data.get_attack_style())
			_spawn_unit(scene, units_root, data, body_color, index, is_player)
			index += 1


func _clear_units(units_root: Node2D) -> void:
	for child in units_root.get_children():
		units_root.remove_child(child)
		child.free()


func _scene_for_attack_style(attack_style: WeaponData.AttackStyle) -> PackedScene:
	match attack_style:
		WeaponData.AttackStyle.PROJECTILE_THROW:
			return _SPEAR_UNIT_SCENE
		_:
			return _MELEE_UNIT_SCENE


func _spawn_unit(
	scene: PackedScene,
	units_root: Node2D,
	roster_data: RosterUnitData,
	body_color: Color,
	squad_index: int,
	is_player: bool,
	spawn_global: Vector2 = Vector2.INF
) -> Unit:
	var unit: Unit = scene.instantiate()
	unit.roll_random_stats = false
	unit.roster_data = roster_data
	if roster_data.stats != null:
		unit.stats = roster_data.stats.duplicate(true)
	if roster_data.weapon != null:
		unit.weapon = roster_data.weapon
	unit.body_color = body_color * UnitStatsData.tint_for_tier(roster_data.power_tier)
	unit.squad_index = squad_index
	unit.died.connect(_on_unit_died.bind(is_player))
	units_root.add_child(unit)
	if spawn_global != Vector2.INF:
		unit.global_position = spawn_global
	return unit


func _on_unit_died(unit: Unit, is_player: bool) -> void:
	request_hitstop()
	var roster := unit.roster_data
	var wants_zombie_respawn := (
		roster != null
		and not roster.has_revived
		and roster.has_meta("zombie_cap_wants_respawn")
		and bool(roster.get_meta("zombie_cap_wants_respawn"))
	)
	if not sandboxed:
		if is_player and roster != null:
			_fallen_units.append(roster)
			GameState.troop.remove_unit(roster)
		elif not is_player:
			_award_kill_biomass(unit)
	if wants_zombie_respawn:
		_schedule_zombie_respawn(roster, is_player, unit.squad_index)
	else:
		_check_battle_end()


func _schedule_zombie_respawn(
	dead_roster: RosterUnitData,
	is_player: bool,
	squad_index: int
) -> void:
	if dead_roster == null:
		return
	if dead_roster.has_meta("zombie_cap_wants_respawn"):
		dead_roster.remove_meta("zombie_cap_wants_respawn")
	if is_player:
		_pending_player_zombie_respawns += 1
	else:
		_pending_enemy_zombie_respawns += 1
	await get_tree().create_timer(_ZOMBIE_RESPAWN_DELAY).timeout
	if not is_inside_tree():
		return
	if is_player:
		_pending_player_zombie_respawns = maxi(_pending_player_zombie_respawns - 1, 0)
	else:
		_pending_enemy_zombie_respawns = maxi(_pending_enemy_zombie_respawns - 1, 0)
	if _battle_over:
		return
	_respawn_zombie_cap(dead_roster, is_player, squad_index)
	_check_battle_end()


## Spawn just ahead of the opposing unit that has advanced furthest.
func _zombie_respawn_global_position(troop: Troop) -> Vector2:
	var opponent := troop.get_opponent()
	if opponent == null:
		return troop.get_flag_global_position()
	var frontmost := opponent.get_frontmost_living_unit()
	if frontmost == null:
		return troop.get_flag_global_position()
	# Place slightly in front of that unit (in the direction they face).
	return frontmost.global_position + Vector2(
		opponent.get_facing() * Troop.HOME_SLOT_SPACING,
		0.0
	)


func _respawn_zombie_cap(
	dead_roster: RosterUnitData,
	is_player: bool,
	squad_index: int
) -> void:
	if dead_roster == null:
		return
	var clone := dead_roster.duplicate(true) as RosterUnitData
	if clone == null:
		return
	if clone.stats != null:
		clone.stats = dead_roster.stats.duplicate(true)
	clone.has_revived = true
	if clone.has_meta("zombie_cap_wants_respawn"):
		clone.remove_meta("zombie_cap_wants_respawn")
	if is_player and not sandboxed:
		_fallen_units.erase(dead_roster)
		if GameState.troop.try_add_unit(clone) == "":
			return
	var troop := player_troop if is_player else enemy_troop
	var units_root: Node2D = troop.get_node("Units")
	var color := Color.WHITE if is_player else Color(0.85, 0.25, 0.3, 1.0)
	var scene := _scene_for_attack_style(clone.get_attack_style())
	var spawn_pos := _zombie_respawn_global_position(troop)
	var spawned := _spawn_unit(scene, units_root, clone, color, squad_index, is_player, spawn_pos)
	if spawned != null:
		spawned.notify_battle_start()
	_refresh_unit_process_order()


func _check_battle_end() -> void:
	if _battle_over:
		return
	var player_wiped := (
		player_troop.is_wiped_out() and _pending_player_zombie_respawns <= 0
	)
	var enemy_wiped := (
		enemy_troop.is_wiped_out() and _pending_enemy_zombie_respawns <= 0
	)
	if not player_wiped and not enemy_wiped:
		return
	_battle_over = true
	_set_combat_paused(false)

	if player_wiped:
		_hitstop_active = false
		_restore_engine_timing()
		_notify_battle_end()
		if sandboxed:
			battle_ended.emit(false)
			return
		SceneTransition.change_scene(_GAME_OVER_SCENE_PATH)
		return

	# Sandbox rematches skip the victory beat so flags/walls stay reset-friendly.
	if sandboxed:
		_hitstop_active = false
		_restore_engine_timing()
		_notify_battle_end()
		battle_ended.emit(true)
		return

	_victory_celebrating = true
	await get_tree().create_timer(_VICTORY_LEAD_IN_SEC, true, true, true).timeout
	if not is_inside_tree():
		return
	await _play_victory_celebration()
	if not is_inside_tree():
		return
	_victory_celebrating = false
	_hitstop_active = false
	_restore_engine_timing()
	_notify_battle_end()

	GameState.ensure_nursery_seeded()
	GameState.current_day += 1
	GameState.clear_upcoming_enemy_formation()
	if GameState.has_won_run():
		SceneTransition.change_scene(_VICTORY_SCENE_PATH)
		return
	DaySummaryFeed.clear()
	if GameState.current_day == GameState.NURSERY_UNLOCK_DAY:
		GameState.prefer_nursery_tab = true
		DaySummaryFeed.add_base_unlock("Nursery")
	if GameState.current_day == GameState.RIBOFORGE_UNLOCK_DAY:
		GameState.prefer_riboforge_tab = true
		DaySummaryFeed.add_base_unlock("Riboforge")
	if _biomass_earned_this_fight > 0:
		DaySummaryFeed.add_biomass_earned(_biomass_earned_this_fight)
	for unit in _fallen_units:
		DaySummaryFeed.add_fallen_unit(unit)
	var grown := GameState.troop.advance_unit_ages()
	for unit in grown:
		DaySummaryFeed.add_unit_became_imago(unit)
	var matured := GameState.nursery.advance_day()
	for entry in matured:
		DaySummaryFeed.add_nursery_matured(
			str(entry.get("spore_name", "Spore")),
			int(entry.get("plot_index", 0)),
			entry.get("tint", Color.WHITE) as Color,
			bool(entry.get("as_imago", false))
		)
	GameState.refresh_shops_for_new_day()
	SceneTransition.change_scene(_DAY_SUMMARY_SCENE_PATH)


func _play_victory_celebration() -> void:
	_hitstop_active = true
	Engine.time_scale = _VICTORY_HITSTOP_SCALE
	_destroy_all_walls()
	if enemy_troop.has_flag_bearer():
		enemy_troop.flag_bearer.play_death()
	_spawn_victory_callout()
	var celebrants: Array[Unit] = player_troop.get_living_units()
	for unit in celebrants:
		unit.begin_victory_celebration()
	var world := get_node_or_null("World") as Node2D
	if _victory_director != null:
		_victory_director.play(celebrants, world)

	# Real-time durations so slow-mo doesn't compress the celebration.
	await get_tree().create_timer(_VICTORY_HITSTOP_DURATION, true, true, true).timeout
	if not is_inside_tree():
		return
	_hitstop_active = false
	Engine.time_scale = 1.0

	await get_tree().create_timer(_VICTORY_CELEBRATE_SEC, true, true, true).timeout
	if _victory_director != null:
		_victory_director.stop()


func _destroy_all_walls() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("combat_obstacles"):
		var wall := node as WallObstacle
		if wall != null:
			wall.destroy()


func _spawn_victory_callout() -> void:
	var hud := get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return
	var callout: CombatCallout = _COMBAT_CALLOUT_SCENE.instantiate()
	hud.add_child(callout)
	var viewport_size := get_viewport().get_visible_rect().size
	callout.position = viewport_size * 0.5 + Vector2(0.0, -48.0)
	callout.display("Victory!", CombatCallout.Kind.VICTORY)


func _refresh_unit_process_order() -> void:
	var units: Array[Unit] = []
	units.append_array(player_troop.get_living_units())
	units.append_array(enemy_troop.get_living_units())
	units.sort_custom(func(a: Unit, b: Unit) -> bool:
		if a.stats.spd != b.stats.spd:
			return a.stats.spd > b.stats.spd
		return a.process_tiebreak > b.process_tiebreak
	)
	for i in units.size():
		units[i].process_physics_priority = i


func _clear_world_vfx() -> void:
	var world := $World
	for child in world.get_children():
		if (
			child is DamageNumber
			or child is CombatCallout
			or child is Projectile
			or child is HitBurst
			or child is SporeCloud
			or child is WallObstacle
		):
			child.queue_free()
