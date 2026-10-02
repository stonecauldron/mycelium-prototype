extends Node

## Session owner for persistent run state.
signal debug_mode_changed(is_active: bool)
signal seals_changed()

const WIN_DAYS := 10
const NURSERY_UNLOCK_DAY := 1
const BASE_SCENE_PATH := "res://assets/base/base.tscn"

var troop: TroopData = TroopData.new()
var nursery: NurseryData = NurseryData.new()
var pupation: PupationData = PupationData.new()
## Committed cocoon results waiting for their one-time Base presentation.
var pending_cocoon_emergences: Array[Dictionary] = []
var biomass: BiomassData = BiomassData.new()
var seals: SealsCollection = SealsCollection.new()
var barks: BarkData = BarkData.new()
var base_undo: BaseUndoHistory = BaseUndoHistory.new()
var current_day: int = 0
var is_guided_run: bool = false
var _guided_child_revealed: bool = false
var _guided_preparation_day: int = -1
var _guided_enemy_day: int = -1
var _guided_enemy_roster: Array[RosterUnitData] = []
var _guided_preparation_checkpoint: GuidedRunSnapshot = null
var _guided_battle_checkpoint: GuidedRunSnapshot = null
var _seal_choice_queued_day: int = -1
var _run_finished: bool = false
## Seeds deterministic enemy compositions for this run (scout matches combat).
var run_seed: int = 0
## Active enemy formation for the upcoming day (filled by scout; consumed by roster build).
var upcoming_enemy_formation: Array[EnemyUnitSpec] = []
## Paid Scout rerolls already bought this Day (resets on new Day).
var scout_rerolls_today: int = 0
var prefer_nursery_tab: bool = false
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
## Retain this pick's offers and paid reroll count when its choice is undone.
var seal_choice_offers: Array[SealData] = []
var seal_rerolls_this_pick: int = 0
## Favourite Child: first harvest of the current day already claimed.
var favourite_child_used_today: bool = false
## True after reset_run(); false on a cold boot until New Run (or editor play-from-base).
var run_started: bool = false


## Debug (~): +100 biomass and unlock all base screens.
func activate_debug_cheats() -> void:
	base_undo.clear()
	biomass.add(100)
	troop.unlock_all_squad_slots()
	debug_mode_active = true
	debug_mode_changed.emit(true)


func toggle_debug_mode() -> void:
	if debug_mode_active:
		debug_mode_active = false
		debug_mode_changed.emit(false)
	else:
		activate_debug_cheats()


## Debug: skip combat and apply one day of progression.
func debug_advance_day() -> void:
	base_undo.clear()
	ensure_nursery_seeded()
	current_day += 1
	clear_upcoming_enemy_formation()
	troop.advance_unit_ages()
	emerge_pupations()
	nursery.advance_day()
	refresh_shops_for_new_day()
	begin_day()
	maybe_queue_seal_choice()
	ensure_guided_preparation()


## Day-start effects (Golden Mould, Favourite Child day flag). Call after day advances and on run start.
func begin_day() -> void:
	favourite_child_used_today = false
	var mould := SealModifiers.golden_mould_biomass()
	if mould > 0:
		biomass.add(mould)
		Analytics.biomass_source("Seal", "golden_mould", mould)


func maybe_queue_seal_choice() -> void:
	if (current_day > 0 and is_seal_choice_day(get_upcoming_day())
			and _seal_choice_queued_day != get_upcoming_day()):
		_seal_choice_queued_day = get_upcoming_day()
		seal_choice_offers.clear()
		seal_rerolls_this_pick = 0
		pending_seal_choice = true


## Receiving Days, shared by the ordinary Run reward schedule and progression UI.
func is_seal_choice_day(day: int) -> bool:
	if is_guided_run:
		return day <= get_run_length() and (day == 11 or (day >= 12 and day % 3 == 0))
	return day >= 1 and day <= WIN_DAYS and (day == 1 or day % 3 == 0)


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
	if not is_feature_available(&"compost"):
		return false
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
	var is_adult := unit.is_adult_stage()
	var compost_reward := BiomassData.reward_for_compost(is_adult)
	if compost_reward > 0:
		unit.last_death_biomass_yield += compost_reward
		biomass.add(compost_reward)
		Analytics.biomass_source("Compost", "Adult" if is_adult else "Child", compost_reward)
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
	if unit == null or not is_school_available(school):
		return false
	if not unit.check_training_eligibility(school).allowed:
		return false
	if pupation.is_school_filled(school):
		return false
	if pupation.find_school_for_unit(unit) >= 0:
		return false
	# Training with a wait must leave at least one fighter in the troop.
	if unit.effective_cocoon_days() > 0 and available_fighter_count() <= 1:
		return false
	return true


