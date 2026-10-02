class_name GuidedRun
extends RefCounted

## Authored learning content. Availability follows Days, never a completed action.
const LENGTH := 15
const MAX_PLOT_COUNT := 2
const SEAL_CHOICE_DAYS: Array[int] = [11, 13, 15]
const FEATURE_DAYS := {
	&"progression": 4, &"nursery": 6, &"shop": 7, &"mutations": 8,
	&"squad_slots": 9, &"plot_slots": 9, &"compost": 11, &"seals": 11,
	&"full_shop": 12, &"shop_reroll": 12, &"offer_locks": 12, &"full_seal_pool": 13,
}
const _FEATURE_UNLOCK_PRESENTATION := {
	&"progression": {
		"label": "Daily progression",
		"icon": preload("res://assets/base/combat_progress_track/skull.png"),
	},
	&"nursery": {
		"label": "Nursery",
		"icon": preload("res://assets/base/plot_tile/growth0.png"),
	},
	&"shop": {
		"label": "Shop · Quick Growth",
		"icon": preload("res://assets/base/nursery/fertilizers/fertiliser.png"),
	},
	&"mutations": {
		"label": "Thorny Mutation",
		"icon": preload("res://assets/base/nursery/mutations/mutation_icon.png"),
	},
	&"squad_slots": {
		"label": "Squad expansion",
		"icon": preload("res://assets/combat/flag_bearer/flag.png"),
	},
	&"plot_slots": {
		"label": "Plot expansion",
		"icon": preload("res://assets/base/plot_tile/plot_empty.png"),
	},
	&"compost": {
		"label": "Compost",
		"icon": preload("res://assets/base/composting_bin/composting_bin.png"),
	},
	&"seals": {
		"label": "Seals",
		"icon": preload("res://assets/base/seals/seal.png"),
	},
	# The full Shop card includes its catalogs, rerolls, and offer locks.
	&"full_shop": {
		"label": "Full Shop",
		"icon": preload("res://assets/base/nursery/fertilizers/fertiliser.png"),
	},
	&"full_seal_pool": {
		"label": "Full Seal pool",
		"icon": preload("res://assets/base/seals/seal.png"),
	},
}
const QUICK_GROWTH := preload("res://assets/base/nursery/fertilizers/quick_growth.tres")
const THORNY := preload("res://assets/base/nursery/mutations/body/thorny.tres")
const SEALS: Array[SealData] = [
	preload("res://assets/base/seals/wooden_sword.tres"),
	preload("res://assets/base/seals/wooden_bow.tres"),
	preload("res://assets/base/seals/wooden_heart.tres"),
]
## Small, readable formations; elite Days use Strong enemies. See ADR-0015 exception.
const ARMIES: Array[Dictionary] = [
	{"solar_sword": 1},
	{"solar_sword": 2},
	{"solar_sword": 3},
	{"peashooter": 1, "solar_sword": 2},
	{"log": 1},
	{"peashooter": 1, "solar_sword": 3},
	{"rose_thorn": 1, "solar_sword": 3},
	{"peashooter": 2, "solar_sword": 3},
	{"stump": 1, "solar_sword": 3},
	{"log": 1, "solar_cleaver": 1},
	{"peashooter": 1, "stump": 1, "solar_sword": 3},
	{"peashooter": 2, "stump": 1, "solar_sword": 4},
	{"peashooter": 2, "stump": 2, "rose_thorn": 2},
	{"peashooter": 3, "stump": 2, "solar_sword": 3},
	{"canopy": 1, "log": 1, "solar_cleaver": 2},
]
const BUDGETS: Array[Vector2i] = [
	Vector2i(6, 12), Vector2i(12, 18), Vector2i(18, 24), Vector2i(18, 30),
	Vector2i(82, 111), # Single Log deliberately uses the normal Day-5 reward range.
	Vector2i(24, 36), Vector2i(24, 38), Vector2i(30, 44), Vector2i(30, 48),
	Vector2i(42, 66), Vector2i(36, 54), Vector2i(48, 66), Vector2i(48, 72),
	Vector2i(54, 84), Vector2i(78, 110),
]


static func feature_available(feature: StringName, day: int) -> bool:
	return FEATURE_DAYS.has(feature) and day >= int(FEATURE_DAYS[feature])


static func school_available(school: int, day: int) -> bool:
	match school:
		WeaponSchool.Id.BOW:
			return day >= 2
		WeaponSchool.Id.SWORD:
			return day >= 3
		WeaponSchool.Id.MACE:
			return day >= 4
		WeaponSchool.Id.SHIELD:
			return day >= 8
		WeaponSchool.Id.SPEAR:
			return day >= 13
	return false


## Systems first available in this preparation Day, not recurring rewards.
static func unlocks_for_day(day: int) -> Array[Dictionary]:
	var unlocks: Array[Dictionary] = []
	if day < 1 or day > LENGTH:
		return unlocks
	for school in WeaponSchool.DISPLAY_ORDER:
		if not school_available(school, day) or school_available(school, day - 1):
			continue
		var weapon := WeaponSchool.load_weapon(WeaponSchool.base_weapon_path(school))
		unlocks.append({
			"id": StringName("school_%d" % school),
			"label": "%s Training" % WeaponSchool.display_name(school),
			"icon": weapon.icon,
		})
	for feature: StringName in _FEATURE_UNLOCK_PRESENTATION:
		if not feature_available(feature, day) or feature_available(feature, day - 1):
			continue
		var presentation: Dictionary = _FEATURE_UNLOCK_PRESENTATION[feature]
		unlocks.append({
			"id": feature,
			"label": presentation["label"],
			"icon": presentation["icon"],
		})
	return unlocks


static func specs_for_day(day: int) -> Array[EnemyUnitSpec]:
	var specs: Array[EnemyUnitSpec] = []
	for enemy_id: String in ARMIES[clampi(day, 1, LENGTH) - 1]:
		var path := "res://assets/units/enemies/%s/%s_unit.tres" % [enemy_id, enemy_id]
		var data := load(path) as EnemyUnitData
		for i in int(ARMIES[clampi(day, 1, LENGTH) - 1][enemy_id]):
			specs.append(EnemyUnitSpec.make(data))
	return specs


static func make_starter(adult: bool) -> RosterUnitData:
	# Resolve the same distinct pair when the reserved Child arrives on Day 2.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([GameState.run_seed, "guided-starter-names"])
	var names := UnitNames.pick_unique(2, rng)
	var unit_name := names[0] if adult else names[1]
	var unit := RosterUnitData.create(
		unit_name, UnitStatsData.average_for_tier(UnitStatsData.PowerTier.COMMON),
		WeaponSchool.sickle(), UnitStatsData.PowerTier.COMMON
	)
	if adult:
		unit.generation = 2
		unit.display_name = UnitNames.format_unit_name(unit.lineage_name, unit.generation)
		WeaponSchool.apply_school_stats(unit.stats, WeaponSchool.Id.SWORD)
		unit.weapon_trainings.append(WeaponSchool.Id.SWORD)
		unit.promote_to_imago()
	unit.sync_weapon_from_trainings()
	return unit


static func make_shop_offer(slot_index: int) -> ShopOffer:
	if not GameState.is_guided_shop_slot_available(slot_index):
		return null
	var offer := ShopOffer.new()
	if slot_index == 0:
		offer.item = QUICK_GROWTH
		offer.cost = QUICK_GROWTH.biomass_cost
	else:
		offer.item = THORNY
		offer.cost = THORNY.biomass_cost
	return offer
