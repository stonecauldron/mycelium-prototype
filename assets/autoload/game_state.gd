extends Node

## Session owner for persistent run state.
const WIN_DAYS := 10
const NURSERY_UNLOCK_DAY := 1
const RIBOFORGE_UNLOCK_DAY := 2
const _COMMON_SPORE_PATH := "res://assets/base/nursery/common_spore.tres"

var troop: TroopData = TroopData.new()
var nursery: NurseryData = NurseryData.new()
var riboforge: RiboforgeData = RiboforgeData.new()
var biomass: BiomassData = BiomassData.new()
var current_day: int = 0
## Seeds deterministic enemy compositions for this run (scout matches combat).
var run_seed: int = 0
## Active enemy formation for the upcoming day (filled by scout; consumed by roster build).
var upcoming_enemy_formation: Array[EnemyUnitSpec] = []
## One-shot: open Nursery when returning to base after it unlocks.
var prefer_nursery_tab: bool = false
## One-shot: open Riboforge when returning to base after it unlocks.
var prefer_riboforge_tab: bool = false
## Session preference: combat fast-forward toggle (restored on next fight).
var combat_fast_forward: bool = false


func _ready() -> void:
	_roll_run_seed()


func get_upcoming_day() -> int:
	return current_day + 1


func clear_upcoming_enemy_formation() -> void:
	upcoming_enemy_formation.clear()


func has_won_run() -> bool:
	return current_day >= WIN_DAYS


func is_nursery_unlocked() -> bool:
	return current_day >= NURSERY_UNLOCK_DAY


func is_riboforge_unlocked() -> bool:
	return current_day >= RIBOFORGE_UNLOCK_DAY


func consume_prefer_nursery_tab() -> bool:
	if not prefer_nursery_tab:
		return false
	prefer_nursery_tab = false
	return is_nursery_unlocked()


func consume_prefer_riboforge_tab() -> bool:
	if not prefer_riboforge_tab:
		return false
	prefer_riboforge_tab = false
	return is_riboforge_unlocked()


func ensure_nursery_seeded() -> void:
	nursery.seed_if_empty()


func ensure_riboforge_seeded() -> void:
	riboforge.seed_if_empty()


func try_buy_spore(spore: SporeData, cost: int) -> bool:
	if spore == null or cost < 0:
		return false
	ensure_nursery_seeded()
	if not biomass.try_spend(cost):
		return false
	nursery.spore_stock.append(spore)
	return true


func try_buy_common_spore() -> bool:
	var spore := load(_COMMON_SPORE_PATH) as SporeData
	if spore == null:
		return false
	return try_buy_spore(spore, BiomassData.COMMON_SPORE_COST)


func try_buy_weapon(weapon: WeaponData, cost: int) -> bool:
	if weapon == null or cost < 0:
		return false
	ensure_riboforge_seeded()
	if not biomass.try_spend(cost):
		return false
	# Duplicate so purchased copies are distinct from the shared default melee.
	var stock_weapon := weapon.duplicate() as WeaponData
	if stock_weapon == null:
		biomass.add(cost)
		return false
	riboforge.weapon_stock.append(stock_weapon)
	return true


func try_equip_weapon_from_stock(unit: RosterUnitData, stock_index: int) -> bool:
	if unit == null:
		return false
	ensure_riboforge_seeded()
	if stock_index < 0 or stock_index >= riboforge.weapon_stock.size():
		return false
	var stock_weapon := riboforge.weapon_stock[stock_index] as WeaponData
	if stock_weapon == null:
		return false
	var previous := unit.weapon
	if previous != null and not RiboforgeData.is_default_weapon(previous):
		riboforge.weapon_stock.append(previous)
	unit.weapon = stock_weapon
	riboforge.weapon_stock.remove_at(stock_index)
	return true


func try_unequip_weapon_to_stock(unit: RosterUnitData) -> bool:
	if unit == null:
		return false
	ensure_riboforge_seeded()
	if RiboforgeData.is_default_weapon(unit.weapon):
		return false
	riboforge.weapon_stock.append(unit.weapon)
	unit.weapon = RiboforgeData.get_default_weapon()
	return true


## Move an equipped non-default weapon onto another unit (swap if the target has one).
func try_transfer_equipped_weapon(from_unit: RosterUnitData, to_unit: RosterUnitData) -> bool:
	if from_unit == null or to_unit == null or from_unit == to_unit:
		return false
	ensure_riboforge_seeded()
	if RiboforgeData.is_default_weapon(from_unit.weapon):
		return false
	var moving := from_unit.weapon
	var displaced := to_unit.weapon
	to_unit.weapon = moving
	from_unit.weapon = (
		RiboforgeData.get_default_weapon()
		if RiboforgeData.is_default_weapon(displaced)
		else displaced
	)
	return true


func try_unlock_plot() -> bool:
	ensure_nursery_seeded()
	if not nursery.can_unlock_plot():
		return false
	var cost := nursery.next_unlock_cost()
	if cost < 0 or not biomass.try_spend(cost):
		return false
	if not nursery.unlock_next_plot():
		biomass.add(cost)
		return false
	return true


func reset_run() -> void:
	troop.reset()
	nursery.reset()
	riboforge.reset()
	biomass.reset()
	current_day = 0
	prefer_nursery_tab = false
	prefer_riboforge_tab = false
	clear_upcoming_enemy_formation()
	_roll_run_seed()


func _roll_run_seed() -> void:
	run_seed = randi()
	if run_seed == 0:
		run_seed = 1