## Spend biomass on training; only remove the unit from troop when there is a wait.
func try_cocoon_for_pupation(unit: RosterUnitData, school: int) -> bool:
	if not can_cocoon_for_pupation(unit, school):
		return false
	if not biomass.can_afford(WeaponSchool.COCOON_COST):
		return false
	if not biomass.try_spend(WeaponSchool.COCOON_COST):
		return false
	if unit.effective_cocoon_days() <= 0:
		unit.apply_pupation_training(school)
	else:
		troop.remove_unit(unit)
		if not pupation.try_place(unit, school):
			biomass.add(WeaponSchool.COCOON_COST)
			troop.try_add_unit(unit)
			return false
	Analytics.biomass_sink(
		"Training",
		Analytics.slug(WeaponSchool.display_name(school)),
		WeaponSchool.COCOON_COST
	)
	return true


## Cancel cocoon before day advance: refund biomass, return to squad-then-bench.
func try_cancel_pupation(school: int) -> bool:
	var unit := pupation.take_occupant(school)
	if unit == null:
		return false
	biomass.add(WeaponSchool.COCOON_COST)
	Analytics.biomass_source(
		"Training",
		Analytics.slug(WeaponSchool.display_name(school)),
		WeaponSchool.COCOON_COST
	)
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
		queue_cocoon_emergence(unit, int(entry.get("school", 0)))
	return emerged


func queue_cocoon_emergence(unit: RosterUnitData, school: int) -> void:
	if unit == null:
		return
	pending_cocoon_emergences.append({
		"unit": unit,
		"school": school,
		"stage": unit.life_stage_id,
		"trainings": unit.weapon_trainings.duplicate(),
	})


func is_cocoon_emergence_current(entry: Dictionary) -> bool:
	var unit := entry.get("unit") as RosterUnitData
	return (
		unit != null and _troop_contains(unit) and unit.is_adult_stage()
		and unit.life_stage_id == entry.get("stage", &"")
		and unit.weapon_trainings == entry.get("trainings", [])
	)


func try_add_seal(seal: SealData) -> bool:
	if is_guided_run and (not pending_seal_choice or not GuidedRun.SEALS.has(seal)):
		return false
	if seal == null:
		return false
	if not seals.add(seal):
		return false
	if seal.greenhouse_day_reduction > 0:
		ensure_nursery_seeded()
		nursery.apply_greenhouse_remaining_cut(seal.greenhouse_day_reduction)
	# Opening seal is chosen after day-0 begin_day(); grant missed day-start biomass once.
	if current_day == 0 and seal.biomass_per_day > 0:
		var mould := SealModifiers.golden_mould_biomass()
		if mould > 0:
			biomass.add(mould)
			Analytics.biomass_source("Seal", "golden_mould", mould)
	ensure_nursery_seeded()
	seals_changed.emit()
	return true


func clear_pending_seal_choice() -> void:
	pending_seal_choice = false


func get_upcoming_day() -> int:
	return current_day + 1


func current_scout_reroll_cost() -> int:
	return BiomassData.reroll_price(scout_rerolls_today + 1)


func advance_scout_reroll_cost() -> void:
	scout_rerolls_today += 1


func reset_scout_reroll_cost() -> void:
	scout_rerolls_today = 0


## Every 5th battle (days 5 and 10 in a 10-day run) is an elite fight.
func is_elite_day(day: int) -> bool:
	return day > 0 and day % 5 == 0


func clear_upcoming_enemy_formation() -> void:
	upcoming_enemy_formation.clear()
	_guided_enemy_roster.clear()
	_guided_enemy_day = -1


func ensure_upcoming_enemy_formation() -> void:
	if not upcoming_enemy_formation.is_empty():
		return
	var day := clampi(get_upcoming_day(), 1, get_run_length())
	upcoming_enemy_formation = EnemyComposer.specs_for_day(day)


func has_won_run() -> bool:
	return current_day >= get_run_length()


func is_nursery_unlocked() -> bool:
	if is_guided_run:
		return is_feature_available(&"nursery")
	return debug_mode_active or current_day >= NURSERY_UNLOCK_DAY


