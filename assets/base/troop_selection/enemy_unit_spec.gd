class_name EnemyUnitSpec
extends RefCounted

var unit_data: EnemyUnitData = null


static func make(enemy_unit: EnemyUnitData) -> EnemyUnitSpec:
	var spec := EnemyUnitSpec.new()
	spec.unit_data = enemy_unit
	return spec
