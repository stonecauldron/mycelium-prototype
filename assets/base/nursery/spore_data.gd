class_name SporeData
extends Resource

@export var display_name: String = "Spore"
@export_range(1, 99, 1) var days_to_mature: int = 2
## Extra days past maturity before harvest yields an imago (0 = imago on first READY harvest).
@export_range(0, 99, 1) var extra_days_to_imago: int = 1
@export var biomass_cost: int = 4
@export var power_tier: UnitStatsData.PowerTier = UnitStatsData.PowerTier.COMMON

var tint: Color:
	get:
		return UnitStatsData.tint_for_tier(power_tier)


func grants_imago_at(days_grown: int) -> bool:
	return days_grown >= days_to_mature + extra_days_to_imago
