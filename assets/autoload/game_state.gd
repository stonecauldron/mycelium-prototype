extends Node

## Session owner for persistent run state.
signal debug_cheats_applied

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
## Session preference: combat fast-forward scale (1, 2, or 4; restored on next fight).
var combat_fast_forward: int = 1
## Session: show floating arrow pointing at Start Combat until first launch.
var show_start_combat_hint: bool = true
## Session: hovering arrow on READY plots until the player harvests once.
var show_plot_harvest_hint: bool = true
## Debug (~): cheats active — force base screens unlocked and show debug HUD.
var debug_mode_active: bool = false


func _ready() -> void:
	_roll_run_seed()


## Debug (~): +100 biomass and unlock all base screens.
func activate_debug_cheats() -> void:
	biomass.add(100)
	debug_mode_active = true
	debug_cheats_applied.emit()


## Debug: skip combat and apply one day of progression.
func debug_advance_day() -> void:
	ensure_nursery_seeded()
	current_day += 1
	clear_upcoming_enemy_formation()
	troop.advance_unit_ages()
	nursery.advance_day()
	refresh_shops_for_new_day()


func get_upcoming_day() -> int:
	return current_day + 1


func clear_upcoming_enemy_formation() -> void:
	upcoming_enemy_formation.clear()


func ensure_upcoming_enemy_formation() -> void:
	if not upcoming_enemy_formation.is_empty():
		return
	var day := clampi(get_upcoming_day(), 1, WIN_DAYS)
	upcoming_enemy_formation = EnemyComposer.specs_for_day(day)


func has_won_run() -> bool:
	return current_day >= WIN_DAYS


func is_nursery_unlocked() -> bool:
	return debug_mode_active or current_day >= NURSERY_UNLOCK_DAY


func is_riboforge_unlocked() -> bool:
	return debug_mode_active or current_day >= RIBOFORGE_UNLOCK_DAY


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


## Free daily refresh: reroll unlocked shop slots (locks persist).
func refresh_shops_for_new_day() -> void:
	ensure_nursery_seeded()
	ensure_riboforge_seeded()
	nursery.reroll_unlocked_shop_offers()
	nursery.apply_day_start_shop_rules()
	riboforge.reroll_unlocked_shop_offers()


func try_buy_spore(spore: SporeData, cost: int) -> bool:
	if spore == null or cost < 0:
		return false
	ensure_nursery_seeded()
	if not nursery.can_add_stock_item():
		return false
	if not biomass.try_spend(cost):
		return false
	if not nursery.add_spore(spore):
		biomass.add(cost)
		return false
	return true


func try_buy_fertilizer(fertilizer: FertilizerData, cost: int) -> bool:
	if fertilizer == null or cost < 0:
		return false
	ensure_nursery_seeded()
	if not nursery.can_add_stock_item():
		return false
	if not biomass.try_spend(cost):
		return false
	if not nursery.add_fertilizer(fertilizer):
		biomass.add(cost)
		return false
	return true


func try_buy_common_spore() -> bool:
	var spore := load(_COMMON_SPORE_PATH) as SporeData
	if spore == null:
		return false
	return try_buy_spore(spore, BiomassData.COMMON_SPORE_COST)


## Buys into weapon stock. Returns the stock slot index, or -1 on failure.
func try_buy_weapon(weapon: WeaponData, cost: int) -> int:
	if weapon == null or cost < 0:
		return -1
	ensure_riboforge_seeded()
	if not riboforge.can_add_weapon():
		return -1
	if not biomass.try_spend(cost):
		return -1
	# Duplicate so purchased copies are distinct from the shared default melee.
	var stock_weapon := weapon.duplicate() as WeaponData
	var stock_index := riboforge.add_weapon(stock_weapon) if stock_weapon != null else -1
	if stock_index < 0:
		biomass.add(cost)
		return -1
	return stock_index


func try_equip_weapon_from_stock(unit: RosterUnitData, stock_index: int) -> bool:
	if unit == null:
		return false
	ensure_riboforge_seeded()
	var stock_weapon := riboforge.weapon_stock.get_at(stock_index) as WeaponData
	if stock_weapon == null:
		return false
	# Clear first so a displaced non-default weapon can re-enter without needing
	# an extra stock slot beyond the cap.
	riboforge.weapon_stock.clear_slot(stock_index)
	var previous := unit.weapon
	unit.weapon = stock_weapon
	if previous != null and not RiboforgeData.is_default_weapon(previous):
		if riboforge.add_weapon(previous) < 0:
			# Should be unreachable after clearing the source slot; restore stock.
			riboforge.weapon_stock.set_at(stock_index, stock_weapon)
			unit.weapon = previous
			return false
	return true


func try_unequip_weapon_to_stock(unit: RosterUnitData) -> bool:
	if unit == null:
		return false
	ensure_riboforge_seeded()
	if RiboforgeData.is_default_weapon(unit.weapon):
		return false
	if not riboforge.can_add_weapon():
		return false
	if riboforge.add_weapon(unit.weapon) < 0:
		return false
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


func try_sell_spore_from_stock(stock_index: int) -> bool:
	return try_sell_nursery_stock_item(stock_index)


func try_sell_fertilizer_from_stock(stock_index: int) -> bool:
	return try_sell_nursery_stock_item(stock_index)


func try_sell_nursery_stock_item(stock_index: int) -> bool:
	ensure_nursery_seeded()
	var item := nursery.stock.get_at(stock_index)
	var buy_cost := 0
	if item is SporeData:
		buy_cost = (item as SporeData).biomass_cost
	elif item is FertilizerData:
		buy_cost = (item as FertilizerData).biomass_cost
	else:
		return false
	nursery.stock.clear_slot(stock_index)
	biomass.add(BiomassData.sell_value(buy_cost))
	return true


func try_sell_weapon_from_stock(stock_index: int) -> bool:
	ensure_riboforge_seeded()
	var weapon := riboforge.weapon_stock.get_at(stock_index) as WeaponData
	if weapon == null or RiboforgeData.is_default_weapon(weapon):
		return false
	riboforge.weapon_stock.clear_slot(stock_index)
	biomass.add(BiomassData.sell_value(weapon.biomass_cost))
	return true


func try_sell_equipped_weapon(unit: RosterUnitData) -> bool:
	if unit == null:
		return false
	ensure_riboforge_seeded()
	var weapon := unit.weapon
	if weapon == null or RiboforgeData.is_default_weapon(weapon):
		return false
	unit.weapon = RiboforgeData.get_default_weapon()
	biomass.add(BiomassData.sell_value(weapon.biomass_cost))
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
	show_plot_harvest_hint = true
	debug_mode_active = false
	clear_upcoming_enemy_formation()
	_roll_run_seed()


func _roll_run_seed() -> void:
	run_seed = randi()
	if run_seed == 0:
		run_seed = 1
