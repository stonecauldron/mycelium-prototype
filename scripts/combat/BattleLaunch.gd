class_name BattleLaunch
extends RefCounted

## Enemy roster handoff from Base → CombatStage. Player lineup comes from ArmyData.
static var enemy_roster: Array[RosterUnitData] = []


static func set_enemy_roster(enemy_units: Array) -> void:
	enemy_roster = _copy_roster(enemy_units)


static func has_enemy_roster() -> bool:
	return not enemy_roster.is_empty()


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
