class_name EnemyUnitData
extends Resource

const STAT_VARIANCE := 1

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var short_description: String = ""
@export var icon: Texture2D
@export var appearance_scene: PackedScene
@export var combat: CombatProfile
## Visual-only held weapon art for mount / scout portraits (combat uses `combat`).
@export var held_weapon: WeaponData
## When false, skip WeaponMount art. Projectiles still use `combat.projectile_scene`.
@export var show_held_weapon: bool = true
## Biomass granted to the player when this enemy dies.
@export_range(0, 99, 1) var biomass_reward: int = 4
## Authored average STR/DEX/CON/SPD. Instances roll ±STAT_VARIANCE via `make_stats()`.
@export var stats: UnitStatsData
## First day this type can appear in procedural armies (1-based).
@export_range(1, 99, 1) var min_day: int = 1
## Relative weight when picking types for army mix.
@export_range(0.0, 100.0, 0.1) var composition_weight: float = 1.0
## Optional combat hooks (on_death, on_hit_taken, …). Null for plain enemies.
@export var effect: StrainEffect


func instantiate_appearance() -> UnitAppearance:
	if appearance_scene == null:
		return null
	return appearance_scene.instantiate() as UnitAppearance


func get_combat_profile() -> CombatProfile:
	if combat != null:
		return combat
	return CombatProfile.new()


## Instance stats from authored averages, each attribute independently ±STAT_VARIANCE.
func make_stats(rng: RandomNumberGenerator = null) -> UnitStatsData:
	var generator := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		generator.randomize()
	var rolled := UnitStatsData.new()
	var base := stats
	if base == null:
		rolled.strength = _roll_stat(UnitStatsData.NEUTRAL_STAT, generator)
		rolled.dex = _roll_stat(UnitStatsData.NEUTRAL_STAT, generator)
		rolled.con = _roll_stat(UnitStatsData.NEUTRAL_STAT, generator)
		rolled.spd = _roll_stat(UnitStatsData.NEUTRAL_STAT, generator)
		return rolled
	rolled.strength = _roll_stat(base.strength, generator)
	rolled.dex = _roll_stat(base.dex, generator)
	rolled.con = _roll_stat(base.con, generator)
	rolled.spd = _roll_stat(base.spd, generator)
	return rolled


func average_stat_sum() -> int:
	if stats == null:
		return UnitStatsData.NEUTRAL_STAT * 4
	return stats.strength + stats.dex + stats.con + stats.spd


func call_effect(method_name: StringName, args: Array = []) -> void:
	if effect == null or not effect.has_method(method_name):
		return
	effect.callv(method_name, args)


func _roll_stat(average: int, rng: RandomNumberGenerator) -> int:
	return clampi(average + rng.randi_range(-STAT_VARIANCE, STAT_VARIANCE), 1, 99)
