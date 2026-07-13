class_name RosterUnitData
extends Resource

@export var display_name: String = "Unit"
@export var stats: UnitStatsData
@export var weapon: WeaponData


func get_range_class() -> WeaponData.WeaponRange:
	if weapon == null:
		return WeaponData.WeaponRange.MELEE
	return weapon.range_class


static func create(
	unit_name: String,
	unit_stats: UnitStatsData,
	unit_weapon: WeaponData
) -> RosterUnitData:
	var data := RosterUnitData.new()
	data.display_name = unit_name
	data.stats = unit_stats
	data.weapon = unit_weapon
	return data
