extends Node

## Public Run lifecycle checks. Run: godot --headless --path . res://tests/guided_run_test.tscn
var _failures: int = 0
var _checks: int = 0
var _settings_existed: bool = false
var _settings_bytes := PackedByteArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	Analytics.ga = null
	_settings_existed = FileAccess.file_exists(SettingsServer.PATH)
	if _settings_existed:
		_settings_bytes = FileAccess.get_file_as_bytes(SettingsServer.PATH)
	_test_mode_and_unlocks()
	_test_late_nursery_and_offers()
	_test_new_unlock_actions()
	_test_full_shop_and_restore()
	_test_battle_and_preparation_restore()
	_test_compost_and_lineage_restore()
	_test_seal_restore()
	_test_full_seal_pool()
	_test_terminal_preference()
	if _settings_existed:
		var file := FileAccess.open(SettingsServer.PATH, FileAccess.WRITE)
		file.store_buffer(_settings_bytes)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SettingsServer.PATH))
	print("Guided Run checks: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_mode_and_unlocks() -> void:
	SettingsServer.set_guided_run_enabled(false)
	GameState.reset_run()
	_expect(not GameState.is_guided_run, "New Run respects an immediate opt-out")
	SettingsServer.set_guided_run_enabled(true)
	GameState.reset_run()
	_expect(GameState.is_guided_run, "New Run uses the selected guided mode")
	GameState.reset_run(true)
	_expect(GameState.get_run_length() == 15, "Guided Run lasts 15 Days")
	_expect(GameState.troop.living_unit_count() == 1, "Opening has one fixed Adult")
	_expect(GameState.troop.get_squad_roster()[0].weapon_trainings == [WeaponSchool.Id.SWORD], "Opening Adult has Sword only")
	_expect(GameState.troop.get_squad_roster()[0].generation == 2, "Starter Adult uses normal Generation II")
	_expect(not GameState.pending_seal_choice, "Opening has no Seal gate")
	_expect(not GameState.is_nursery_unlocked(), "Nursery initially hidden")
	_expect(not GameState.try_plant_fresh_common(0), "Hidden Nursery rejects planting")
	_expect(not GameState.is_school_available(WeaponSchool.Id.SWORD), "No Training school on Day 1")
	for day in range(2, 16):
		GameState.debug_advance_day()
		_expect(GameState.get_upcoming_day() == day, "Day advances without tutorial actions: %d" % day)
		_expect(GameState.is_school_available(WeaponSchool.Id.BOW), "Bow stays available from Day 2")
		_expect(GameState.is_school_available(WeaponSchool.Id.SWORD) == (day >= 3), "Sword schedule")
		_expect(GameState.is_school_available(WeaponSchool.Id.MACE) == (day >= 4), "Mace unlocks on Day 4")
		_expect(GameState.is_school_available(WeaponSchool.Id.SHIELD) == (day >= 8), "Shield schedule")
		_expect(GameState.is_school_available(WeaponSchool.Id.SPEAR) == (day >= 13), "Spear completes the school unlocks on Day 13")
		_expect(GameState.is_feature_available(&"progression") == (day >= 4), "Progression schedule")
		_expect(GameState.is_nursery_unlocked() == (day >= 6), "Nursery schedule")
		_expect(GameState.is_feature_available(&"shop") == (day >= 7), "Shop schedule")
		_expect(GameState.is_feature_available(&"mutations") == (day >= 8), "Mutation schedule")
		_expect(GameState.troop.can_unlock_squad_slot() == (day >= 9), "Squad capacity schedule")
		_expect(GameState.nursery.can_unlock_plot() == (day >= 9), "Plot capacity schedule")
		_expect(GameState.is_feature_available(&"compost") == (day >= 11), "Compost schedule")
		_expect(GameState.is_feature_available(&"full_shop") == (day >= 12), "Full Shop schedule")
		_expect(GameState.is_feature_available(&"shop_reroll") == (day >= 12), "Shop reroll schedule")
		_expect(GameState.is_feature_available(&"offer_locks") == (day >= 12), "Shop lock schedule")
		_expect(GameState.is_feature_available(&"full_seal_pool") == (day >= 13), "Full Seal pool schedule")
		_expect(GameState.is_seal_choice_day(day) == (day in [11, 13, 15]), "Seal receiving Day %d" % day)
		_expect(GameState.troop.living_unit_count() == 2, "Reserved Child appears exactly once")
		if day == 11:
			_expect(not GameState.has_won_run(), "Day-10 victory continues the guided Run")
	GameState.debug_advance_day()
	_expect(GameState.has_won_run(), "Day-15 victory completes the guided Run")
	GameState.reset_run(false)
	_expect(GameState.get_run_length() == 10, "Ordinary length unchanged")
	_expect(GameState.pending_seal_choice, "Ordinary opening retains Seal")
	_expect(GameState.is_school_available(WeaponSchool.Id.SHIELD), "Ordinary schools unchanged")
	GameState.debug_advance_day()
	_expect(GameState.is_nursery_unlocked(), "Ordinary Nursery still unlocks after Day 1")
	for day in range(1, 11):
		_expect(GameState.is_seal_choice_day(day) == (day in [1, 3, 6, 9]), "Ordinary receiving Day %d" % day)


func _test_late_nursery_and_offers() -> void:
	_prepare_day(9)
	GameState.biomass.add(30)
	_expect(GameState.try_plant_fresh_common(0), "Late first planting succeeds")
	var plot: NurseryPlotData = GameState.nursery.plots[0]
	_expect(plot.remaining_days() == 1, "First grow still takes one Day when planted late")
	var offer: ShopOffer = GameState.nursery.spore_shop.offers[0]
	_expect(offer.item == GuidedRun.QUICK_GROWTH, "Quick Growth remains available for late use")
	_expect(GameState.nursery.spore_shop.offers[2].item == GuidedRun.THORNY, "Thorny remains available")
	_expect(GameState.nursery.spore_shop.offers[1] == null, "Other offers remain hidden")
	GameState.nursery.replace_shop_slot(0)
	GameState.nursery.ensure_shop_offers()
	_expect(GameState.nursery.spore_shop.offers[0] == null, "Refresh never replenishes a bought offer")
	GameState.debug_advance_day()
	_expect(plot.can_harvest(), "Late first grow is ready before Battle 10")
	_expect(GameState.nursery.spore_shop.offers[0] != null, "Next Day replenishes introductory offer")
	var children := GameState.nursery.harvest(0)
	_expect(children.size() == 1 and not children[0].is_adult_stage(), "Harvest yields a Child")


func _test_new_unlock_actions() -> void:
	_prepare_day(3)
	GameState.biomass.add(100)
	var child: RosterUnitData = GameState.troop.squad[1]
	var before := GameState.biomass.amount
	_expect(not GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.MACE), "Mace rejects Training before Day 4")
	_expect(GameState.biomass.amount == before, "Unavailable Training never spends biomass")
	GameState.debug_advance_day()
	_expect(GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.MACE), "Mace can be trained on Day 4")
	GameState.debug_advance_day()
	_expect(child.is_adult_stage() and child.weapon_trainings.has(WeaponSchool.Id.MACE), "Day-4 Mace Training emerges for the Log battle")

	_prepare_day(7)
	GameState.biomass.add(10)
	child = GameState.troop.squad[1]
	before = GameState.biomass.amount
	_expect(not GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.SHIELD), "Shield rejects Training before Day 8")
	_expect(GameState.biomass.amount == before, "Unavailable Shield Training spends no biomass")
	GameState.debug_advance_day()
	_expect(GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.SHIELD), "Day 8 allows Shield Training")
	_expect(GameState.biomass.amount == before - WeaponSchool.COCOON_COST, "Shield Training charges its normal price")

	_prepare_day(8)
	GameState.biomass.add(200)
	before = GameState.biomass.amount
	_expect(not GameState.try_unlock_plot(), "Plot expansion rejects purchases before Day 9")
	_expect(not GameState.try_unlock_squad_slot(), "Squad expansion rejects purchases before Day 9")
	_expect(GameState.biomass.amount == before, "Unavailable capacity actions leave the balance unchanged")
	GameState.debug_advance_day()
	var plot_count := GameState.nursery.unlocked_plot_count
	var plot_cost := GameState.nursery.next_unlock_cost()
	var squad_cost := GameState.troop.next_squad_unlock_cost()
	_expect(GameState.try_unlock_plot(), "Day 9 allows a normal Plot expansion purchase")
	_expect(GameState.try_unlock_squad_slot(), "Day 9 allows a normal Squad expansion purchase")
	_expect(GameState.nursery.unlocked_plot_count == plot_count + 1, "Purchased Plot becomes available")
	_expect(GameState.biomass.amount == before - plot_cost - squad_cost, "Expansion purchases charge their normal prices")
	_expect(GameState.try_plant_fresh_common(plot_count), "The purchased Plot accepts a fresh grow")
	before = GameState.biomass.amount
	_expect(GameState.nursery.unlocked_plot_count == 2 and not GameState.nursery.can_unlock_plot(), "Guided Plot expansion stops at two total Plots")
	_expect(GameState.nursery.next_unlock_cost() == -1, "Guided Run has no third Plot purchase offer")
	_expect(not GameState.try_unlock_plot() and GameState.biomass.amount == before, "A rejected third Plot purchase spends no biomass")
	_expect(not GameState.nursery.unlock_next_plot(), "The Nursery also rejects directly unlocking a third guided Plot")
	for day in range(10, 16):
		GameState.debug_advance_day()
		_expect(not GameState.try_unlock_plot() and GameState.nursery.unlocked_plot_count == 2, "Two-Plot limit remains on Day %d" % day)

	_prepare_day(12)
	GameState.biomass.add(10)
	child = GameState.troop.squad[1]
	_expect(not GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.SPEAR), "Spear remains unavailable before Day 13")
	GameState.debug_advance_day()
	_expect(GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.SPEAR), "Day 13 allows Spear Training")
	for school in WeaponSchool.DISPLAY_ORDER:
		_expect(GameState.is_school_available(school), "Every school is available by Day 13")
	GameState.reset_run(false)
	GameState.biomass.add(100)
	for count in range(2, 5):
		_expect(GameState.try_unlock_plot() and GameState.nursery.unlocked_plot_count == count, "Ordinary Runs can still expand to %d Plots" % count)
	_expect(not GameState.try_unlock_plot(), "Ordinary Plot capacity still stops at four")


