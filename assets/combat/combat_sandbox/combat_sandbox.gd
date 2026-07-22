extends Node

const _RESTART_DELAY_SEC := 1.0
const _MELEE_WEAPON := preload("res://assets/weapons/basic_melee/basic_melee.tres")
const _SPEAR_WEAPON := preload("res://assets/weapons/basic_spear/basic_spear.tres")
const _BOW_WEAPON := preload("res://assets/weapons/basic_bow/basic_bow.tres")
const _SHIELD_WEAPON := preload("res://assets/weapons/basic_shield/basic_shield.tres")

@onready var _stage: Node2D = $CombatStage
@onready var _buttons: VBoxContainer = %MatchupButtons

var _rebuild_matchup: Callable = Callable()
var _restart_token: int = 0
var _imago_checkbox: CheckBox


func _ready() -> void:
	_stage.battle_ended.connect(_on_battle_ended)
	_wire_buttons()
	_set_matchup(func() -> Array:
		return [_make_units(_MELEE_WEAPON, 3), _make_units(_SPEAR_WEAPON, 3)]
	)


func _wire_buttons() -> void:
	_imago_checkbox = CheckBox.new()
	_imago_checkbox.text = "Imago units"
	_imago_checkbox.toggled.connect(_on_imago_toggled)
	_buttons.add_child(_imago_checkbox)

	_add_button("Restart", _restart_current)
	_add_button("3v3 Starters", func() -> void:
		_set_matchup(func() -> Array:
			return [
				[_make_unit(_BOW_WEAPON), _make_unit(_SPEAR_WEAPON), _make_unit(_MELEE_WEAPON)],
				[_make_unit(_BOW_WEAPON), _make_unit(_SPEAR_WEAPON), _make_unit(_MELEE_WEAPON)],
			]
		)
	)
	_add_button("3 Melee", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_MELEE_WEAPON, 3), _make_units(_MELEE_WEAPON, 3)]
		)
	)
	_add_button("3 Spear", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SPEAR_WEAPON, 3), _make_units(_SPEAR_WEAPON, 3)]
		)
	)
	_add_button("3 Bow", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_BOW_WEAPON, 3), _make_units(_BOW_WEAPON, 3)]
		)
	)
	_add_button("Melee vs Spear", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_MELEE_WEAPON, 1), _make_units(_SPEAR_WEAPON, 1)]
		)
	)
	_add_button("Melee vs Bow", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_MELEE_WEAPON, 1), _make_units(_BOW_WEAPON, 1)]
		)
	)
	_add_button("Spear vs Bow", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SPEAR_WEAPON, 1), _make_units(_BOW_WEAPON, 1)]
		)
	)
	_add_button("Shield vs Melee", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SHIELD_WEAPON, 1), _make_units(_MELEE_WEAPON, 1)]
		)
	)
	_add_button("Shield vs Bow", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SHIELD_WEAPON, 1), _make_units(_BOW_WEAPON, 1)]
		)
	)
	_add_button("9v9 Shield Line", func() -> void:
		_set_matchup(func() -> Array:
			return [
				_make_line([_BOW_WEAPON, _SPEAR_WEAPON, _SHIELD_WEAPON]),
				_make_line([_BOW_WEAPON, _SPEAR_WEAPON, _MELEE_WEAPON]),
			]
		)
	)


func _add_button(label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	_buttons.add_child(button)


func _on_imago_toggled(_pressed: bool) -> void:
	_restart_current()


func _on_battle_ended(_player_won: bool) -> void:
	_restart_token += 1
	var token := _restart_token
	await get_tree().create_timer(_RESTART_DELAY_SEC).timeout
	if token != _restart_token or not is_inside_tree():
		return
	_restart_current()


func _restart_current() -> void:
	if not _rebuild_matchup.is_valid():
		return
	_set_matchup(_rebuild_matchup)


func _set_matchup(builder: Callable) -> void:
	_restart_token += 1
	_rebuild_matchup = builder
	var pair: Array = builder.call()
	_stage.start_battle(_as_roster(pair[0]), _as_roster(pair[1]))


func _as_roster(value: Variant) -> Array[RosterUnitData]:
	var roster: Array[RosterUnitData] = []
	for unit in value:
		roster.append(unit as RosterUnitData)
	return roster


func _make_line(weapons: Array) -> Array[RosterUnitData]:
	var roster: Array[RosterUnitData] = []
	for weapon in weapons:
		roster.append_array(_make_units(weapon as WeaponData, 3))
	return roster


func _make_units(weapon: WeaponData, count: int) -> Array[RosterUnitData]:
	var roster: Array[RosterUnitData] = []
	for _i in count:
		roster.append(_make_unit(weapon))
	return roster


func _make_unit(weapon: WeaponData) -> RosterUnitData:
	var unit := RosterUnitData.create(
		UnitNames.pick(),
		UnitStatsData.create_for_tier(UnitStatsData.PowerTier.COMMON),
		weapon,
		null,
		UnitStatsData.PowerTier.COMMON
	)
	if _imago_checkbox != null and _imago_checkbox.button_pressed:
		unit.promote_to_imago()
	return unit
