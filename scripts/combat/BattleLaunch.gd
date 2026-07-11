class_name BattleLaunch
extends RefCounted

## Shared handoff from Base → CombatStage (no autoload needed).
static var player_roster: Array[RosterUnitData] = []
static var enemy_roster: Array[RosterUnitData] = []


static func set_rosters(player_units: Array, enemy_units: Array) -> void:
	player_roster = _copy_roster(player_units)
	enemy_roster = _copy_roster(enemy_units)


static func has_rosters() -> bool:
	return not player_roster.is_empty() and not enemy_roster.is_empty()


static func take_player_roster() -> Array[RosterUnitData]:
	var copy := _copy_roster(player_roster)
	player_roster.clear()
	return copy


static func take_enemy_roster() -> Array[RosterUnitData]:
	var copy := _copy_roster(enemy_roster)
	enemy_roster.clear()
	return copy


static func _copy_roster(units: Array) -> Array[RosterUnitData]:
	var copy: Array[RosterUnitData] = []
	for entry in units:
		var unit := entry as RosterUnitData
		if unit != null:
			copy.append(unit)
	return copy
