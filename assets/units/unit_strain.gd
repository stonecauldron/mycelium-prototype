class_name UnitStrain
extends Resource

const STAGE_JUVENILE := &"juvenile"
const STAGE_IMAGO := &"imago"
const JUVENILE_SCALE_FALLBACK := 0.8
const NO_LIFE_EXPECTANCY := -1

@export var display_name: String = "Generalist"
@export_multiline var short_description: String = ""
@export_range(0, 99, 1) var days_to_imago: int = 2
@export var life_stages: Array[StrainLifeStage] = []
@export var effect: StrainEffect
## When false, harvest always rolls Common regardless of spore power_tier.
@export var use_power_tier: bool = true
@export var strength_delta: int = 0
@export var dex_delta: int = 0
@export var con_delta: int = 0
@export var spd_delta: int = 0
## Multiplies the rolled hatch stats (e.g. Magikarp 0.25). Applied before deltas.
@export_range(0.0, 4.0, 0.01) var hatch_stat_fraction: float = 1.0
## Extra flat bonus applied on imago promotion (after global +2).
@export var imago_stat_delta: int = 0
## Inclusive range rolled at hatch into RosterUnitData.max_days_alive. -1 = no limit.
@export var life_expectancy_min: int = NO_LIFE_EXPECTANCY
@export var life_expectancy_max: int = NO_LIFE_EXPECTANCY
## How many roster units one harvest yields (Zerglings later).
@export_range(1, 9, 1) var hatch_count: int = 1
@export_range(0.05, 1.0, 0.05) var juvenile_scale_fallback: float = JUVENILE_SCALE_FALLBACK


func get_stage(stage_id: StringName) -> StrainLifeStage:
	for stage in life_stages:
		if stage != null and stage.id == stage_id:
			return stage
	return null


func appearance_for(stage_id: StringName) -> PackedScene:
	var stage := get_stage(stage_id)
	if stage == null:
		return null
	return stage.appearance_scene


func stage_after(stage_id: StringName) -> StrainLifeStage:
	for i in life_stages.size():
		var stage := life_stages[i]
		if stage != null and stage.id == stage_id:
			if i + 1 < life_stages.size():
				return life_stages[i + 1]
			return null
	return null


func instantiate_appearance(stage_id: StringName = STAGE_JUVENILE) -> UnitAppearance:
	var used_fallback_scale := false
	var scene := appearance_for(stage_id)
	if scene == null and stage_id == STAGE_JUVENILE:
		scene = appearance_for(STAGE_IMAGO)
		used_fallback_scale = scene != null
	if scene == null:
		for stage in life_stages:
			if stage != null and stage.appearance_scene != null:
				scene = stage.appearance_scene
				break
	if scene == null:
		return null
	var appearance := scene.instantiate() as UnitAppearance
	if appearance == null:
		return null
	if used_fallback_scale:
		appearance.apply_body_scale(juvenile_scale_fallback)
	return appearance


func apply_hatch_stats(stats: UnitStatsData) -> void:
	if stats == null:
		return
	if not is_equal_approx(hatch_stat_fraction, 1.0):
		stats.strength = maxi(1, roundi(float(stats.strength) * hatch_stat_fraction))
		stats.dex = maxi(1, roundi(float(stats.dex) * hatch_stat_fraction))
		stats.con = maxi(1, roundi(float(stats.con) * hatch_stat_fraction))
		stats.spd = maxi(1, roundi(float(stats.spd) * hatch_stat_fraction))
	stats.strength = clampi(stats.strength + strength_delta, 1, 99)
	stats.dex = clampi(stats.dex + dex_delta, 1, 99)
	stats.con = clampi(stats.con + con_delta, 1, 99)
	stats.spd = clampi(stats.spd + spd_delta, 1, 99)


func roll_max_days_alive(rng: RandomNumberGenerator = null) -> int:
	if life_expectancy_min < 0 or life_expectancy_max < 0:
		return NO_LIFE_EXPECTANCY
	var lo := mini(life_expectancy_min, life_expectancy_max)
	var hi := maxi(life_expectancy_min, life_expectancy_max)
	var generator := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		generator.randomize()
	return generator.randi_range(lo, hi)


func call_effect(method: StringName, args: Array = []) -> void:
	if effect == null or not effect.has_method(method):
		return
	effect.callv(method, args)
