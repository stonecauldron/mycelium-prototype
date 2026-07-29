extends Node

const _RESTART_DELAY_SEC := 1.0
const _SWORD_WEAPON := preload("res://assets/weapons/sword/sword.tres")
const _SPEAR_WEAPON := preload("res://assets/weapons/spear/spear.tres")
const _BOW_WEAPON := preload("res://assets/weapons/bow/bow.tres")
const _SHIELD_WEAPON := preload("res://assets/weapons/shield/shield.tres")
const _FISTS_WEAPON := preload("res://assets/weapons/bare_fists.tres")
const _SICKLE_WEAPON := preload("res://assets/weapons/sickle/sickle.tres")
const _RAPIER_WEAPON := preload("res://assets/weapons/rapier/rapier.tres")
const _GREAT_SWORD_WEAPON := preload("res://assets/weapons/great_sword/great_sword.tres")
const _GREAT_HAMMER_WEAPON := preload("res://assets/weapons/great_hammer/great_hammer.tres")
const _LANCE_WEAPON := preload("res://assets/weapons/lance/lance.tres")
const _SCYTHE_WEAPON := preload("res://assets/weapons/scythe/scythe.tres")
const _HALBERD_WEAPON := preload("res://assets/weapons/halberd/halberd.tres")
const _GREAT_SHIELD_WEAPON := preload("res://assets/weapons/great_shield/great_shield.tres")
const _UMBRELLA_WEAPON := preload("res://assets/weapons/umbrella/umbrella.tres")
const _CROSSBOW_WEAPON := preload("res://assets/weapons/crossbow/crossbow.tres")
const _SNIPER_WEAPON := preload("res://assets/weapons/sniper/sniper.tres")
const _MORTAR_WEAPON := preload("res://assets/weapons/mortar/mortar.tres")
const _GIANT_HORN_WEAPON := preload("res://assets/weapons/giant_horn/giant_horn.tres")

const _WEAPON_OPTIONS: Array[Dictionary] = [
	{"name": "Sword", "weapon": _SWORD_WEAPON},
	{"name": "Spear", "weapon": _SPEAR_WEAPON},
	{"name": "Bow", "weapon": _BOW_WEAPON},
	{"name": "Shield", "weapon": _SHIELD_WEAPON},
	{"name": "Fists", "weapon": _FISTS_WEAPON},
	{"name": "Sickle", "weapon": _SICKLE_WEAPON},
	{"name": "Rapier", "weapon": _RAPIER_WEAPON},
	{"name": "Great Sword", "weapon": _GREAT_SWORD_WEAPON},
	{"name": "Great Hammer", "weapon": _GREAT_HAMMER_WEAPON},
	{"name": "Lance", "weapon": _LANCE_WEAPON},
	{"name": "Scythe", "weapon": _SCYTHE_WEAPON},
	{"name": "Halberd", "weapon": _HALBERD_WEAPON},
	{"name": "Great Shield", "weapon": _GREAT_SHIELD_WEAPON},
	{"name": "Umbrella", "weapon": _UMBRELLA_WEAPON},
	{"name": "Crossbow", "weapon": _CROSSBOW_WEAPON},
	{"name": "Sniper", "weapon": _SNIPER_WEAPON},
	{"name": "Mortar", "weapon": _MORTAR_WEAPON},
	{"name": "Giant Horn", "weapon": _GIANT_HORN_WEAPON},
]

const _STRAIN_OPTIONS: Array[Dictionary] = [
	{"name": "Generalist", "path": "res://assets/units/generalist/generalist_strain.tres"},
	{"name": "Death Cap", "path": "res://assets/units/death_cap/death_cap_strain.tres"},
	{"name": "Inky Cap", "path": "res://assets/units/inky_cap/inky_cap_strain.tres"},
	{"name": "Boom Cap", "path": "res://assets/units/boom_cap/boom_cap_strain.tres"},
	{"name": "Mini Cap", "path": "res://assets/units/mini_cap/mini_cap_strain.tres"},
	{"name": "Lanky Cap", "path": "res://assets/units/lanky_cap/lanky_cap_strain.tres"},
	{"name": "Fat Cap", "path": "res://assets/units/fat_cap/fat_cap_strain.tres"},
	{"name": "Magi Cap", "path": "res://assets/units/magi_cap/magi_cap_strain.tres"},
	{"name": "Chad Cap", "path": "res://assets/units/chad_cap/chad_cap_strain.tres"},
	{"name": "Rush Cap", "path": "res://assets/units/rush_cap/rush_cap_strain.tres"},
	{"name": "Wall Cap", "path": "res://assets/units/wall_cap/wall_cap_strain.tres"},
	{"name": "Bank Cap", "path": "res://assets/units/bank_cap/bank_cap_strain.tres"},
	{"name": "Zombie Cap", "path": "res://assets/units/zombie_cap/zombie_cap_strain.tres"},
	{"name": "Rubber Cap", "path": "res://assets/units/rubber_cap/rubber_cap_strain.tres"},
]

@onready var _stage: Node2D = $CombatStage
@onready var _buttons: VBoxContainer = %MatchupButtons
@onready var _player_strain: OptionButton = %PlayerStrain
@onready var _player_weapon: OptionButton = %PlayerWeapon
@onready var _enemy_strain: OptionButton = %EnemyStrain
@onready var _enemy_weapon: OptionButton = %EnemyWeapon
@onready var _unit_count: SpinBox = %UnitCount
@onready var _run_custom: Button = %RunCustom