func _test_full_shop_and_restore() -> void:
	_prepare_day(11)
	GameState.biomass.add(200)
	var shop := GameState.nursery.spore_shop
	var intro_offers := shop.offers.duplicate()
	_expect(not GameState.is_guided_shop_slot_available(1) and not GameState.is_guided_shop_slot_available(3), "Additional Shop slots remain hidden before Day 12")
	GameState.nursery.reroll_unlocked_shop_offers()
	_expect(shop.offers == intro_offers, "Early restricted offers cannot be rerolled into the full catalog")
	GameState.debug_advance_day()
	for slot in NurseryData.SHOP_SLOT_COUNT:
		var offer := shop.offers[slot]
		_expect(GameState.is_guided_shop_slot_available(slot) and offer != null, "Day 12 fills Shop slot %d" % slot)
		if offer != null:
			var right_kind := offer.item is FertilizerData if slot < 2 else offer.item is MutationData
			_expect(right_kind, "Full Shop preserves the normal slot type")
	_expect(shop.offers[0].item != shop.offers[1].item, "Full Shop includes distinct normal Fertilizers beyond Quick Growth")
	_expect(shop.offers[2].item != shop.offers[3].item, "Full Shop includes distinct normal Mutations beyond Thorny")
	var before := GameState.biomass.amount
	var full_offers := shop.offers.duplicate()
	GameState.ensure_guided_preparation_checkpoint()
	shop.set_locked(0, true)
	var purchase: ShopOffer = shop.offers[1]
	_expect(GameState.try_buy_fertilizer(purchase.item as FertilizerData, SealModifiers.fertilizer_cost(purchase.cost)), "A full-catalog Fertilizer can be bought")
	GameState.nursery.replace_shop_slot(1)
	var prepared_offers := shop.offers.duplicate()
	GameState.nursery.ensure_shop_offers()
	GameState.ensure_guided_preparation()
	_expect(shop.offers == prepared_offers and shop.offers[1] == null, "Ensuring full Shop preserves offers, locks and a purchased empty slot")
	var prepared := BaseUndoSnapshot.new()
	prepared.capture()
	GameState.capture_guided_battle_checkpoint(GameState.make_upcoming_enemy_roster())
	var mutation_offer: ShopOffer = shop.offers[2]
	_expect(GameState.try_buy_mutation(mutation_offer.item as MutationData, SealModifiers.mutation_cost(mutation_offer.cost)), "A full-catalog Mutation can be bought")
	GameState.nursery.replace_shop_slot(2)
	GameState.nursery.reroll_unlocked_shop_offers()
	GameState.nursery.advance_shop_reroll_cost()
	_expect(GameState.restart_guided_battle(), "Full-Shop Battle can be restarted")
	GameState.ensure_guided_preparation()
	_expect(prepared.matches_current_state(), "Battle retry restores exact full-Shop offers, Stock, locks, reroll count and balance")
	_expect(GameState.restore_guided_preparation(), "Full-Shop preparation can be restored")
	GameState.nursery.ensure_shop_offers()
	_expect(shop.offers == full_offers and not shop.is_locked(0), "Preparation restore keeps the original rolled offers and undoes locks")
	_expect(GameState.biomass.amount == before and GameState.nursery.stock.slots.all(func(item: Resource) -> bool: return item == null), "Preparation restore refunds purchases and removes their Stock")
	shop.set_locked(0, true)
	var locked_offer := shop.offers[0]
	var unlocked_offer := shop.offers[1]
	GameState.nursery.reroll_unlocked_shop_offers()
	_expect(shop.offers[0] == locked_offer and shop.is_locked(0), "A locked full-Shop offer survives reroll")
	_expect(shop.offers[1] != unlocked_offer, "An unlocked full-Shop offer is rerolled")
	GameState.debug_advance_day()
	_expect(shop.offers[0] == locked_offer and shop.is_locked(0), "A locked full-Shop offer survives the next Day's refresh")
	var next_day_offers := shop.offers.duplicate()
	GameState.ensure_guided_preparation()
	GameState.nursery.ensure_shop_offers()
	_expect(shop.offers == next_day_offers, "Ensuring the next Day never rerolls the already refreshed Shop")


