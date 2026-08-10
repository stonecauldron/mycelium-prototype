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

@export var display_name: String = "Spore"
@export_range(0, 99, 1) var days_to_mature: int = 2
@export var biomass_cost: int = 4
@export var power_tier: UnitStatsData.PowerTier = UnitStatsData.PowerTier.COMMON
## Lineage death-spore fields (empty / null for shop spores).
@export var lineage_name: String = ""
@export var parent_generation: int = 1
@export var mean_stats: UnitStatsData
@export var weapon_trainings: Array[int] = []
## Copied from fallen unit; seeded onto the plot when planted.
@export var body_mutation: MutationData
@export var cap_mutation: MutationData

var tint: Color:
	get:
		if cap_mutation != null and cap_mutation.tint != Color.WHITE:
			return cap_mutation.tint
		if body_mutation != null and body_mutation.tint != Color.WHITE:
			return body_mutation.tint
		return UnitStatsData.tint_for_tier(power_tier)


func is_lineage_spore() -> bool:
	return not lineage_name.strip_edges().is_empty()


## Authored growth days after Greenhouse seal reduction (fertilizers applied on the plot).
func days_to_mature_effective() -> int:
	return maxi(days_to_mature - SealModifiers.greenhouse_day_reduction(), 0)


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
	if unit.body_mutation != null:
		spore.body_mutation = unit.body_mutation.duplicate(true) as MutationData
	if unit.cap_mutation != null:
		spore.cap_mutation = unit.cap_mutation.duplicate(true) as MutationData
	if unit.stats != null:
		spore.mean_stats = unit.stats.duplicate(true) as UnitStatsData
	spore.weapon_trainings = []
	for training in unit.weapon_trainings:
		spore.weapon_trainings.append(int(training))
	return spore


static func _template_for_unit(unit: RosterUnitData) -> SporeData:
	var tier := UnitStatsData.PowerTier.COMMON
	if unit != null:
		tier = unit.power_tier
	var tier_path: String = _TIER_SPORE_PATHS.get(tier, _COMMON_SPORE_PATH)
	var tier_spore := load(tier_path) as SporeData
	if tier_spore != null:
		return tier_spore
	return load(_COMMON_SPORE_PATH) as SporeData
