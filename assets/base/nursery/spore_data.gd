class_name SporeData
extends Resource

const _COMMON_SPORE_PATH := "res://assets/base/nursery/common_spore.tres"
const _TIER_SPORE_PATHS := {
	UnitStatsData.PowerTier.COMMON: "res://assets/base/nursery/common_spore.tres",
	UnitStatsData.PowerTier.UNCOMMON: "res://assets/base/nursery/uncommon_spore.tres",
	UnitStatsData.PowerTier.RARE: "res://assets/base/nursery/rare_spore.tres",
	UnitStatsData.PowerTier.EPIC: "res://assets/base/nursery/epic_spore.tres",
	UnitStatsData.PowerTier.LEGENDARY: "res://assets/base/nursery/legendary_spore.tres",
}
const _STRAIN_SPORE_PATHS: Array[String] = [
	"res://assets/base/nursery/spores/death_cap_spore.tres",
	"res://assets/base/nursery/spores/inky_cap_spore.tres",
	"res://assets/base/nursery/spores/boom_cap_spore.tres",
	"res://assets/base/nursery/spores/mini_cap_spore.tres",
	"res://assets/base/nursery/spores/lanky_cap_spore.tres",
	"res://assets/base/nursery/spores/fat_cap_spore.tres",
	"res://assets/base/nursery/spores/wall_cap_spore.tres",
	"res://assets/base/nursery/spores/bank_cap_spore.tres",
	"res://assets/base/nursery/spores/zombie_cap_spore.tres",
	"res://assets/base/nursery/spores/rubber_cap_spore.tres",
	"res://assets/base/nursery/spores/brood_empress_spore.tres",
]

@export var display_name: String = "Spore"
@export_range(0, 99, 1) var days_to_mature: int = 2
@export var biomass_cost: int = 4
@export var power_tier: UnitStatsData.PowerTier = UnitStatsData.PowerTier.COMMON
@export var strain: UnitStrain
## Lineage death-spore fields (empty / null for shop spores).
@export var lineage_name: String = ""
@export var parent_generation: int = 1
@export var mean_stats: UnitStatsData
@export var weapon_trainings: Array[int] = []

var tint: Color:
	get:
		var resolved := resolved_strain()
		# Specialty strains use their own color; white means untinted → rarity.
		if resolved != null and resolved.tint != Color.WHITE:
			return resolved.tint
		return UnitStatsData.tint_for_tier(power_tier)


func is_lineage_spore() -> bool:
	return not lineage_name.strip_edges().is_empty()


## Extra days past maturity before harvest yields an imago.
## Half the strain's days-to-imago, floored, with a minimum of 1.
func extra_days_to_imago() -> int:
	var resolved := resolved_strain()
	var days := resolved.days_to_imago if resolved != null else 2
	return maxi(1, int(days / 2.0))


func grants_imago_at(days_grown: int, days_required: int = -1) -> bool:
	var mature_at := days_to_mature if days_required < 0 else days_required
	return days_grown >= mature_at + extra_days_to_imago()


func resolved_strain() -> UnitStrain:
	if strain != null:
		return strain
	return load("res://assets/units/generalist/generalist_strain.tres") as UnitStrain


static func from_fallen_unit(unit: RosterUnitData) -> SporeData:
	if unit == null:
		return null
	var lineage := unit.lineage_name.strip_edges()
	if lineage.is_empty():
		lineage = unit.display_name.strip_edges()
	if lineage.is_empty():
		lineage = "Unit"
	var template := _template_for_unit(unit)
	var spore := SporeData.new()
	if template != null:
		spore.days_to_mature = template.days_to_mature
		spore.biomass_cost = template.biomass_cost
	else:
		spore.days_to_mature = 2
		spore.biomass_cost = 4
	spore.display_name = "%s's spores" % lineage
	spore.lineage_name = lineage
	spore.parent_generation = maxi(unit.generation, 1)
	spore.power_tier = unit.power_tier
	spore.strain = unit.strain
	if unit.stats != null:
		spore.mean_stats = unit.stats.duplicate(true) as UnitStatsData
	spore.weapon_trainings = []
	for training in unit.weapon_trainings:
		spore.weapon_trainings.append(int(training))
	return spore


static func _template_for_unit(unit: RosterUnitData) -> SporeData:
	if unit != null and unit.strain != null:
		var strain_path := unit.strain.resource_path
		if not strain_path.is_empty():
			for path in _STRAIN_SPORE_PATHS:
				var candidate := load(path) as SporeData
				if candidate == null or candidate.strain == null:
					continue
				if candidate.strain.resource_path == strain_path:
					return candidate
	var tier := UnitStatsData.PowerTier.COMMON
	if unit != null:
		tier = unit.power_tier
	var tier_path: String = _TIER_SPORE_PATHS.get(tier, _COMMON_SPORE_PATH)
	var tier_spore := load(tier_path) as SporeData
	if tier_spore != null:
		return tier_spore
	return load(_COMMON_SPORE_PATH) as SporeData