func _test_battle_and_preparation_restore() -> void:
	_prepare_day(8)
	GameState.biomass.add(30)
	var starting_biomass := GameState.biomass.amount
	var child: RosterUnitData = GameState.troop.squad[1]
	var parent: RosterUnitData = GameState.troop.squad[0]
	GameState.ensure_guided_preparation_checkpoint()
	_expect(GameState.try_plant_fresh_common(0), "Preparation plants grow")
	_expect(GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.BOW), "Preparation trains Child")
	var launch_balance := GameState.biomass.amount
	var enemies := GameState.make_upcoming_enemy_roster()
	var enemy_strength := enemies[0].stats.strength
	GameState.capture_guided_battle_checkpoint(enemies)
	for attempt in 3:
		GameState.nursery.add_death_spore(parent)
		GameState.troop.remove_unit(parent)
		GameState.biomass.add(90)
		GameState.debug_advance_day()
		enemies[0].stats.strength = 99
		_expect(GameState.restart_guided_battle(), "Retry remains repeatable")
		_expect(GameState.current_day == 7, "Retry restores the Battle's Day")
		_expect(GameState.biomass.amount == launch_balance, "Retry discards attempted reward")
		_expect(GameState.troop.squad[0] == parent and not parent.emitted_death_spore, "Retry restores dead parent's identity and state")
		_expect(not GameState.nursery.has_spore_in_stock(), "Retry removes attempted death spore")
		_expect(GameState.pupation.find_school_for_unit(child) == WeaponSchool.Id.BOW, "Retry undoes premature Training tick")
		_expect((GameState.nursery.plots[0] as NurseryPlotData).remaining_days() == 1, "Retry undoes grow tick")
		_expect(BattleLaunch.enemy_roster[0].stats.strength == enemy_strength, "Retry preserves exact enemy roll")
	_expect(GameState.restore_guided_preparation(), "Change preparation restores checkpoint")
	_expect(GameState.biomass.amount == starting_biomass, "Change preparation refunds that Day's spending")
	_expect(GameState.troop.squad[1] == child and not child.is_adult_stage(), "Change preparation restores untrained Child")
	_expect((GameState.nursery.plots[0] as NurseryPlotData).is_empty(), "Change preparation removes that Day's grow")
	_expect(GameState.make_upcoming_enemy_roster()[0].stats.strength == enemy_strength, "Change preparation keeps enemy roll")
	_expect(not GameState.has_guided_battle_checkpoint(), "New preparation invalidates old battle checkpoint")


