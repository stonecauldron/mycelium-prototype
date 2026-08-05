class_name PupationData
extends Resource

## One cocoon occupant per weapon school (index = WeaponSchool.Id).
@export var occupants: Array = []
## Days left until emerge for each school slot (0 when empty).
@export var days_remaining: Array = []


func _init() -> void:
	_ensure_slots()


func _ensure_slots() -> void:
	if occupants.size() != WeaponSchool.COUNT:
		occupants.resize(WeaponSchool.COUNT)
	if days_remaining.size() != WeaponSchool.COUNT:
		days_remaining.resize(WeaponSchool.COUNT)
	for i in WeaponSchool.COUNT:
		if i >= occupants.size():
			occupants.append(null)
		if i >= days_remaining.size():
			days_remaining.append(0)
		if occupants[i] == null:
			days_remaining[i] = 0


func get_occupant(school: int) -> RosterUnitData:
	_ensure_slots()
	if school < 0 or school >= WeaponSchool.COUNT:
		return null
	return occupants[school] as RosterUnitData


func get_days_remaining(school: int) -> int:
	_ensure_slots()
	if school < 0 or school >= WeaponSchool.COUNT:
		return 0
	return int(days_remaining[school])


func is_school_filled(school: int) -> bool:
	return get_occupant(school) != null


func find_school_for_unit(unit: RosterUnitData) -> int:
	if unit == null:
		return -1
	_ensure_slots()
	for i in WeaponSchool.COUNT:
		if occupants[i] == unit:
			return i
	return -1


func sealed_count() -> int:
	_ensure_slots()
	var n := 0
	for entry in occupants:
		if entry != null:
			n += 1
	return n


func reset() -> void:
	occupants.clear()
	days_remaining.clear()
	_ensure_slots()


## Seal a unit into a school cocoon. Caller must have already removed them from troop
## and spent biomass. Returns false if slot full or args invalid.
func try_place(unit: RosterUnitData, school: int) -> bool:
	_ensure_slots()
	if unit == null or school < 0 or school >= WeaponSchool.COUNT:
		return false
	if occupants[school] != null:
		return false
	if find_school_for_unit(unit) >= 0:
		return false
	occupants[school] = unit
	days_remaining[school] = maxi(WeaponSchool.SEAL_DURATION_DAYS, 1)
	return true


## Remove occupant from school without applying training. Returns the unit (or null).
func take_occupant(school: int) -> RosterUnitData:
	_ensure_slots()
	if school < 0 or school >= WeaponSchool.COUNT:
		return null
	var unit := occupants[school] as RosterUnitData
	occupants[school] = null
	days_remaining[school] = 0
	return unit


## Tick one day: decrement remaining time and emerge ready units.
## Returns [{ "unit": RosterUnitData, "school": int }, ...]
func advance_day() -> Array[Dictionary]:
	_ensure_slots()
	var emerged: Array[Dictionary] = []
	for school in WeaponSchool.COUNT:
		var unit := occupants[school] as RosterUnitData
		if unit == null:
			continue
		var left := int(days_remaining[school]) - 1
		days_remaining[school] = left
		if left > 0:
			continue
		occupants[school] = null
		days_remaining[school] = 0
		unit.apply_pupation_training(school)
		emerged.append({"unit": unit, "school": school})
	return emerged
