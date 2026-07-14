class_name RosterUnitData
extends Resource

const _DEFAULT_STRAIN := preload("res://assets/units/capling/capling_strain.tres")

@export var display_name: String = "Unit"
@export var stats: UnitStatsData
@export var weapon: WeaponData
@export var strain: UnitStrain


func get_range_class() -> WeaponData.WeaponRange:
	if weapon == null:
		return WeaponData.WeaponRange.MELEE
	return weapon.range_class


static func create(
	unit_name: String,
	unit_stats: UnitStatsData,
	unit_weapon: WeaponData,
	unit_strain: UnitStrain = null
) -> RosterUnitData:
	var data := RosterUnitData.new()
	data.display_name = unit_name
	data.stats = unit_stats
	data.weapon = unit_weapon
	data.strain = unit_strain if unit_strain != null else _DEFAULT_STRAIN
	return data
