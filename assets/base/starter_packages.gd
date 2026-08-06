class_name StarterPackages
extends RefCounted

## Curated starter packages: one Evolved (dual training) + one Adult (base weapon).

const PACKAGE_IDS: Array[StringName] = [
	&"great_sword_spear",
	&"sniper_shield",
	&"halberd_sword",
	&"great_shield_bow",
]


static func all_ids() -> Array[StringName]:
	return PACKAGE_IDS.duplicate()


static func display_name(package_id: StringName) -> String:
	match package_id:
		&"great_sword_spear":
			return "Frontliners"
		&"sniper_shield":
			return "Long-range Death"
		&"halberd_sword":
			return "Pikes"
		&"great_shield_bow":
			return "Fortress"
		_:
			return str(package_id)


## Returns {evolved_schools: Array[int], adult_school: int} or empty if unknown.
static func def_for(package_id: StringName) -> Dictionary:
	match package_id:
		&"great_sword_spear":
			return {
				"evolved_schools": [WeaponSchool.Id.SWORD, WeaponSchool.Id.SWORD],
				"adult_school": WeaponSchool.Id.SPEAR,
			}
		&"sniper_shield":
			return {
				"evolved_schools": [WeaponSchool.Id.BOW, WeaponSchool.Id.BOW],
				"adult_school": WeaponSchool.Id.SHIELD,
			}
		&"halberd_sword":
			return {
				"evolved_schools": [WeaponSchool.Id.SPEAR, WeaponSchool.Id.SPEAR],
				"adult_school": WeaponSchool.Id.SWORD,
			}
		&"great_shield_bow":
			return {
				"evolved_schools": [WeaponSchool.Id.SHIELD, WeaponSchool.Id.SHIELD],
				"adult_school": WeaponSchool.Id.BOW,
			}
		_:
			return {}


static func evolved_weapon(package_id: StringName) -> WeaponData:
	var def := def_for(package_id)
	if def.is_empty():
		return null
	var schools: Array = def["evolved_schools"]
	return WeaponSchool.resolve_weapon(schools, true)


static func adult_weapon(package_id: StringName) -> WeaponData:
	var def := def_for(package_id)
	if def.is_empty():
		return null
	return WeaponSchool.resolve_weapon([int(def["adult_school"])], true)


static func build_units(package_id: StringName) -> Array[RosterUnitData]:
	var def := def_for(package_id)
	var units: Array[RosterUnitData] = []
	if def.is_empty():
		return units
	var names := UnitNames.pick_unique(2)
	var evolved := _make_evolved(names[0], def["evolved_schools"])
	var adult := _make_adult(names[1], int(def["adult_school"]))
	if evolved != null:
		units.append(evolved)
	if adult != null:
		units.append(adult)
	units.sort_custom(_compare_by_range_class)
	return units


## Squad slot order: ranged, mid, melee.
static func _compare_by_range_class(a: RosterUnitData, b: RosterUnitData) -> bool:
	return _range_sort_key(a) < _range_sort_key(b)


static func _range_sort_key(unit: RosterUnitData) -> int:
	if unit == null or unit.weapon == null:
		return 99
	match unit.weapon.formation_line:
		WeaponData.FormationLine.BACK:
			return 0
		WeaponData.FormationLine.MID:
			return 1
		WeaponData.FormationLine.FRONT:
			return 2
		_:
			return 99


static func _make_adult(unit_name: String, school: int) -> RosterUnitData:
	var unit := _make_blank(unit_name)
	if unit == null:
		return null
	# Starters skip pupation gate (adults can no longer seal in play).
	WeaponSchool.apply_school_stats(unit.stats, school)
	unit.weapon_trainings.append(school)
	unit.promote_to_imago(false)
	unit.sync_weapon_from_trainings()
	return unit


static func _make_evolved(unit_name: String, schools: Array) -> RosterUnitData:
	var unit := _make_blank(unit_name)
	if unit == null:
		return null
	for school in schools:
		WeaponSchool.apply_school_stats(unit.stats, int(school))
		unit.weapon_trainings.append(int(school))
	unit.promote_to_fully_evolved()
	unit.sync_weapon_from_trainings()
	return unit


static func _make_blank(unit_name: String) -> RosterUnitData:
	var stats := UnitStatsData.create_for_tier(UnitStatsData.PowerTier.COMMON)
	return RosterUnitData.create(
		unit_name,
		stats,
		WeaponSchool.sickle(),
		null,
		UnitStatsData.PowerTier.COMMON
	)
