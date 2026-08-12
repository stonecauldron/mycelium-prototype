extends Node

## Session owner for persistent run state.
signal debug_cheats_applied

const WIN_DAYS := 10
const NURSERY_UNLOCK_DAY := 1
const RIBOFORGE_UNLOCK_DAY := 2

var troop: TroopData = TroopData.new()
var nursery: NurseryData = NurseryData.new()
var riboforge: RiboforgeData = RiboforgeData.new()
var pupation: PupationData = PupationData.new()
var biomass: BiomassData = BiomassData.new()
var seals: SealsCollection = SealsCollection.new()
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
## Session: hovering arrow on empty plots until the player plants once.
var show_plot_plant_hint: bool = true
## Debug (~): cheats active — force base screens unlocked and show debug HUD.
var debug_mode_active: bool = false
## Mandatory seal pick waiting when returning to base (after days 2 / 5 / 8).
var pending_seal_choice: bool = false
## Favourite Child: first harvest of the current day already claimed.
var favourite_child_used_today: bool = false


func _ready() -> void:
	_roll_run_seed()
	begin_day()
	pending_seal_choice = true


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
	emerge_pupations()
	nursery.advance_day()
	refresh_shops_for_new_day()
	begin_day()
	maybe_queue_seal_choice()


## Day-start effects (Golden Mould, Favourite Child day flag). Call after day advances and on run start.
func begin_day() -> void:
	favourite_child_used_today = false
	var mould := SealModifiers.golden_mould_biomass()
	if mould > 0:
		biomass.add(mould)


func maybe_queue_seal_choice() -> void:
	# After completing days 2 / 5 / 8 (one fight earlier than 3 / 6 / 9).
	if current_day == 2 or current_day == 5 or current_day == 8:
		pending_seal_choice = true


## Available fighters = living troop units (cocooned units are already out of troop).
func available_fighter_count() -> int:
	return troop.living_unit_count()


## Preview compost payout without mutating state. Keys: biomass (int), emits_spore (bool).
func preview_compost_outcome(unit: RosterUnitData) -> Dictionary:
	if unit == null:
		return {"biomass": 0, "emits_spore": false}
	var stage_reward := BiomassData.reward_for_compost(unit.is_adult_stage())
	var bank := maxi(unit.biomass_bank, 0)
	return {
		"biomass": stage_reward + bank,
		"emits_spore": unit.is_adult_stage(),
	}


func can_compost_unit(unit: RosterUnitData) -> bool:
	if unit == null:
		return false
	if not _troop_contains(unit):
		return false
	if pupation.find_school_for_unit(unit) >= 0:
		return false
	# Must leave at least one fighter after composting this unit.
	if available_fighter_count() <= 1:
		return false
	return true


## Instantly compost a unit: death hooks, stage biomass, adult spore, remove from troop.
func try_compost_unit(unit: RosterUnitData) -> bool:
	if not can_compost_unit(unit):
		return false
	unit.last_death_biomass_yield = 0
	unit.call_lifecycle_effect(
		&"on_death",
		[unit, MutationEffect.DeathContext.COMPOSTED, null]
	)
	var compost_reward := BiomassData.reward_for_compost(unit.is_adult_stage())
	if compost_reward > 0:
		unit.last_death_biomass_yield += compost_reward
		biomass.add(compost_reward)
	# Mould ticks while the composted unit is still in troop (excluded from credit).
	_notify_ally_composted(unit)
	if unit.is_adult_stage():
		nursery.add_death_spore(unit)
	troop.remove_unit(unit)
	return true


func _notify_ally_composted(composted: RosterUnitData) -> void:
	if composted == null or troop == null:
		return
	for entry in troop.squad:
		var other := entry as RosterUnitData
		if other == null or other == composted:
			continue
		other.call_lifecycle_effect(&"on_ally_composted", [other, composted])
	for entry in troop.bench:
		var other := entry as RosterUnitData
		if other == null or other == composted:
			continue
		other.call_lifecycle_effect(&"on_ally_composted", [other, composted])


func _troop_contains(unit: RosterUnitData) -> bool:
	if unit == null:
		return false
	for entry in troop.squad:
		if entry == unit:
			return true
	for entry in troop.bench:
		if entry == unit:
			return true
	return false


