class_name SporeData
extends Resource

@export var display_name: String = "Spore"
@export_range(0, 99, 1) var days_to_mature: int = 2
@export var biomass_cost: int = 4
@export var power_tier: UnitStatsData.PowerTier = UnitStatsData.PowerTier.COMMON
@export var strain: UnitStrain

var tint: Color:
	get:
		var resolved := resolved_strain()
		# Specialty strains use their own color; white means untinted → rarity.
		if resolved != null and resolved.tint != Color.WHITE:
			return resolved.tint
		return UnitStatsData.tint_for_tier(power_tier)


## Extra days past maturity before harvest yields an imago.
## Half the strain's days-to-imago, floored, with a minimum of 1.
func extra_days_to_imago() -> int:
	var resolved := resolved_strain()
	var days := resolved.days_to_imago if resolved != null else 2
	return maxi(1, days / 2)


func grants_imago_at(days_grown: int, days_required: int = -1) -> bool:
	var mature_at := days_to_mature if days_required < 0 else days_required
	return days_grown >= mature_at + extra_days_to_imago()


func resolved_strain() -> UnitStrain:
	if strain != null:
		return strain
	return load("res://assets/units/generalist/generalist_strain.tres") as UnitStrain
