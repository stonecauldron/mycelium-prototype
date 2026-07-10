extends Node2D

const FLOOR_SURFACE_Y := 880.0
const MELEE_COUNT := 4
const SPEAR_COUNT := 4
const _MELEE_UNIT_SCENE := preload("res://scenes/units/MeleeUnit.tscn")
const _SPEAR_UNIT_SCENE := preload("res://scenes/units/SpearUnit.tscn")
const _DEBUG_PANEL_SCENE := preload("res://scenes/debug/DebugScenarioPanel.tscn")

@onready var player_army: Army = $World/PlayerArmy
@onready var enemy_army: Army = $World/EnemyArmy

var _player_spawn: Vector2
var _enemy_spawn: Vector2


func _ready() -> void:
	_player_spawn = player_army.flag_bearer.global_position
	_enemy_spawn = enemy_army.flag_bearer.global_position

	var panel: CanvasLayer = _DEBUG_PANEL_SCENE.instantiate()
	add_child(panel)
	panel.scenario_requested.connect(_on_scenario_requested)

	_run_scenario(UnitStats.PowerTier.AVERAGE, UnitStats.PowerTier.AVERAGE)


func _on_scenario_requested(player_tier: UnitStats.PowerTier, enemy_tier: UnitStats.PowerTier) -> void:
	_run_scenario(player_tier, enemy_tier)


func _run_scenario(player_tier: UnitStats.PowerTier, enemy_tier: UnitStats.PowerTier) -> void:
	_clear_world_vfx()
	_reset_army(player_army, _player_spawn, player_tier, Color(0.25, 0.75, 0.4, 1.0))
	_reset_army(enemy_army, _enemy_spawn, enemy_tier, Color(0.85, 0.25, 0.3, 1.0))
	_refresh_unit_process_order()
	player_army.begin_march()
	enemy_army.begin_march()


func _reset_army(army: Army, spawn_global: Vector2, tier: UnitStats.PowerTier, body_color: Color) -> void:
	var units_root: Node2D = army.get_node("Units")
	for child in units_root.get_children():
		units_root.remove_child(child)
		child.free()

	army.reset_for_scenario(spawn_global)

	for i in MELEE_COUNT:
		_spawn_unit(_MELEE_UNIT_SCENE, units_root, tier, body_color, i)

	for i in SPEAR_COUNT:
		_spawn_unit(_SPEAR_UNIT_SCENE, units_root, tier, body_color, i)

	army.refresh_squad_indices()


func _spawn_unit(
	scene: PackedScene,
	units_root: Node2D,
	tier: UnitStats.PowerTier,
	body_color: Color,
	squad_index: int
) -> void:
	var unit: Unit = scene.instantiate()
	unit.roll_random_stats = false
	unit.stats = UnitStats.create_for_tier(tier)
	unit.body_color = body_color
	unit.squad_index = squad_index
	units_root.add_child(unit)


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
