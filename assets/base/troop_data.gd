class_name TroopData
extends Resource

const SQUAD_SLOT_COUNT := 12

@export var bench: Array[RosterUnitData] = []
@export var squad: Array = []

var _seeded: bool = false


func _init() -> void:
	_ensure_squad_size()


func is_seeded() -> bool:
	return _seeded


func seed_if_empty(starter_units: Array[RosterUnitData]) -> void:
	if _seeded:
		return
	bench.clear()
	_ensure_squad_size()
	var slot := 0
	for unit in starter_units:
		if unit == null:
			continue
		if slot < squad.size():
			squad[slot] = unit
			slot += 1
		else:
			bench.append(unit)
	_seeded = true
	sort_rosters()


func get_squad_roster() -> Array[RosterUnitData]:
	var roster: Array[RosterUnitData] = []
	for entry in squad:
		var unit := entry as RosterUnitData
		if unit != null:
			roster.append(unit)
	return roster


func squad_unit_count() -> int:
	return get_squad_roster().size()


func remove_unit(unit_data: RosterUnitData) -> void:
	if unit_data == null:
		return
	for i in squad.size():
		if squad[i] == unit_data:
			squad[i] = null
	bench.erase(unit_data)
	sort_squad()


func reset() -> void:
	bench.clear()
	squad.clear()
	_seeded = false
	_ensure_squad_size()


func sort_rosters() -> void:
	sort_squad()
	sort_bench()


func sort_squad() -> void:
	var occupied: Array = []
	for entry in squad:
		var unit := entry as RosterUnitData
		if unit != null:
			occupied.append(unit)
	occupied.sort_custom(compare_units)
	squad.clear()
	for unit in occupied:
		squad.append(unit)
	_ensure_squad_size()


func sort_bench() -> void:
	var ordered: Array[RosterUnitData] = []
	for unit in bench:
		if unit != null:
			ordered.append(unit)
	ordered.sort_custom(compare_units)
	bench.clear()
	bench.append_array(ordered)


func compare_units(a: RosterUnitData, b: RosterUnitData) -> bool:
	var range_a := int(a.get_range_class())
	var range_b := int(b.get_range_class())
	if range_a != range_b:
		return range_a > range_b

	var spd_a := a.stats.spd if a.stats != null else 0
	var spd_b := b.stats.spd if b.stats != null else 0
	if spd_a != spd_b:
		return spd_a > spd_b

	return a.display_name.naturalnocasecmp_to(b.display_name) < 0


func _ensure_squad_size() -> void:
	if squad.is_empty():
		squad.resize(SQUAD_SLOT_COUNT)
		squad.fill(null)
		return
	while squad.size() < SQUAD_SLOT_COUNT:
		squad.append(null)
	if squad.size() > SQUAD_SLOT_COUNT:
		squad.resize(SQUAD_SLOT_COUNT)
