extends SubViewportContainer

enum Phase { ENTERING, FIGHTING, EXITING, INTERMISSION }

const _UNIT_SCENE := preload("res://assets/units/unit.tscn")
const _DEMO_UNIT_SCRIPT := preload("res://assets/title/title_battle_unit.gd")
const _TROOP_SCENE := preload("res://assets/combat/troop/enemy_troop.tscn")
const _SICKLE := preload("res://assets/weapons/sickle/sickle.tres")
const _WEAPONS: Dictionary[String, WeaponData] = {
	"bow": preload("res://assets/weapons/bow/bow.tres"),
	"spear": preload("res://assets/weapons/spear/spear.tres"),
	"sword": preload("res://assets/weapons/sword/sword.tres"),
	"mace": preload("res://assets/weapons/mace/mace.tres"),
	"sword_shield": preload("res://assets/weapons/sword_and_shield/sword_and_shield.tres"),
	"great_sword": preload("res://assets/weapons/great_sword/great_sword.tres"),
	"great_hammer": preload("res://assets/weapons/great_hammer/great_hammer.tres"),
	"great_bow": preload("res://assets/weapons/great_bow/great_bow.tres"),
	"crossbow": preload("res://assets/weapons/crossbow/crossbow.tres"),
	"lance": preload("res://assets/weapons/lance/lance.tres"),
	"mortar": preload("res://assets/weapons/mortar/mortar.tres"),
}
const _ENEMIES: Dictionary[String, EnemyUnitData] = {
	"pea": preload("res://assets/units/enemies/peashooter/peashooter_unit.tres"),
	"rose": preload("res://assets/units/enemies/rose_thorn/rose_thorn_unit.tres"),
	"solar": preload("res://assets/units/enemies/solar_sword/solar_sword_unit.tres"),
	"stump": preload("res://assets/units/enemies/stump/stump_unit.tres"),
	"cleaver": preload("res://assets/units/enemies/solar_cleaver/solar_cleaver_unit.tres"),
	"durian": preload("res://assets/units/enemies/durian/durian_unit.tres"),
	"acorn": preload("res://assets/units/enemies/acorn_knight/acorn_knight_unit.tres"),
}
const _MATCHUPS: Array[Dictionary] = [
	{"players": ["bow", "spear", "sword"], "children": 2,
		"enemies": ["pea", "rose", "solar", "solar", "solar"]},
	{"players": ["great_bow", "great_sword", "great_hammer"], "children": 1,
		"enemies": ["pea", "rose", "cleaver", "durian"]},
	{"players": ["bow", "spear", "mace", "sword_shield"], "children": 1,
		"enemies": ["pea", "rose", "rose", "stump"]},
	{"players": ["crossbow", "lance", "sword_shield"], "children": 2,
		"enemies": ["pea", "pea", "cleaver", "acorn"]},
	{"players": ["spear", "sword", "mace"], "children": 2,
		"enemies": ["pea", "pea", "solar", "solar", "stump"]},
	{"players": ["mortar", "great_bow", "great_hammer"], "children": 2,
		"enemies": ["pea", "rose", "durian", "acorn"]},
]
const _STALEMATE_SECONDS := 30.0
const _FLOOR_Y := 786.0
const _OFFSCREEN_MARGIN := 240.0

@onready var _viewport: SubViewport = $Viewport
@onready var _camera: Camera2D = $Viewport/Camera
@onready var _world: Node2D = $Viewport/World

var _player_troop: Troop
var _enemy_troop: Troop
var _round_index: int = 0
var _round_elapsed: float = 0.0
var _phase: Phase = Phase.ENTERING
var _phase_elapsed: float = 0.0
var _stalemate_tick: float = 0.0
var _winners: Array[Unit] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_start_round()


func _process(delta: float) -> void:
	_phase_elapsed += delta
	match _phase:
		Phase.ENTERING:
			if _all_units_arrived():
				_set_edges_enabled(true)
				for unit in _all_living_units():
					(unit as TitleBattleUnit).begin_fighting()
				_phase = Phase.FIGHTING
		Phase.FIGHTING:
			_round_elapsed += delta
			_break_stalemate(delta)
			if _player_troop.is_wiped_out() or _enemy_troop.is_wiped_out():
				_begin_exit()
		Phase.EXITING:
			if _winners_are_offscreen():
				_phase = Phase.INTERMISSION
				_phase_elapsed = 0.0
		Phase.INTERMISSION:
			if _phase_elapsed >= 0.6:
				_start_round()


func _all_living_units() -> Array[Unit]:
	var units := _player_troop.get_living_units()
	units.append_array(_enemy_troop.get_living_units())
	return units


func _all_units_arrived() -> bool:
	for unit in _all_living_units():
		if not (unit as TitleBattleUnit).has_arrived():
			return false
	return true


