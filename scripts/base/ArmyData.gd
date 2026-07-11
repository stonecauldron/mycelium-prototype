extends Node

const SQUAD_SLOT_COUNT := 12

var bench: Array[RosterUnitData] = []
var squad: Array = []

var _seeded: bool = false


func _ready() -> void:
	_ensure_squad_size()


func is_seeded() -> bool:
	return _seeded


func seed_if_empty(bench_units: Array[RosterUnitData]) -> void:
	if _seeded:
		return
	bench.clear()
	for unit in bench_units:
		if unit != null:
			bench.append(unit)
	_ensure_squad_size()
	_seeded = true


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


func reset() -> void:
	bench.clear()
	squad.clear()
	_seeded = false
	_ensure_squad_size()


func _ensure_squad_size() -> void:
	if squad.is_empty():
		squad.resize(SQUAD_SLOT_COUNT)
		squad.fill(null)
		return
	while squad.size() < SQUAD_SLOT_COUNT:
		squad.append(null)
	if squad.size() > SQUAD_SLOT_COUNT:
		squad.resize(SQUAD_SLOT_COUNT)
