class_name EnemyUnitSpec
extends RefCounted

var unit_data: EnemyUnitData = null
var tier: UnitStatsData.PowerTier = UnitStatsData.PowerTier.FEEBLE


static func make(
	enemy_unit: EnemyUnitData,
	power_tier: UnitStatsData.PowerTier
) -> EnemyUnitSpec:
	var spec := EnemyUnitSpec.new()
	spec.unit_data = enemy_unit
	spec.tier = power_tier
	return spec
