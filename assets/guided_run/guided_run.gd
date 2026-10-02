class_name GuidedRun
extends RefCounted

## Authored learning content. Availability follows Days, never a completed action.
const LENGTH := 15
const FEATURE_DAYS := {
	&"progression": 4, &"nursery": 6, &"shop": 7, &"mutations": 8,
	&"squad_slots": 9, &"compost": 11, &"seals": 11,
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
			return day >= 5
	return false


static func specs_for_day(day: int) -> Array[EnemyUnitSpec]:
	var specs: Array[EnemyUnitSpec] = []
	for enemy_id: String in ARMIES[clampi(day, 1, LENGTH) - 1]:
		var path := "res://assets/units/enemies/%s/%s_unit.tres" % [enemy_id, enemy_id]
		var data := load(path) as EnemyUnitData
		for i in int(ARMIES[clampi(day, 1, LENGTH) - 1][enemy_id]):
			specs.append(EnemyUnitSpec.make(data))
	return specs


static func make_starter(adult: bool) -> RosterUnitData:
	var unit_name := "Fern" if adult else "Moss"
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
