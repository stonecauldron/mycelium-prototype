extends Node

const _RESTART_DELAY_SEC := 1.0
const _SWORD_WEAPON := preload("res://assets/weapons/sword/sword.tres")
const _SPEAR_WEAPON := preload("res://assets/weapons/spear/spear.tres")
const _BOW_WEAPON := preload("res://assets/weapons/bow/bow.tres")
const _SHIELD_WEAPON := preload("res://assets/weapons/shield/shield.tres")
const _SICKLE_WEAPON := preload("res://assets/weapons/sickle/sickle.tres")
const _RAPIER_WEAPON := preload("res://assets/weapons/rapier/rapier.tres")
const _GREAT_SWORD_WEAPON := preload("res://assets/weapons/great_sword/great_sword.tres")
const _GREAT_HAMMER_WEAPON := preload("res://assets/weapons/great_hammer/great_hammer.tres")
const _MACE_WEAPON := preload("res://assets/weapons/mace/mace.tres")
const _LANCE_WEAPON := preload("res://assets/weapons/lance/lance.tres")
const _SCYTHE_WEAPON := preload("res://assets/weapons/scythe/scythe.tres")
const _HALBERD_WEAPON := preload("res://assets/weapons/halberd/halberd.tres")
const _GREAT_SHIELD_WEAPON := preload("res://assets/weapons/great_shield/great_shield.tres")
const _UMBRELLA_WEAPON := preload("res://assets/weapons/umbrella/umbrella.tres")
const _CROSSBOW_WEAPON := preload("res://assets/weapons/crossbow/crossbow.tres")
const _SNIPER_WEAPON := preload("res://assets/weapons/sniper/sniper.tres")
const _MORTAR_WEAPON := preload("res://assets/weapons/mortar/mortar.tres")
const _GIANT_HORN_WEAPON := preload("res://assets/weapons/giant_horn/giant_horn.tres")

const _SOLAR_SWORD_ENEMY := preload("res://assets/units/enemies/solar_sword/solar_sword_unit.tres")
const _ROSE_THORN_ENEMY := preload("res://assets/units/enemies/rose_thorn/rose_thorn_unit.tres")
const _PEASHOOTER_ENEMY := preload("res://assets/units/enemies/peashooter/peashooter_unit.tres")
const _STUMP_ENEMY := preload("res://assets/units/enemies/stump/stump_unit.tres")
const _SOLAR_CLEAVER_ENEMY := preload("res://assets/units/enemies/solar_cleaver/solar_cleaver_unit.tres")
const _DURIAN_ENEMY := preload("res://assets/units/enemies/durian/durian_unit.tres")
const _LOG_ENEMY := preload("res://assets/units/enemies/log/log_unit.tres")
const _CANOPY_ENEMY := preload("res://assets/units/enemies/canopy/canopy_unit.tres")
const _SEED_LOBBER_ENEMY := preload("res://assets/units/enemies/seed_lobber/seed_lobber_unit.tres")
const _ACORN_KNIGHT_ENEMY := preload("res://assets/units/enemies/acorn_knight/acorn_knight_unit.tres")