var _rebuild_matchup: Callable = Callable()
var _restart_token: int = 0
var _imago_checkbox: CheckBox
var _strain_cache: Dictionary = {}


func _ready() -> void:
	_stage.battle_ended.connect(_on_battle_ended)
	_populate_custom_controls()
	_wire_buttons()
	_set_matchup(_build_custom_matchup)


func _populate_custom_controls() -> void:
	_fill_strain_options(_player_strain)
	_fill_strain_options(_enemy_strain)
	_fill_weapon_options(_player_weapon)
	_fill_weapon_options(_enemy_weapon)
	_run_custom.pressed.connect(_on_run_custom_pressed)


func _fill_strain_options(button: OptionButton) -> void:
	button.clear()
	for i in _STRAIN_OPTIONS.size():
		button.add_item(str(_STRAIN_OPTIONS[i]["name"]), i)
	button.select(0)


func _fill_weapon_options(button: OptionButton) -> void:
	button.clear()
	for i in _WEAPON_OPTIONS.size():
		button.add_item(str(_WEAPON_OPTIONS[i]["name"]), i)
	button.select(0)


func _wire_buttons() -> void:
	_imago_checkbox = CheckBox.new()
	_imago_checkbox.text = "Imago units"
	_imago_checkbox.toggled.connect(_on_imago_toggled)
	_buttons.add_child(_imago_checkbox)

	_add_button("Restart", _restart_current)
	_add_button("3v3 Starters", func() -> void:
		_set_matchup(func() -> Array:
			return [
				[_make_unit(_BOW_WEAPON), _make_unit(_SPEAR_WEAPON), _make_unit(_SWORD_WEAPON)],
				[_make_unit(_BOW_WEAPON), _make_unit(_SPEAR_WEAPON), _make_unit(_SWORD_WEAPON)],
			]
		)
	)
	_add_button("3 Melee", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SWORD_WEAPON, 3), _make_units(_SWORD_WEAPON, 3)]
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
			return [_make_units(_SWORD_WEAPON, 1), _make_units(_SPEAR_WEAPON, 1)]
		)
	)
	_add_button("Melee vs Bow", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SWORD_WEAPON, 1), _make_units(_BOW_WEAPON, 1)]
		)
	)
	_add_button("Spear vs Bow", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SPEAR_WEAPON, 1), _make_units(_BOW_WEAPON, 1)]
		)
	)
	_add_button("Shield vs Melee", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SHIELD_WEAPON, 1), _make_units(_SWORD_WEAPON, 1)]
		)
	)
	_add_button("Shield vs Bow", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SHIELD_WEAPON, 1), _make_units(_BOW_WEAPON, 1)]
		)
	)
	_add_button("9v9 Mirror", func() -> void:
		_set_matchup(func() -> Array:
			return [
				_make_line([_BOW_WEAPON, _SPEAR_WEAPON, _SWORD_WEAPON]),
				_make_line([_BOW_WEAPON, _SPEAR_WEAPON, _SWORD_WEAPON]),
			]
		)
	)
	_add_button("9v9 Shield Line", func() -> void:
		_set_matchup(func() -> Array:
			return [
				_make_line([_BOW_WEAPON, _SPEAR_WEAPON, _SHIELD_WEAPON]),
				_make_line([_BOW_WEAPON, _SPEAR_WEAPON, _SWORD_WEAPON]),
			]
		)
	)


func _add_button(label: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	_buttons.add_child(button)


func _on_run_custom_pressed() -> void:
	_set_matchup(_build_custom_matchup)


func _build_custom_matchup() -> Array:
	var count := clampi(int(_unit_count.value), 1, 9)
	return [
		_make_units(_selected_weapon(_player_weapon), count, _selected_strain(_player_strain)),
		_make_units(_selected_weapon(_enemy_weapon), count, _selected_strain(_enemy_strain)),
	]


func _selected_weapon(button: OptionButton) -> WeaponData:
	var index := button.get_selected_id()
	if index < 0 or index >= _WEAPON_OPTIONS.size():
		index = button.selected
	if index < 0 or index >= _WEAPON_OPTIONS.size():
		return _SWORD_WEAPON
	return _WEAPON_OPTIONS[index]["weapon"] as WeaponData


func _selected_strain(button: OptionButton) -> UnitStrain:
	var index := button.get_selected_id()
	if index < 0 or index >= _STRAIN_OPTIONS.size():
		index = button.selected
	if index < 0 or index >= _STRAIN_OPTIONS.size():
		return null
	var path := str(_STRAIN_OPTIONS[index]["path"])
	if not _strain_cache.has(path):
		_strain_cache[path] = load(path)
	return _strain_cache[path] as UnitStrain


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


func _make_units(
	weapon: WeaponData,
	count: int,
	strain: UnitStrain = null
) -> Array[RosterUnitData]:
	var roster: Array[RosterUnitData] = []
	for _i in count:
		roster.append(_make_unit(weapon, strain))
	return roster


func _make_unit(weapon: WeaponData, strain: UnitStrain = null) -> RosterUnitData:
	var stats := UnitStatsData.create_for_tier(UnitStatsData.PowerTier.COMMON)
	if strain != null:
		strain.apply_hatch_stats(stats)
	var unit := RosterUnitData.create(
		UnitNames.pick(),
		stats,
		weapon,
		strain,
		UnitStatsData.PowerTier.COMMON
	)
	if _imago_checkbox != null and _imago_checkbox.button_pressed:
		unit.promote_to_imago()
	return unit