func consume_prefer_nursery_tab() -> bool:
	if not prefer_nursery_tab:
		return false
	prefer_nursery_tab = false
	return is_nursery_unlocked()


func ensure_nursery_seeded() -> void:
	nursery.seed_if_empty()


## Free daily refresh: reroll unlocked shop slots (locks persist). Reset Nursery and Scout reroll counts.
func refresh_shops_for_new_day() -> void:
	ensure_nursery_seeded()
	nursery.reset_shop_reroll_cost()
	reset_scout_reroll_cost()
	nursery.reroll_unlocked_shop_offers()


func try_buy_fertilizer(fertilizer: FertilizerData, cost: int) -> bool:
	if not is_feature_available(&"shop"):
		return false
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
	Analytics.biomass_sink("Shop", Analytics.resource_slug(fertilizer), cost)
	return true


func try_buy_mutation(mutation: MutationData, cost: int) -> bool:
	if not is_feature_available(&"mutations"):
		return false
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
	Analytics.biomass_sink("Shop", Analytics.resource_slug(mutation), cost)
	return true


## Pay biomass on an empty plot to start a fresh Common grow (Rotten Thumb applies).
func try_plant_fresh_common(plot_index: int) -> bool:
	if not is_nursery_unlocked():
		return false
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
	Analytics.biomass_sink("Nursery", "Plant", cost)
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
	var sold := BiomassData.sell_value(buy_cost)
	var item_id := "Plant"
	if item is FertilizerData or item is MutationData:
		var catalog := Analytics.resource_slug(item as Resource)
		if not catalog.is_empty():
			item_id = catalog
	nursery.stock.clear_slot(stock_index)
	biomass.add(sold)
	Analytics.biomass_source("Stock", item_id, sold)
	return true


func try_unlock_plot() -> bool:
	if not is_feature_available(&"plot_slots"):
		return false
	ensure_nursery_seeded()
	if not nursery.can_unlock_plot():
		return false
	var cost := nursery.next_unlock_cost()
	if cost < 0 or not biomass.try_spend(cost):
		return false
	if not nursery.unlock_next_plot():
		biomass.add(cost)
		return false
	Analytics.biomass_sink("Nursery", "Unlock", cost)
	return true


func try_unlock_squad_slot() -> bool:
	if not is_feature_available(&"squad_slots"):
		return false
	if not troop.can_unlock_squad_slot():
		return false
	var cost := troop.next_squad_unlock_cost()
	if cost < 0 or not biomass.try_spend(cost):
		return false
	if not troop.unlock_next_squad_slot():
		biomass.add(cost)
		return false
	Analytics.biomass_sink("Troop", "Unlock", cost)
	return true


func start_new_run() -> void:
	if run_started:
		finish_run()
	reset_run()
	Audio.play_base_music(true)
	SceneTransition.change_scene(BASE_SCENE_PATH)


func reset_run(guided: Variant = null) -> void:
	is_guided_run = SettingsServer.guided_run_enabled if guided == null else bool(guided)
	_run_finished = false
	_guided_child_revealed = false
	_guided_preparation_day = -1
	_guided_preparation_checkpoint = null
	_guided_battle_checkpoint = null
	_seal_choice_queued_day = -1
	BattleLaunch.enemy_roster.clear()
	DaySummaryFeed.clear()
	base_undo.end_visit()
	pending_cocoon_emergences.clear()
	seal_choice_offers.clear()
	seal_rerolls_this_pick = 0
	troop.reset()
	nursery.reset()
	pupation.reset()
	biomass.reset()
	seals.reset()
	barks.reset()
	current_day = 0
	prefer_nursery_tab = false
	show_start_combat_hint = true
	show_plot_harvest_hint = true
	show_plot_plant_hint = true
	debug_mode_active = false
	favourite_child_used_today = false
	reset_scout_reroll_cost()
	clear_upcoming_enemy_formation()
	_roll_run_seed()
	begin_day()
	pending_seal_choice = not is_guided_run
	if pending_seal_choice:
		_seal_choice_queued_day = 1
	if is_guided_run:
		var starters: Array[RosterUnitData] = [GuidedRun.make_starter(true)]
		troop.seed_if_empty(starters)
		show_start_combat_hint = false
		show_plot_harvest_hint = false
		show_plot_plant_hint = false
		ensure_guided_preparation()
	run_started = true
	Analytics.on_run_started()


func _roll_run_seed() -> void:
	run_seed = randi()
	if run_seed == 0:
		run_seed = 1