const _WEAPON_OPTIONS: Array[Dictionary] = [
	{"name": "Sword", "weapon": _SWORD_WEAPON},
	{"name": "Spear", "weapon": _SPEAR_WEAPON},
	{"name": "Bow", "weapon": _BOW_WEAPON},
	{"name": "Shield", "weapon": _SHIELD_WEAPON},
	{"name": "Sickle", "weapon": _SICKLE_WEAPON},
	{"name": "Rapier", "weapon": _RAPIER_WEAPON},
	{"name": "Great Sword", "weapon": _GREAT_SWORD_WEAPON},
	{"name": "Great Hammer", "weapon": _GREAT_HAMMER_WEAPON},
	{"name": "Mace", "weapon": _MACE_WEAPON},
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

const _ENEMY_OPTIONS: Array[Dictionary] = [
	{"name": "Solar Sword", "unit": _SOLAR_SWORD_ENEMY},
	{"name": "Rose Thorn", "unit": _ROSE_THORN_ENEMY},
	{"name": "Peashooter", "unit": _PEASHOOTER_ENEMY},
	{"name": "Stump", "unit": _STUMP_ENEMY},
	{"name": "Solar Cleaver", "unit": _SOLAR_CLEAVER_ENEMY},
	{"name": "Durian", "unit": _DURIAN_ENEMY},
	{"name": "Log", "unit": _LOG_ENEMY},
	{"name": "Canopy", "unit": _CANOPY_ENEMY},
	{"name": "Seed Lobber", "unit": _SEED_LOBBER_ENEMY},
	{"name": "Acorn Knight", "unit": _ACORN_KNIGHT_ENEMY},
]

@onready var _stage: Node2D = $CombatStage
@onready var _buttons: VBoxContainer = %MatchupButtons
@onready var _player_weapon: OptionButton = %PlayerWeapon
@onready var _enemy_type: OptionButton = %EnemyType
@onready var _unit_count: SpinBox = %UnitCount
@onready var _run_custom: Button = %RunCustom

var _rebuild_matchup: Callable = Callable()
var _restart_token: int = 0
var _imago_checkbox: CheckBox


func _ready() -> void:
	_stage.battle_ended.connect(_on_battle_ended)
	_populate_custom_controls()
	_wire_buttons()
	_set_matchup(_build_custom_matchup)


func _populate_custom_controls() -> void:
	_fill_weapon_options(_player_weapon)
	_fill_enemy_options(_enemy_type)
	_run_custom.pressed.connect(_on_run_custom_pressed)


func _fill_weapon_options(button: OptionButton) -> void:
	button.clear()
	for i in _WEAPON_OPTIONS.size():
		button.add_item(str(_WEAPON_OPTIONS[i]["name"]), i)
	button.select(0)


func _fill_enemy_options(button: OptionButton) -> void:
	button.clear()
	for i in _ENEMY_OPTIONS.size():
		button.add_item(str(_ENEMY_OPTIONS[i]["name"]), i)
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
				[_make_enemy(_PEASHOOTER_ENEMY), _make_enemy(_ROSE_THORN_ENEMY), _make_enemy(_SOLAR_SWORD_ENEMY)],
			]
		)
	)
	_add_button("3 Melee", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SWORD_WEAPON, 3), _make_enemies(_SOLAR_SWORD_ENEMY, 3)]
		)
	)
	_add_button("3 Spear", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SPEAR_WEAPON, 3), _make_enemies(_ROSE_THORN_ENEMY, 3)]
		)
	)
	_add_button("3 Bow", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_BOW_WEAPON, 3), _make_enemies(_PEASHOOTER_ENEMY, 3)]
		)
	)
	_add_button("Melee vs Solar Sword", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SWORD_WEAPON, 1), _make_enemies(_SOLAR_SWORD_ENEMY, 1)]
		)
	)
	_add_button("Melee vs Rose Thorn", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SWORD_WEAPON, 1), _make_enemies(_ROSE_THORN_ENEMY, 1)]
		)
	)
	_add_button("Melee vs Peashooter", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SWORD_WEAPON, 1), _make_enemies(_PEASHOOTER_ENEMY, 1)]
		)
	)
	_add_button("Spear vs Peashooter", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SPEAR_WEAPON, 1), _make_enemies(_PEASHOOTER_ENEMY, 1)]
		)
	)
	_add_button("Shield vs Solar Sword", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SHIELD_WEAPON, 1), _make_enemies(_SOLAR_SWORD_ENEMY, 1)]
		)
	)
	_add_button("Shield vs Peashooter", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SHIELD_WEAPON, 1), _make_enemies(_PEASHOOTER_ENEMY, 1)]
		)
	)
	_add_button("Shield vs Stump", func() -> void:
		_set_matchup(func() -> Array:
			return [_make_units(_SHIELD_WEAPON, 1), _make_enemies(_STUMP_ENEMY, 1)]
		)
	)
	_add_button("9v9 Mixed", func() -> void:
		_set_matchup(func() -> Array:
			return [
				_make_line([_BOW_WEAPON, _SPEAR_WEAPON, _SWORD_WEAPON]),
				_make_enemy_line([_PEASHOOTER_ENEMY, _ROSE_THORN_ENEMY, _SOLAR_SWORD_ENEMY]),
			]
		)
	)
	_add_button("9v9 Shield Line", func() -> void:
		_set_matchup(func() -> Array:
			return [
				_make_line([_BOW_WEAPON, _SPEAR_WEAPON, _SHIELD_WEAPON]),
				_make_enemy_line([_PEASHOOTER_ENEMY, _ROSE_THORN_ENEMY, _STUMP_ENEMY]),
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
	var count := clampi(int(_unit_count.value), 1, 24)
	return [
		_make_units(_selected_weapon(_player_weapon), count),
		_make_enemies(_selected_enemy(_enemy_type), count),
	]


func _selected_weapon(button: OptionButton) -> WeaponData:
	var index := button.get_selected_id()
	if index < 0 or index >= _WEAPON_OPTIONS.size():
		index = button.selected
	if index < 0 or index >= _WEAPON_OPTIONS.size():
		return _SWORD_WEAPON
	return _WEAPON_OPTIONS[index]["weapon"] as WeaponData


func _selected_enemy(button: OptionButton) -> EnemyUnitData:
	var index := button.get_selected_id()
	if index < 0 or index >= _ENEMY_OPTIONS.size():
		index = button.selected
	if index < 0 or index >= _ENEMY_OPTIONS.size():
		return _SOLAR_SWORD_ENEMY
	return _ENEMY_OPTIONS[index]["unit"] as EnemyUnitData


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


func _make_enemy_line(enemies: Array) -> Array[RosterUnitData]:
	var roster: Array[RosterUnitData] = []
	for enemy in enemies:
		roster.append_array(_make_enemies(enemy as EnemyUnitData, 3))
	return roster


func _make_units(weapon: WeaponData, count: int) -> Array[RosterUnitData]:
	var roster: Array[RosterUnitData] = []
	for _i in count:
		roster.append(_make_unit(weapon))
	return roster


func _make_enemies(unit_data: EnemyUnitData, count: int) -> Array[RosterUnitData]:
	var roster: Array[RosterUnitData] = []
	for _i in count:
		roster.append(_make_enemy(unit_data))
	return roster


func _make_unit(weapon: WeaponData) -> RosterUnitData:
	var stats := UnitStatsData.create_for_tier(UnitStatsData.PowerTier.COMMON)
	var unit := RosterUnitData.create(
		UnitNames.pick(),
		stats,
		weapon,
		UnitStatsData.PowerTier.COMMON
	)
	if _imago_checkbox != null and _imago_checkbox.button_pressed:
		unit.promote_to_imago()
	return unit


func _make_enemy(unit_data: EnemyUnitData) -> RosterUnitData:
	var stats := unit_data.make_stats() if unit_data != null else UnitStatsData.new()
	var display_name := "Enemy"
	if unit_data != null and not unit_data.display_name.is_empty():
		display_name = unit_data.display_name
	return RosterUnitData.create_enemy(display_name, stats, unit_data)
