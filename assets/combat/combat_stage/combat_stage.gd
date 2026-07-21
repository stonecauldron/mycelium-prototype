extends Node2D

signal battle_ended(player_won: bool)

const FLOOR_SURFACE_Y := 880.0
const _MELEE_UNIT_SCENE := preload("res://assets/units/melee_unit/melee_unit.tscn")
const _SPEAR_UNIT_SCENE := preload("res://assets/units/spear_unit/spear_unit.tscn")
const _GAME_OVER_SCENE_PATH := "res://assets/game_over/game_over.tscn"
const _VICTORY_SCENE_PATH := "res://assets/victory/victory.tscn"
const _DAY_SUMMARY_SCENE_PATH := "res://assets/day_summary/day_summary.tscn"
const _FAST_FORWARD_SCALE := 2.0

@export var sandboxed: bool = false

@onready var player_troop: Troop = $World/PlayerTroop
@onready var enemy_troop: Troop = $World/EnemyTroop
@onready var _fast_forward_button: Button = %FastForwardButton

var _player_spawn: Vector2
var _enemy_spawn: Vector2
var _battle_over: bool = false
var _fallen_units: Array[RosterUnitData] = []
var _biomass_earned_this_fight: int = 0
var _fast_forward: bool = false


func _ready() -> void:
	if get_tree().current_scene != self:
		sandboxed = true

	_player_spawn = player_troop.flag_bearer.global_position
	_enemy_spawn = enemy_troop.flag_bearer.global_position
	_fast_forward_button.pressed.connect(_on_fast_forward_pressed)
	_set_fast_forward(GameState.combat_fast_forward)

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
	Engine.time_scale = 1.0


func start_battle(
	player_roster: Array[RosterUnitData],
	enemy_roster: Array[RosterUnitData]
) -> void:
	_run_battle(player_roster, enemy_roster)


func _on_fast_forward_pressed() -> void:
	_set_fast_forward(not _fast_forward)


func _set_fast_forward(enabled: bool) -> void:
	_fast_forward = enabled
	GameState.combat_fast_forward = enabled
	Engine.time_scale = _FAST_FORWARD_SCALE if enabled else 1.0
	if _fast_forward_button != null:
		_fast_forward_button.modulate = (
			Color(1.0, 0.85, 0.35, 1.0) if enabled else Color.WHITE
		)


func _run_battle(
	player_roster: Array[RosterUnitData],
	enemy_roster: Array[RosterUnitData]
) -> void:
	_battle_over = false
	_fallen_units.clear()
	_biomass_earned_this_fight = 0
	_clear_world_vfx()
	_reset_troop_from_roster(
		player_troop,
		_player_spawn,
		player_roster,
		Color(0.25, 0.75, 0.4, 1.0),
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
	_set_fast_forward(_fast_forward)
	player_troop.begin_march()
	enemy_troop.begin_march()


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

	var index := 0
	for data in roster:
		if data == null:
			continue
		var scene := _scene_for_range(data.get_range_class())
		_spawn_unit(scene, units_root, data, body_color, index, is_player)
		index += 1

	troop.refresh_squad_indices()
	troop.cache_battle_march_speed()


func _clear_units(units_root: Node2D) -> void:
	for child in units_root.get_children():
		units_root.remove_child(child)
		child.free()


func _scene_for_range(range_class: WeaponData.WeaponRange) -> PackedScene:
	match range_class:
		WeaponData.WeaponRange.MID:
			return _SPEAR_UNIT_SCENE
		_:
			return _MELEE_UNIT_SCENE


func _spawn_unit(
	scene: PackedScene,
	units_root: Node2D,
	roster_data: RosterUnitData,
	body_color: Color,
	squad_index: int,
	is_player: bool
) -> void:
	var unit: Unit = scene.instantiate()
	unit.roll_random_stats = false
	unit.roster_data = roster_data
	if roster_data.stats != null:
		unit.stats = roster_data.stats.duplicate(true)
	if roster_data.weapon != null:
		unit.weapon = roster_data.weapon
	unit.body_color = body_color
	unit.squad_index = squad_index
	unit.died.connect(_on_unit_died.bind(is_player))
	units_root.add_child(unit)


func _on_unit_died(unit: Unit, is_player: bool) -> void:
	if not sandboxed:
		if is_player and unit.roster_data != null:
			_fallen_units.append(unit.roster_data)
			GameState.troop.remove_unit(unit.roster_data)
		elif not is_player:
			var is_imago := unit.roster_data != null and unit.roster_data.is_imago
			var reward := BiomassData.reward_for_kill(is_imago)
			GameState.biomass.add(reward)
			_biomass_earned_this_fight += reward
	_check_battle_end()


func _check_battle_end() -> void:
	if _battle_over:
		return
	if not player_troop.is_wiped_out() and not enemy_troop.is_wiped_out():
		return
	_battle_over = true
	Engine.time_scale = 1.0

	if sandboxed:
		battle_ended.emit(not player_troop.is_wiped_out())
		return

	if player_troop.is_wiped_out():
		SceneTransition.change_scene(_GAME_OVER_SCENE_PATH)
	else:
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
				int(entry.get("plot_index", 0))
			)
		SceneTransition.change_scene(_DAY_SUMMARY_SCENE_PATH)


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
		if child is DamageNumber or child is SpearProjectile or child is ArrowProjectile:
			child.queue_free()
