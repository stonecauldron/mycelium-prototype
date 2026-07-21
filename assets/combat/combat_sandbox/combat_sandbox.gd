extends Node

const _RESTART_DELAY_SEC := 1.0
const _MELEE_WEAPON := preload("res://assets/weapons/basic_melee/basic_melee.tres")
const _SPEAR_WEAPON := preload("res://assets/weapons/basic_spear/basic_spear.tres")
const _BOW_WEAPON := preload("res://assets/weapons/basic_bow/basic_bow.tres")
const _SHIELD_WEAPON := preload("res://assets/weapons/basic_shield/basic_shield.tres")

@onready var _stage: Node2D = $CombatStage
@onready var _buttons: VBoxContainer = %MatchupButtons

var _player_roster: Array[RosterUnitData] = []
var _enemy_roster: Array[RosterUnitData] = []
var _restart_token: int = 0


func _ready() -> void:
	_stage.battle_ended.connect(_on_battle_ended)
	_wire_buttons()
	_start_matchup(_make_units(_MELEE_WEAPON, 3), _make_units(_SPEAR_WEAPON, 3))


func _wire_buttons() -> void:
	_add_button("Restart", _restart_current)
	_add_button("3v3 Starters", func() -> void:
		_start_matchup(
			[_make_unit(_BOW_WEAPON), _make_unit(_SPEAR_WEAPON), _make_unit(_MELEE_WEAPON)],
			[_make_unit(_BOW_WEAPON), _make_unit(_SPEAR_WEAPON), _make_unit(_MELEE_WEAPON)]
		)
	)
	_add_button("3 Melee", func() -> void:
		_start_matchup(_make_units(_MELEE_WEAPON, 3), _make_units(_MELEE_WEAPON, 3))
	)
	_add_button("3 Spear", func() -> void:
		_start_matchup(_make_units(_SPEAR_WEAPON, 3), _make_units(_SPEAR_WEAPON, 3))
	)
	_add_button("3 Bow", func() -> void:
		_start_matchup(_make_units(_BOW_WEAPON, 3), _make_units(_BOW_WEAPON, 3))
	)
	_add_button("Melee vs Spear", func() -> void:
		_start_matchup(_make_units(_MELEE_WEAPON, 1), _make_units(_SPEAR_WEAPON, 1))
	)
	_add_button("Melee vs Bow", func() -> void:
		_start_matchup(_make_units(_MELEE_WEAPON, 1), _make_units(_BOW_WEAPON, 1))
	)
	_add_button("Spear vs Bow", func() -> void:
		_start_matchup(_make_units(_SPEAR_WEAPON, 1), _make_units(_BOW_WEAPON, 1))
	)
	_add_button("Shield vs Melee", func() -> void:
		_start_matchup(_make_units(_SHIELD_WEAPON, 1), _make_units(_MELEE_WEAPON, 1))
	)
	_add_button("Shield vs Bow", func() -> void:
		_start_matchup(_make_units(_SHIELD_WEAPON, 1), _make_units(_BOW_WEAPON, 1))
	)


func _add_button(label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	_buttons.add_child(button)


func _on_battle_ended(_player_won: bool) -> void:
	_restart_token += 1
	var token := _restart_token
	await get_tree().create_timer(_RESTART_DELAY_SEC).timeout
	if token != _restart_token or not is_inside_tree():
		return
	_restart_current()


func _restart_current() -> void:
	if _player_roster.is_empty() and _enemy_roster.is_empty():
		return
	_start_matchup(_copy_roster(_player_roster), _copy_roster(_enemy_roster))


func _start_matchup(
	player_roster: Array[RosterUnitData],
	enemy_roster: Array[RosterUnitData]
) -> void:
	_restart_token += 1
	_player_roster = _copy_roster(player_roster)
	_enemy_roster = _copy_roster(enemy_roster)
	_stage.start_battle(_copy_roster(_player_roster), _copy_roster(_enemy_roster))


func _make_units(weapon: WeaponData, count: int) -> Array[RosterUnitData]:
	var roster: Array[RosterUnitData] = []
	for _i in count:
		roster.append(_make_unit(weapon))
	return roster


func _make_unit(weapon: WeaponData) -> RosterUnitData:
	return RosterUnitData.create(
		UnitNames.pick(),
		UnitStatsData.create_for_tier(UnitStatsData.PowerTier.AVERAGE),
		weapon
	)


func _copy_roster(roster: Array[RosterUnitData]) -> Array[RosterUnitData]:
	var copy: Array[RosterUnitData] = []
	for unit in roster:
		if unit == null:
			continue
		copy.append(unit.duplicate(true) as RosterUnitData)
	return copy
