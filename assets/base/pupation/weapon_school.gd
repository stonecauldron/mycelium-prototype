class_name WeaponSchool
extends RefCounted

## Training schools for pupation. Order is stable for slot indices.
enum Id { SWORD, SHIELD, SPEAR, BOW }

const COUNT := 4
const COCOON_COST := 3
## Days in a cocoon before emerge (day advances tick this down).
const COCOON_DURATION_DAYS := 1

const _SICKLE_PATH := "res://assets/weapons/sickle/sickle.tres"
const _SCYTHE_PATH := "res://assets/weapons/scythe/scythe.tres"
const _SWORD_PATH := "res://assets/weapons/sword/sword.tres"
const _SHIELD_PATH := "res://assets/weapons/shield/shield.tres"
const _SPEAR_PATH := "res://assets/weapons/spear/spear.tres"
const _BOW_PATH := "res://assets/weapons/bow/bow.tres"
const _GREAT_SWORD_PATH := "res://assets/weapons/great_sword/great_sword.tres"
const _MACE_PATH := "res://assets/weapons/mace/mace.tres"
const _LANCE_PATH := "res://assets/weapons/lance/lance.tres"
const _CROSSBOW_PATH := "res://assets/weapons/crossbow/crossbow.tres"
const _GREAT_SHIELD_PATH := "res://assets/weapons/great_shield/great_shield.tres"
const _GREAT_HAMMER_PATH := "res://assets/weapons/great_hammer/great_hammer.tres"
const _UMBRELLA_PATH := "res://assets/weapons/umbrella/umbrella.tres"
const _HALBERD_PATH := "res://assets/weapons/halberd/halberd.tres"
const _MORTAR_PATH := "res://assets/weapons/mortar/mortar.tres"
const _SNIPER_PATH := "res://assets/weapons/sniper/sniper.tres"

## school -> { strength, dex, con, spd }
const SCHOOL_STAT_DELTAS := {
	0: {"strength": 3, "dex": -1, "con": 2, "spd": 0},
	1: {"strength": 1, "dex": 0, "con": 4, "spd": -1},
	2: {"strength": 1, "dex": 1, "con": -1, "spd": 3},
	3: {"strength": 0, "dex": 3, "con": -1, "spd": 2},
}

const DISPLAY_NAMES := {
	0: "Sword",
	1: "Shield",
	2: "Spear",
	3: "Bow",
}


static func display_name(school: int) -> String:
	return str(DISPLAY_NAMES.get(school, "School"))


static func base_weapon_path(school: int) -> String:
	match school:
		Id.SWORD:
			return _SWORD_PATH
		Id.SHIELD:
			return _SHIELD_PATH
		Id.SPEAR:
			return _SPEAR_PATH
		Id.BOW:
			return _BOW_PATH
		_:
			return _SICKLE_PATH


static func combo_weapon_path(a: int, b: int) -> String:
	var lo := mini(a, b)
	var hi := maxi(a, b)
	if lo == hi:
		match lo:
			Id.SWORD:
				return _GREAT_SWORD_PATH
			Id.SHIELD:
				return _GREAT_SHIELD_PATH
			Id.SPEAR:
				return _HALBERD_PATH
			Id.BOW:
				return _SNIPER_PATH
	# Unique pairs (lo, hi)
	if lo == Id.SWORD and hi == Id.SHIELD:
		return _MACE_PATH
	if lo == Id.SWORD and hi == Id.SPEAR:
		return _LANCE_PATH
	if lo == Id.SWORD and hi == Id.BOW:
		return _CROSSBOW_PATH
	if lo == Id.SHIELD and hi == Id.SPEAR:
		return _GREAT_HAMMER_PATH
	if lo == Id.SHIELD and hi == Id.BOW:
		return _UMBRELLA_PATH
	if lo == Id.SPEAR and hi == Id.BOW:
		return _MORTAR_PATH
	return _SICKLE_PATH


static func load_weapon(path: String) -> WeaponData:
	return load(path) as WeaponData


static func sickle() -> WeaponData:
	return load_weapon(_SICKLE_PATH)


static func scythe() -> WeaponData:
	return load_weapon(_SCYTHE_PATH)


static func resolve_weapon_path(trainings: Array, is_adult_stage: bool) -> String:
	var n := trainings.size()
	if n <= 0:
		return _SCYTHE_PATH if is_adult_stage else _SICKLE_PATH
	if n == 1:
		return base_weapon_path(int(trainings[0]))
	return combo_weapon_path(int(trainings[0]), int(trainings[1]))


static func resolve_weapon(trainings: Array, is_adult_stage: bool) -> WeaponData:
	return load_weapon(resolve_weapon_path(trainings, is_adult_stage))


## Gen 1–2 full gains; each generation after 2 halves again.
static func generation_gain_scale(generation: int) -> float:
	if generation <= 2:
		return 1.0
	return 1.0 / pow(2.0, float(generation - 2))


