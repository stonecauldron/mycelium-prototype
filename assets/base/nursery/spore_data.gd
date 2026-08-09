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
## Prepared Body mutation (lineage only; Fertilizers never ride spores).
@export var body_mutation: MutationData
## Prepared Cap mutation (lineage only; Fertilizers never ride spores).
@export var cap_mutation: MutationData

var tint: Color:
	get:
		var resolved := resolved_strain()
		# Specialty strains use their own color; white means untinted → rarity.
		if resolved != null and resolved.tint != Color.WHITE:
			return resolved.tint
		return UnitStatsData.tint_for_tier(power_tier)


func is_lineage_spore() -> bool:
	return not lineage_name.strip_edges().is_empty()


## Authored growth days after Greenhouse seal reduction (fertilizers applied on the plot).
func days_to_mature_effective() -> int:
	return maxi(days_to_mature - SealModifiers.greenhouse_day_reduction(), 0)


func resolved_strain() -> UnitStrain:
	if strain != null:
		return strain
	return load("res://assets/units/generalist/generalist_strain.tres") as UnitStrain


## Mutations can be prepped on lineage spores in Stock; replace consumes the previous.
func can_apply_mutation() -> bool:
	return is_lineage_spore()


## Assigns mutation to its Body/Cap slot. Same-kind replace consumes the previous.
func apply_mutation(mutation: MutationData) -> bool:
	if mutation == null or not can_apply_mutation():
		return false
	if mutation.is_body():
		body_mutation = mutation
		return true
	if mutation.is_cap():
		cap_mutation = mutation
		return true
	return false


func mutation_tooltip_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	if body_mutation != null:
		lines.append(
			"Body: %s — %s" % [body_mutation.display_name, body_mutation.subtitle_text()]
		)
	if cap_mutation != null:
		lines.append(
			"Cap: %s — %s" % [cap_mutation.display_name, cap_mutation.subtitle_text()]
		)
	return lines


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
	# Snapshot Body/Cap Mutations only — Fertilizer items never ride lineage spores
	# (baked stat effects may still be present via mean_stats).
	spore.body_mutation = (
		unit.body_mutation.duplicate(true) as MutationData if unit.body_mutation != null else null
	)
	spore.cap_mutation = (
		unit.cap_mutation.duplicate(true) as MutationData if unit.cap_mutation != null else null
	)
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
