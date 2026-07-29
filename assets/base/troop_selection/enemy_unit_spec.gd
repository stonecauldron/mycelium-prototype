class_name EnemyUnitSpec
extends RefCounted

var weapon: WeaponData = null
var tier: UnitStatsData.PowerTier = UnitStatsData.PowerTier.WEAK
var is_imago: bool = false
var strain: UnitStrain = null


static func make(
	unit_weapon: WeaponData,
	power_tier: UnitStatsData.PowerTier,
	imago: bool = false,
	unit_strain: UnitStrain = null
) -> EnemyUnitSpec:
	var spec := EnemyUnitSpec.new()
	spec.weapon = unit_weapon
	spec.tier = power_tier
	spec.is_imago = imago
	spec.strain = unit_strain
	return spec
