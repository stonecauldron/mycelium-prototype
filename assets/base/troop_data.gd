class_name TroopData
extends Resource

const SQUAD_SLOT_COUNT := 10
const BENCH_SLOT_COUNT := 5

@export var bench: Array = []
@export var squad: Array = []

var _seeded: bool = false


func _init() -> void:
	_ensure_squad_size()
	_ensure_bench_size()


func is_seeded() -> bool:
	return _seeded


func seed_if_empty(starter_units: Array[RosterUnitData]) -> void:
	if _seeded:
		return
	bench.clear()
	_ensure_squad_size()
	_ensure_bench_size()
	var slot := 0
	for unit in starter_units:
		if unit == null:
			continue
		if slot < squad.size():
			squad[slot] = unit
			slot += 1
		else:
			var bench_slot := _first_empty(bench)
			if bench_slot >= 0:
				bench[bench_slot] = unit
	_seeded = true


func has_free_slot() -> bool:
	return _first_empty(squad) >= 0 or _first_empty(bench) >= 0


## Places unit in the first empty squad slot, or the bench if squad is full.
## Returns "squad", "bench", or "" if there is no free slot.
func try_add_unit(unit: RosterUnitData) -> String:
	if unit == null:
		return ""
	var squad_slot := _first_empty(squad)
	if squad_slot >= 0:
		squad[squad_slot] = unit
		return "squad"
	var bench_slot := _first_empty(bench)
	if bench_slot >= 0:
		bench[bench_slot] = unit
		return "bench"
	return ""


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
	for i in bench.size():
		if bench[i] == unit_data:
			bench[i] = null
	pack_squad()


func pack_squad() -> void:
	var occupied: Array = []
	for entry in squad:
		var unit := entry as RosterUnitData
		if unit != null:
			occupied.append(unit)
	squad.clear()
	for unit in occupied:
		squad.append(unit)
	_ensure_squad_size()


func advance_unit_ages() -> Array[RosterUnitData]:
	var matured: Array[RosterUnitData] = []
	for unit in _iter_living_units():
		unit.days_alive += 1
		if unit.can_promote_to_imago() and unit.promote_to_imago():
			matured.append(unit)
	return matured


func _iter_living_units() -> Array[RosterUnitData]:
	var units: Array[RosterUnitData] = []
	for entry in squad:
		var unit := entry as RosterUnitData
		if unit != null:
			units.append(unit)
	for entry in bench:
		var unit := entry as RosterUnitData
		if unit != null:
			units.append(unit)
	return units


func reset() -> void:
	bench.clear()
	squad.clear()
	_seeded = false
	_ensure_squad_size()
	_ensure_bench_size()


func _first_empty(row: Array) -> int:
	for i in row.size():
		if row[i] == null:
			return i
	return -1


func _ensure_squad_size() -> void:
	_ensure_size(squad, SQUAD_SLOT_COUNT)


func _ensure_bench_size() -> void:
	_ensure_size(bench, BENCH_SLOT_COUNT)


func _ensure_size(row: Array, slot_count: int) -> void:
	if row.is_empty():
		row.resize(slot_count)
		row.fill(null)
		return
	while row.size() < slot_count:
		row.append(null)
	if row.size() > slot_count:
		row.resize(slot_count)
