class_name RosterUnitData
extends Resource

const _DEFAULT_VISUAL := preload("res://assets/units/capling/capling_visual.tres")

@export var display_name: String = "Unit"
@export var stats: UnitStatsData
@export var weapon: WeaponData
@export var visual: UnitVisualData


func get_range_class() -> WeaponData.WeaponRange:
	if weapon == null:
		return WeaponData.WeaponRange.MELEE
	return weapon.range_class


static func create(
	unit_name: String,
	unit_stats: UnitStatsData,
	unit_weapon: WeaponData,
	unit_visual: UnitVisualData = null
) -> RosterUnitData:
	var data := RosterUnitData.new()
	data.display_name = unit_name
	data.stats = unit_stats
	data.weapon = unit_weapon
	data.visual = unit_visual if unit_visual != null else _DEFAULT_VISUAL
	return data
