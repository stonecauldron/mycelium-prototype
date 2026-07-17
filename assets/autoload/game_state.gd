extends Node

## Session owner for persistent run state.
const WIN_DAYS := 10
const _COMMON_SPORE_PATH := "res://assets/base/nursery/common_spore.tres"

var troop: TroopData = TroopData.new()
var nursery: NurseryData = NurseryData.new()
var riboforge: RiboforgeData = RiboforgeData.new()
var biomass: BiomassData = BiomassData.new()
var current_day: int = 0
## One-shot: open Nursery when returning to base after it unlocks.
var prefer_nursery_tab: bool = false


func get_upcoming_day() -> int:
	return current_day + 1


func has_won_run() -> bool:
	return current_day >= WIN_DAYS


func is_nursery_unlocked() -> bool:
	return current_day >= 1


func consume_prefer_nursery_tab() -> bool:
	if not prefer_nursery_tab:
		return false
	prefer_nursery_tab = false
	return is_nursery_unlocked()


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