func get_run_length() -> int:
	return GuidedRun.LENGTH if is_guided_run else WIN_DAYS


func is_feature_available(feature: StringName) -> bool:
	return not is_guided_run or debug_mode_active or GuidedRun.feature_available(feature, get_upcoming_day())


func is_school_available(school: int) -> bool:
	if school < 0 or school >= WeaponSchool.COUNT:
		return false
	return not is_guided_run or debug_mode_active or GuidedRun.school_available(school, get_upcoming_day())


func is_guided_shop_slot_available(slot_index: int) -> bool:
	if not is_guided_run or debug_mode_active:
		return true
	return (slot_index == 0 and is_feature_available(&"shop")) or (
		slot_index == 2 and is_feature_available(&"mutations")
	)


func ensure_seal_choice_offers() -> Array[SealData]:
	if pending_seal_choice and seal_choice_offers.is_empty():
		if is_guided_run:
			seal_choice_offers.assign(GuidedRun.SEALS)
		else:
			seal_choice_offers = SealCatalog.roll_offers(3, seals)
	return seal_choice_offers


func can_reroll_seals() -> bool:
	return not is_guided_run and current_day > 0


func ensure_guided_preparation() -> void:
	if not is_guided_run:
		return
	var day := get_upcoming_day()
	if day >= 2 and not _guided_child_revealed:
		troop.try_add_unit(GuidedRun.make_starter(false))
		_guided_child_revealed = true
	if _guided_preparation_day != day:
		_guided_preparation_day = day
		ensure_nursery_seeded()
		nursery.refresh_guided_shop_offers()
	ensure_seal_choice_offers()
	ensure_upcoming_enemy_formation()


func make_upcoming_enemy_roster() -> Array[RosterUnitData]:
	ensure_upcoming_enemy_formation()
	if is_guided_run and _guided_enemy_day == get_upcoming_day():
		return _guided_enemy_roster.duplicate()
	var roster: Array[RosterUnitData] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, get_upcoming_day(), "guided-enemy-stats"])
	for spec in upcoming_enemy_formation:
		if spec.unit_data == null:
			continue
		var stats := spec.unit_data.make_stats(rng if is_guided_run else null)
		var unit_name := spec.unit_data.display_name
		if unit_name.is_empty():
			unit_name = UnitNames.pick(rng if is_guided_run else null)
		roster.append(RosterUnitData.create_enemy(unit_name, stats, spec.unit_data))
	if is_guided_run:
		_guided_enemy_roster = roster.duplicate()
		_guided_enemy_day = get_upcoming_day()
	return roster


func ensure_guided_preparation_checkpoint() -> void:
	if not is_guided_run or has_won_run():
		return
	if _guided_preparation_checkpoint != null and _guided_preparation_checkpoint.day == current_day:
		return
	ensure_guided_preparation()
	_guided_preparation_checkpoint = GuidedRunSnapshot.new()
	_guided_preparation_checkpoint.enemy_roster = make_upcoming_enemy_roster()
	_guided_preparation_checkpoint.capture()
	_guided_battle_checkpoint = null


func capture_guided_battle_checkpoint(enemy_roster: Array[RosterUnitData]) -> void:
	if not is_guided_run:
		return
	_guided_battle_checkpoint = GuidedRunSnapshot.new()
	_guided_battle_checkpoint.enemy_roster = enemy_roster.duplicate()
	_guided_battle_checkpoint.capture()


func has_guided_battle_checkpoint() -> bool:
	return is_guided_run and _guided_battle_checkpoint != null


func restart_guided_battle() -> bool:
	if not has_guided_battle_checkpoint():
		return false
	_guided_battle_checkpoint.restore()
	BattleLaunch.set_enemy_roster(_guided_battle_checkpoint.enemy_roster)
	return true


func restore_guided_preparation() -> bool:
	if not is_guided_run or _guided_preparation_checkpoint == null:
		return false
	_guided_preparation_checkpoint.restore()
	_guided_battle_checkpoint = null
	return true


func finish_run(completed: bool = false) -> void:
	if not run_started or _run_finished:
		return
	_run_finished = true
	if is_guided_run:
		var reached_day := get_upcoming_day()
		if DaySummaryFeed.guided_result:
			reached_day = DaySummaryFeed.battle_day
		Analytics.guided_run_ended(completed, reached_day)
		SettingsServer.record_guided_run_end(completed)
