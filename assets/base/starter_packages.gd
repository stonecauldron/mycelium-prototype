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
	return units


static func _make_adult(unit_name: String, school: int) -> RosterUnitData:
	var unit := _make_blank(unit_name)
	if unit == null:
		return null
	unit.apply_pupation_training(school)
	return unit


static func _make_evolved(unit_name: String, schools: Array) -> RosterUnitData:
	var unit := _make_blank(unit_name)
	if unit == null:
		return null
	for school in schools:
		unit.apply_pupation_training(int(school))
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
