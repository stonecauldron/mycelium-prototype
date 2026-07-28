class_name EnemyUnitSpec
extends RefCounted

enum UnitType { MELEE, SPEAR, BOW, SHIELD }

var type: UnitType = UnitType.MELEE
var tier: UnitStatsData.PowerTier = UnitStatsData.PowerTier.WEAK
var is_imago: bool = false
var strain: UnitStrain = null


static func make(
	unit_type: UnitType,
	power_tier: UnitStatsData.PowerTier,
	imago: bool = false,
	unit_strain: UnitStrain = null
) -> EnemyUnitSpec:
	var spec := EnemyUnitSpec.new()
	spec.type = unit_type
	spec.tier = power_tier
	spec.is_imago = imago
	spec.strain = unit_strain
	return spec
