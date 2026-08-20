class_name TroopData
extends Resource

const SQUAD_SLOT_COUNT := 10
const BENCH_SLOT_COUNT := 4
const STARTING_UNLOCKED_SQUAD_SLOTS := 4

@export var bench: Array = []
@export var squad: Array = []
@export var unlocked_squad_count: int = STARTING_UNLOCKED_SQUAD_SLOTS

var _seeded: bool = false


func _init() -> void:
	unlocked_squad_count = STARTING_UNLOCKED_SQUAD_SLOTS
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
		if slot < unlocked_squad_count:
			squad[slot] = unit
			slot += 1
		else:
			var bench_slot := _first_empty(bench)
			if bench_slot >= 0:
				bench[bench_slot] = unit
	_seeded = true


func is_squad_slot_unlocked(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < unlocked_squad_count


func can_unlock_squad_slot() -> bool:
	return unlocked_squad_count < SQUAD_SLOT_COUNT


func next_squad_unlock_cost() -> int:
	if not can_unlock_squad_slot():
		return -1
	return BiomassData.SQUAD_SLOT_UNLOCK_COST


func unlock_next_squad_slot() -> bool:
	if not can_unlock_squad_slot():
		return false
	unlocked_squad_count += 1
	_ensure_squad_size()
	return true


func unlock_all_squad_slots() -> void:
	unlocked_squad_count = SQUAD_SLOT_COUNT
	_ensure_squad_size()


func first_empty_unlocked_squad() -> int:
	return _first_empty_unlocked_squad()


func has_free_slot() -> bool:
	return _first_empty_unlocked_squad() >= 0 or _first_empty(bench) >= 0


## Places unit in the first empty unlocked squad slot, or the bench if those are full.
## Returns "squad", "bench", or "" if there is no free slot.
func try_add_unit(unit: RosterUnitData) -> String:
	if unit == null:
		return ""
	var squad_slot := _first_empty_unlocked_squad()
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


## Lowest occupied squad index (nearest flag / rearmost).
func get_rearmost_squad_unit() -> RosterUnitData:
	for entry in squad:
		var unit := entry as RosterUnitData
		if unit != null:
			return unit
	return null


## Highest occupied squad index (frontmost).
func get_frontmost_squad_unit() -> RosterUnitData:
	var front: RosterUnitData = null
	for entry in squad:
		var unit := entry as RosterUnitData
		if unit != null:
			front = unit
	return front


func is_rearmost_squad_unit(unit: RosterUnitData) -> bool:
	return unit != null and unit == get_rearmost_squad_unit()


func is_frontmost_squad_unit(unit: RosterUnitData) -> bool:
	return unit != null and unit == get_frontmost_squad_unit()


func living_unit_count() -> int:
	return _iter_living_units().size()


func remove_unit(unit_data: RosterUnitData) -> void:
	if unit_data == null:
		return
	for i in squad.size():
		if squad[i] == unit_data:
			squad[i] = null
	for i in bench.size():
		if bench[i] == unit_data:
			bench[i] = null


func advance_unit_ages() -> void:
	var aged_out: Array[RosterUnitData] = []
	for unit in _iter_living_units():
		unit.days_alive += 1
		if unit.daily_stat_decay > 0 and unit.stats != null:
			var decay := unit.daily_stat_decay
			unit.stats.strength = clampi(unit.stats.strength - decay, 1, 99)
			unit.stats.dex = clampi(unit.stats.dex - decay, 1, 99)
			unit.stats.con = clampi(unit.stats.con - decay, 1, 99)
		unit.call_lifecycle_effect(&"on_day", [unit])
		if unit.has_exceeded_life_expectancy():
			aged_out.append(unit)
	for unit in aged_out:
		unit.call_lifecycle_effect(
			&"on_death",
			[unit, MutationEffect.DeathContext.AGED_OUT, null]
		)
		if unit.is_adult_stage():
			GameState.nursery.add_death_spore(unit)
		if unit.emitted_death_spore or unit.last_death_biomass_yield > 0:
			DaySummaryFeed.add_fallen_unit(unit, MutationEffect.DeathContext.AGED_OUT)
		remove_unit(unit)


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
	unlocked_squad_count = STARTING_UNLOCKED_SQUAD_SLOTS
	_seeded = false
	_ensure_squad_size()
	_ensure_bench_size()


func _first_empty_unlocked_squad() -> int:
	_ensure_squad_size()
	for i in unlocked_squad_count:
		if i < squad.size() and squad[i] == null:
			return i
	return -1


func _first_empty(row: Array) -> int:
	for i in row.size():
		if row[i] == null:
			return i
	return -1


func _ensure_squad_size() -> void:
	unlocked_squad_count = clampi(unlocked_squad_count, 0, SQUAD_SLOT_COUNT)
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