## Scale a single stat delta toward zero for the unit's generation.
static func scale_stat_delta(delta: int, generation: int) -> int:
	var scale := generation_gain_scale(generation)
	if is_equal_approx(scale, 1.0):
		return delta
	# int() truncates toward zero in GDScript.
	return int(float(delta) * scale)


static func is_retrain(unit: RosterUnitData) -> bool:
	return (
		unit != null
		and unit.life_stage_id == UnitStrain.STAGE_JUVENILE
		and unit.weapon_trainings.size() >= 2
	)


## Resulting training list after emerge (evict oldest when already at 2).
static func trainings_after_training(trainings: Array, new_school: int) -> Array[int]:
	var next: Array[int] = []
	for t in trainings:
		next.append(int(t))
	if next.size() >= 2:
		next.pop_front()
	next.append(new_school)
	return next


static func preview_weapon_after_training(
	trainings: Array,
	new_school: int,
	will_be_adult: bool
) -> WeaponData:
	var next := trainings_after_training(trainings, new_school)
	return resolve_weapon(next, will_be_adult)


static func apply_school_stats(
	stats: UnitStatsData,
	school: int,
	generation: int = 1
) -> void:
	if stats == null:
		return
	var deltas := scaled_school_deltas(school, generation)
	stats.strength = clampi(stats.strength + int(deltas.get("strength", 0)), 1, 99)
	stats.dex = clampi(stats.dex + int(deltas.get("dex", 0)), 1, 99)
	stats.con = clampi(stats.con + int(deltas.get("con", 0)), 1, 99)
	stats.spd = clampi(stats.spd + int(deltas.get("spd", 0)), 1, 99)


static func school_stat_deltas(school: int) -> Dictionary:
	return SCHOOL_STAT_DELTAS.get(school, {
		"strength": 0, "dex": 0, "con": 0, "spd": 0
	}) as Dictionary


static func scaled_school_deltas(school: int, generation: int = 1) -> Dictionary:
	var raw := school_stat_deltas(school)
	return {
		"strength": scale_stat_delta(int(raw.get("strength", 0)), generation),
		"dex": scale_stat_delta(int(raw.get("dex", 0)), generation),
		"con": scale_stat_delta(int(raw.get("con", 0)), generation),
		"spd": scale_stat_delta(int(raw.get("spd", 0)), generation),
	}


static func preview_stats_after_training(
	stats: UnitStatsData,
	school: int,
	generation: int = 1
) -> UnitStatsData:
	if stats == null:
		return null
	var preview := stats.duplicate(true) as UnitStatsData
	apply_school_stats(preview, school, generation)
	return preview


static func school_stat_delta_text(school: int, generation: int = 1) -> String:
	var deltas := scaled_school_deltas(school, generation)
	var parts: PackedStringArray = []
	var keys: Array[String] = ["strength", "dex", "con", "spd"]
	for key in keys:
		var v := int(deltas.get(key, 0))
		if v == 0:
			continue
		var label: String = "STR"
		match key:
			"strength":
				label = "STR"
			"dex":
				label = "DEX"
			"con":
				label = "CON"
			"spd":
				label = "SPD"
		parts.append("%+d %s" % [v, label])
	return "  ".join(parts)


static func resulting_training_count(unit: RosterUnitData) -> int:
	if unit == null:
		return 1
	if unit.weapon_trainings.size() >= 2:
		return 2
	return unit.weapon_trainings.size() + 1


static func next_stage_after_training(unit: RosterUnitData) -> StringName:
	if resulting_training_count(unit) >= 2:
		return UnitStrain.STAGE_FULLY_EVOLVED
	return UnitStrain.STAGE_IMAGO


## Non-mutating preview of the unit after finishing this school's pupation.
static func preview_emerged_unit(unit: RosterUnitData, school: int) -> RosterUnitData:
	if unit == null or school < 0 or school >= COUNT:
		return null
	var generation := maxi(unit.generation, 1)
	var next_trainings := trainings_after_training(unit.weapon_trainings, school)
	var next_stage := next_stage_after_training(unit)
	var next_weapon := resolve_weapon(next_trainings, true)
	var preview_stats := preview_stats_after_training(unit.stats, school, generation)
	var data := RosterUnitData.new()
	data.display_name = unit.display_name
	data.lineage_name = unit.lineage_name
	data.generation = unit.generation
	data.stats = preview_stats
	data.weapon = next_weapon
	data.strain = unit.strain
	data.power_tier = unit.power_tier
	data.life_stage_id = next_stage
	data.is_imago = next_stage != UnitStrain.STAGE_JUVENILE
	data.days_alive = unit.days_alive
	data.max_days_alive = unit.max_days_alive
	data.weapon_trainings = next_trainings
	if next_weapon != null:
		data.combat = next_weapon.get_combat_profile()
	return data


static func stage_display_name(stage_id: StringName) -> String:
	if stage_id == UnitStrain.STAGE_FULLY_EVOLVED:
		return "Evolved"
	if stage_id == UnitStrain.STAGE_IMAGO:
		return "Adult"
	return "Child"


static func day_word(days: int = COCOON_DURATION_DAYS) -> String:
	return "day" if days == 1 else "days"
