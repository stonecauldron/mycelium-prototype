extends Node

## Session owner for persistent run state.
const WIN_DAYS := 10
const _COMMON_SPORE_PATH := "res://assets/base/nursery/common_spore.tres"

var troop: TroopData = TroopData.new()
var nursery: NurseryData = NurseryData.new()
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
	biomass.reset()
	current_day = 0
	prefer_nursery_tab = false