func _test_compost_and_lineage_restore() -> void:
	_prepare_day(11)
	GameState.biomass.add(40)
	var parent: RosterUnitData = GameState.troop.squad[0]
	parent.body_mutation = GuidedRun.THORNY
	var starting_biomass := GameState.biomass.amount
	GameState.ensure_guided_preparation_checkpoint()
	_expect(GameState.try_cocoon_for_pupation(parent, WeaponSchool.Id.MACE), "Available Adult Training is instant")
	_expect(GameState.try_compost_unit(parent), "Optional Compost produces a lineage spore")
	var spore := GameState.nursery.stock.get_at(0) as SporeData
	_expect(spore != null and spore.weapon_trainings == [WeaponSchool.Id.SWORD, WeaponSchool.Id.MACE], "Lineage saves actual Adult Trainings")
	_expect(spore != null and spore.body_mutation != null, "Lineage saves parent Mutation")
	var after_compost := GameState.biomass.amount
	_expect(GameState.nursery.plant(0, 0), "Lineage planting consumes owned spore")
	_expect(GameState.biomass.amount == after_compost, "Lineage planting has no fresh-grow cost")
	GameState.capture_guided_battle_checkpoint(GameState.make_upcoming_enemy_roster())
	GameState.debug_advance_day()
	var descendants := GameState.nursery.harvest(0)
	_expect(descendants.size() == 1 and descendants[0].generation == parent.generation + 1, "Actual lineage grow yields next Generation")
	_expect(GameState.restart_guided_battle(), "Lineage Battle can be replayed")
	_expect(not GameState.nursery.has_spore_in_stock(), "Replay does not duplicate planted spore")
	_expect(not GameState.troop.squad.has(parent), "Replay retains accepted Compost preparation")
	_expect(GameState.restore_guided_preparation(), "Compost preparation can be changed")
	_expect(GameState.troop.squad.has(parent) and parent.weapon_trainings == [WeaponSchool.Id.SWORD], "Preparation restores parent and removes instant Training")
	_expect(GameState.biomass.amount == starting_biomass, "Preparation removes Compost payout and refunds Training")
	_expect(not GameState.nursery.has_spore_in_stock() and GameState.nursery.plots[0].is_empty(), "Preparation removes lineage spore and grow together")


