class_name SporeData
extends Resource

@export var display_name: String = "Spore"
@export_range(1, 99, 1) var days_to_mature: int = 2
@export var biomass_cost: int = 4
@export var power_tier: UnitStatsData.PowerTier = UnitStatsData.PowerTier.AVERAGE
@export var tint: Color = Color.WHITE