func _begin_exit() -> void:
	_phase = Phase.EXITING
	_set_edges_enabled(false)
	_winners = _all_living_units()
	# Stray arrows and delayed bombs must not hit the survivors after victory.
	for child in _world.get_children():
		if child is Projectile:
			_world.remove_child(child)
			child.queue_free()
	for unit in _winners:
		(unit as TitleBattleUnit).march_out()


func _winners_are_offscreen() -> bool:
	for unit in _winners:
		if not is_instance_valid(unit):
			continue
		var facing := unit._troop.get_facing()
		if facing * (unit.global_position.x - _screen_edge(facing)) < _OFFSCREEN_MARGIN:
			return false
	return true


func _screen_edge(direction: float) -> float:
	return _camera.position.x + direction * float(_viewport.size.x) * 0.5


func _set_edges_enabled(enabled: bool) -> void:
	$Viewport/World/Boundary/Left.set_deferred("disabled", not enabled)
	$Viewport/World/Boundary/Right.set_deferred("disabled", not enabled)


func _break_stalemate(delta: float) -> void:
	if _round_elapsed < _STALEMATE_SECONDS:
		return
	_stalemate_tick += delta
	if _stalemate_tick < 1.0:
		return
	_stalemate_tick -= 1.0
	# Like combat's Acid Rain, resolve prolonged shield duels instead of cutting away.
	var damage := 1 + floori((_round_elapsed - _STALEMATE_SECONDS) / 5.0)
	for unit in _all_living_units():
		unit.take_damage(damage, Vector2.ZERO, 0.0, null, WeaponData.DamageType.BLUNT)


func _start_round() -> void:
	_set_edges_enabled(false)
	# Rebuild the entire cast and its projectiles so nothing survives a rematch.
	for child in _world.get_children():
		if child is StaticBody2D:
			continue
		_world.remove_child(child)
		child.queue_free()
	var matchup := _MATCHUPS[_round_index % _MATCHUPS.size()]
	var player_count: int = matchup.players.size() + int(matchup.children)
	_player_troop = _make_troop(false, player_count)
	_enemy_troop = _make_troop(true, matchup.enemies.size())
	for i in matchup.players.size():
		var weapon := _WEAPONS[str(matchup.players[i])]
		var stats := UnitStatsData.create_for_tier(UnitStatsData.PowerTier.COMMON, _rng)
		var roster := RosterUnitData.create("Shroom", stats, weapon)
		roster.life_stage_id = RosterUnitData.STAGE_IMAGO
		roster.is_imago = true
		_spawn_unit(_player_troop, roster, i)
	for i in int(matchup.children):
		var stats := UnitStatsData.create_for_tier(UnitStatsData.PowerTier.COMMON, _rng)
		var roster := RosterUnitData.create("Child", stats, _SICKLE)
		_spawn_unit(_player_troop, roster, matchup.players.size() + i)
	for i in matchup.enemies.size():
		var enemy := _ENEMIES[str(matchup.enemies[i])]
		var roster := RosterUnitData.create_enemy(enemy.display_name, enemy.make_stats(_rng), enemy)
		_spawn_unit(_enemy_troop, roster, i)
	_round_elapsed = 0.0
	_phase_elapsed = 0.0
	_stalemate_tick = 0.0
	_winners.clear()
	_phase = Phase.ENTERING
	_round_index += 1


func _make_troop(enemy: bool, count: int) -> Troop:
	var troop: Troop = _TROOP_SCENE.instantiate()
	troop.is_enemy = enemy
	var facing := troop.get_facing()
	var clearance := Troop.FLAG_REAR_CLEARANCE + Troop.HOME_SLOT_SPACING * float(count - 1)
	var spawn_x := _screen_edge(-facing) - facing * (_OFFSCREEN_MARGIN + clearance)
	troop.position = Vector2(spawn_x, _FLOOR_Y)
	_world.add_child(troop)
	return troop


func _spawn_unit(troop: Troop, roster: RosterUnitData, slot: int) -> void:
	var unit: Unit = _UNIT_SCENE.instantiate()
	unit.set_script(_DEMO_UNIT_SCRIPT)
	unit.roll_random_stats = false
	unit.roster_data = roster
	unit.stats = roster.stats
	unit.weapon = roster.weapon
	unit.squad_index = slot
	unit.z_index = 0 if troop.is_enemy else 1
	troop.get_node("Units").add_child(unit)
	var anchor_x := 1580.0 if troop.is_enemy else 340.0
	var home_offset := Troop.FLAG_REAR_CLEARANCE + Troop.HOME_SLOT_SPACING * float(slot)
	(unit as TitleBattleUnit).march_in(anchor_x + troop.get_facing() * home_offset)