func _test_seal_restore() -> void:
	_prepare_day(11)
	var offers := GameState.ensure_seal_choice_offers().duplicate()
	_expect(offers == GuidedRun.SEALS and offers.size() == 3, "First Seal choice retains the three introductory offers")
	_expect(not GameState.try_add_seal(SealCatalog.by_id(&"greenhouse")), "Introductory choice rejects an unoffered Seal")
	GameState.ensure_guided_preparation_checkpoint()
	_expect(GameState.try_add_seal(offers[0]), "Introductory Seal can be chosen")
	GameState.clear_pending_seal_choice()
	GameState.capture_guided_battle_checkpoint(GameState.make_upcoming_enemy_roster())
	_expect(GameState.restart_guided_battle() and GameState.seals.owned.size() == 1, "Battle retry retains chosen Seal once")
	_expect(GameState.restore_guided_preparation(), "Seal preparation can be restored")
	_expect(GameState.pending_seal_choice and GameState.seals.owned.is_empty(), "Preparation restores pending choice without bonus")
	_expect(GameState.ensure_seal_choice_offers() == offers, "Preparation keeps same Seal offers")
	GameState.try_add_seal(offers[0])
	GameState.clear_pending_seal_choice()
	GameState.debug_advance_day()
	_expect(not GameState.pending_seal_choice, "Day 12 does not grant another Seal")
	_expect(not GameState.try_add_seal(offers[0]), "An already accepted offer cannot be chosen again without a pending reward")


