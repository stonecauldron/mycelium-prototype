extends Node2D

const FLOOR_SURFACE_Y := 880.0
const _MELEE_UNIT_SCENE := preload("res://scenes/units/MeleeUnit.tscn")
const _SPEAR_UNIT_SCENE := preload("res://scenes/units/SpearUnit.tscn")
const _BASE_SCENE_PATH := "res://scenes/base/Base.tscn"
const _GAME_OVER_SCENE_PATH := "res://scenes/GameOver.tscn"

@onready var player_army: Army = $World/PlayerArmy
@onready var enemy_army: Army = $World/EnemyArmy

var _player_spawn: Vector2
var _enemy_spawn: Vector2
var _battle_over: bool = false


func _ready() -> void:
	_player_spawn = player_army.flag_bearer.global_position
	_enemy_spawn = enemy_army.flag_bearer.global_position

	var player_roster := ArmyData.get_squad_roster()
	if player_roster.is_empty():
		push_error("CombatStage requires a non-empty player squad in ArmyData.")
		return
	if not BattleLaunch.has_enemy_roster():
		push_error("CombatStage requires an enemy roster via BattleLaunch.")
		return

	_run_battle(player_roster, BattleLaunch.take_enemy_roster())


func _run_battle(
	player_roster: Array[RosterUnitData],
	enemy_roster: Array[RosterUnitData]
) -> void:
	_battle_over = false
	_clear_world_vfx()
	_reset_army_from_roster(
		player_army,
		_player_spawn,
		player_roster,
		Color(0.25, 0.75, 0.4, 1.0),
		true
	)
	_reset_army_from_roster(
		enemy_army,
		_enemy_spawn,
		enemy_roster,
		Color(0.85, 0.25, 0.3, 1.0),
		false
	)
	_refresh_unit_process_order()
	player_army.begin_march()
	enemy_army.begin_march()


func _reset_army_from_roster(
	army: Army,
	spawn_global: Vector2,
	roster: Array[RosterUnitData],
	body_color: Color,
	is_player: bool
) -> void:
	var units_root: Node2D = army.get_node("Units")
	_clear_units(units_root)
	army.reset_for_scenario(spawn_global)

	var index := 0
	for data in roster:
		if data == null:
			continue
		var scene := _scene_for_range(data.get_range_class())
		_spawn_unit(scene, units_root, data, body_color, index, is_player)
		index += 1

	army.refresh_squad_indices()


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
	if is_player and unit.roster_data != null:
		ArmyData.remove_unit(unit.roster_data)
	_check_battle_end()


func _check_battle_end() -> void:
	if _battle_over:
		return
	if not player_army.is_wiped_out() and not enemy_army.is_wiped_out():
		return
	_battle_over = true
	if player_army.is_wiped_out():
		SceneTransition.change_scene(_GAME_OVER_SCENE_PATH)
	else:
		SceneTransition.change_scene(_BASE_SCENE_PATH)


func _refresh_unit_process_order() -> void:
	var units: Array[Unit] = []
	units.append_array(player_army.get_living_units())
	units.append_array(enemy_army.get_living_units())
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
		if child is DamageNumber or child is SpearProjectile:
			child.queue_free()