## Eligibility to open the pupation confirm (funds checked separately on confirm).
func can_cocoon_for_pupation(unit: RosterUnitData, school: int) -> bool:
	if unit == null or school < 0 or school >= WeaponSchool.COUNT:
		return false
	if not unit.can_pupate():
		return false
	if pupation.is_school_filled(school):
		return false
	if pupation.find_school_for_unit(unit) >= 0:
		return false
	# Must leave at least one fighter after removing this unit from troop.
	if available_fighter_count() <= 1:
		return false
	return true


## Cocoon a unit for school training (spend biomass, remove from troop).
func try_cocoon_for_pupation(unit: RosterUnitData, school: int) -> bool:
	if not can_cocoon_for_pupation(unit, school):
		return false
	if not biomass.can_afford(WeaponSchool.COCOON_COST):
		return false
	if not biomass.try_spend(WeaponSchool.COCOON_COST):
		return false
	troop.remove_unit(unit)
	if not pupation.try_place(unit, school):
		biomass.add(WeaponSchool.COCOON_COST)
		troop.try_add_unit(unit)
		return false
	# Fast metabolism (etc.): duration <= 0 emerges immediately.
	if pupation.get_days_remaining(school) <= 0:
		var placed := pupation.take_occupant(school)
		if placed != null:
			placed.apply_pupation_training(school)
			troop.try_add_unit(placed)
	return true


## Cancel cocoon before day advance: refund biomass, return to squad-then-bench.
func try_cancel_pupation(school: int) -> bool:
	var unit := pupation.take_occupant(school)
	if unit == null:
		return false
	biomass.add(WeaponSchool.COCOON_COST)
	if troop.try_add_unit(unit).is_empty():
		# Should not happen with normal roster sizes; keep unit in a bench overflow sense.
		push_warning("Pupation cancel: no troop slot for %s" % unit.display_name)
	return true


## Tick cocoons and return units that finished pupation. Call after advance_unit_ages.
func emerge_pupations() -> Array[Dictionary]:
	var emerged := pupation.advance_day()
	for entry in emerged:
		var unit := entry.get("unit") as RosterUnitData
		if unit == null:
			continue
		troop.try_add_unit(unit)
	return emerged


func try_add_seal(seal: SealData) -> bool:
	if seal == null:
		return false
	if not seals.add(seal):
		return false
	# Opening seal is chosen after day-0 begin_day(); grant missed day-start biomass once.
	if current_day == 0 and seal.biomass_per_day > 0:
		var mould := SealModifiers.golden_mould_biomass()
		if mould > 0:
			biomass.add(mould)
	ensure_nursery_seeded()
	return true


func clear_pending_seal_choice() -> void:
	pending_seal_choice = false


func get_upcoming_day() -> int:
	return current_day + 1


## Every 5th battle (days 5 and 10 in a 10-day run) is an elite fight.
func is_elite_day(day: int) -> bool:
	return day > 0 and day % 5 == 0


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
	nursery.reset_shop_reroll_cost()
	riboforge.reset_shop_reroll_cost()
	nursery.reroll_unlocked_shop_offers()
	riboforge.reroll_unlocked_shop_offers()


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


func try_buy_mutation(mutation: MutationData, cost: int) -> bool:
	if mutation == null or cost < 0:
		return false
	ensure_nursery_seeded()
	if not nursery.can_add_stock_item():
		return false
	if not biomass.try_spend(cost):
		return false
	if not nursery.add_mutation(mutation):
		biomass.add(cost)
		return false
	return true


## Pay biomass on an empty plot to start a fresh Common grow (Rotten Thumb applies).
func try_plant_fresh_common(plot_index: int) -> bool:
	ensure_nursery_seeded()
	if not nursery.can_plant_on_plot(plot_index):
		return false
	var spore := nursery.make_fresh_common_spore()
	if spore == null:
		return false
	var cost := SealModifiers.fresh_plant_cost()
	if not biomass.try_spend(cost):
		return false
	if not nursery.plant_spore(plot_index, spore):
		biomass.add(cost)
		return false
	return true


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
	elif item is MutationData:
		buy_cost = (item as MutationData).biomass_cost
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
	pupation.reset()
	biomass.reset()
	seals.reset()
	current_day = 0
	prefer_nursery_tab = false
	prefer_riboforge_tab = false
	show_plot_harvest_hint = true
	show_plot_plant_hint = true
	debug_mode_active = false
	favourite_child_used_today = false
	clear_upcoming_enemy_formation()
	_roll_run_seed()
	begin_day()
	pending_seal_choice = true


func _roll_run_seed() -> void:
	run_seed = randi()
	if run_seed == 0:
		run_seed = 1