func _test_full_seal_pool() -> void:
	_prepare_day(12)
	var introductory := GameState.ensure_seal_choice_offers()[0]
	_expect(GameState.try_add_seal(introductory), "Deferred first Seal can still be accepted")
	GameState.clear_pending_seal_choice()
	# A pre-owned unique Seal fixture verifies the full pool's normal exclusion rule.
	var owned_unique := SealCatalog.by_id(&"greenhouse")
	GameState.seals.add(owned_unique)
	seed(90210)
	GameState.debug_advance_day()
	var offers := GameState.ensure_seal_choice_offers().duplicate()
	_expect(offers.size() == 3 and GameState.pending_seal_choice, "Day 13 rolls three full-pool Seal offers")
	_expect(not offers.has(owned_unique), "An owned unique Seal is excluded from guided full-pool offers")
	var selected: SealData = null
	var distinct: Dictionary = {}
	for seal: SealData in offers:
		distinct[seal.id] = true
		_expect(SealCatalog.eligible_pool(GameState.seals).has(seal), "Full-pool offer obeys normal Seal eligibility")
		if selected == null and not GuidedRun.SEALS.has(seal):
			selected = seal
	_expect(distinct.size() == 3, "Later Seal offers are distinct")
	_expect(selected != null, "Full-pool fixture offers a Seal beyond the introductory three")
	if selected == null:
		return
	var unoffered: SealData = null
	for seal in SealCatalog.eligible_pool(GameState.seals):
		if not offers.has(seal):
			unoffered = seal
			break
	_expect(not GameState.try_add_seal(unoffered), "Later guided choices reject a Seal that was not actually offered")
	var adult: RosterUnitData = GameState.troop.squad[0]
	adult.body_mutation = GuidedRun.THORNY
	var before := _seal_modifiers()
	var earlier_seals := GameState.seals.owned.duplicate()
	GameState.ensure_guided_preparation_checkpoint()
	_expect(GameState.try_add_seal(selected), "An actual nonintroductory Seal offer can be selected")
	GameState.clear_pending_seal_choice()
	var chosen := _seal_modifiers()
	_expect(chosen != before, "The selected full-pool Seal applies its normal gameplay modifier")
	GameState.capture_guided_battle_checkpoint(GameState.make_upcoming_enemy_roster())
	GameState.debug_advance_day()
	_expect(not GameState.pending_seal_choice, "Day 14 does not grant a Seal")
	_expect(GameState.restart_guided_battle() and _seal_modifiers() == chosen, "Battle retry retains the chosen full-pool Seal and effect")
	_expect(GameState.restore_guided_preparation(), "Full-pool Seal preparation can be changed")
	_expect(GameState.seals.owned == earlier_seals and _seal_modifiers() == before, "Preparation restore removes only the new Seal and its effect")
	_expect(GameState.pending_seal_choice and GameState.ensure_seal_choice_offers() == offers, "Preparation restore keeps the same full-pool offers pending")
	GameState.try_add_seal(selected)
	GameState.clear_pending_seal_choice()
	GameState.debug_advance_day()
	GameState.debug_advance_day()
	var final_offers := GameState.ensure_seal_choice_offers().duplicate()
	_expect(final_offers.size() == 3 and GameState.pending_seal_choice, "Day 15 grants another normal three-offer Seal choice")
	for seal: SealData in final_offers:
		_expect(not seal.is_unique or not GameState.seals.owns(seal.id), "Final Seal offers exclude every owned unique Seal")
	_expect(GameState.ensure_seal_choice_offers() == final_offers, "Repeated inspection keeps the same final Seal offers")


func _seal_modifiers() -> Array:
	var values: Array = [
		SealModifiers.fresh_plant_cost(), SealModifiers.fertilizer_cost(20),
		SealModifiers.mutation_cost(20), SealModifiers.greenhouse_day_reduction(),
		SealModifiers.max_fertilizer_stacks(), SealModifiers.max_mutation_slots(),
		SealModifiers.attack_rate_multiplier(), SealModifiers.wooden_heart_flat_hp(),
		SealModifiers.wooden_melee_flat_damage(), SealModifiers.wooden_ranged_flat_damage(),
		SealModifiers.golden_mould_biomass(), SealModifiers.favourite_child_owned(),
	]
	for unit: RosterUnitData in GameState.troop.get_squad_roster():
		values.append(SealModifiers.unit_atk_multiplier(unit))
		values.append(SealModifiers.unit_hp_multiplier(unit))
	return values


func _test_terminal_preference() -> void:
	SettingsServer.guided_run_enabled = true
	SettingsServer.guided_run_ended = false
	SettingsServer.guided_run_completed = false
	GameState.reset_run(true)
	GameState.ensure_guided_preparation_checkpoint()
	GameState.capture_guided_battle_checkpoint(GameState.make_upcoming_enemy_roster())
	GameState.restart_guided_battle()
	_expect(SettingsServer.guided_run_enabled and not SettingsServer.guided_run_ended, "Retry does not end first guided Run")
	GameState.finish_run()
	_expect(not SettingsServer.guided_run_enabled and SettingsServer.guided_run_ended, "First explicit end unchecks next Run")
	_expect(not SettingsServer.guided_run_completed, "Early end does not record completion")
	SettingsServer.set_guided_run_enabled(true)
	GameState.reset_run(true)
	GameState.finish_run(true)
	_expect(SettingsServer.guided_run_enabled, "Later manual replay preference survives terminal end")
	_expect(SettingsServer.guided_run_completed, "Accepted final victory records completion")
	GameState.reset_run(false)
	GameState.finish_run()
	_expect(SettingsServer.guided_run_enabled, "Ordinary end does not change guided preference")


func _prepare_day(day: int) -> void:
	GameState.reset_run(true)
	while GameState.get_upcoming_day() < day:
		GameState.debug_advance_day()


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
