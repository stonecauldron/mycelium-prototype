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
	_test_guided_biomass()
	_test_late_nursery_and_offers()
	_test_new_unlock_actions()
	_test_full_shop_and_restore()
	_test_first_full_shop_quick_growth()
	_test_battle_and_preparation_restore()
	_test_compost_and_lineage_restore()
	_test_seal_restore()
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
	_expect(GameState.get_run_length() == 10, "Guided Run lasts 10 Days")
	_expect(GameState.troop.living_unit_count() == 1, "Opening has one fixed Adult")
	_expect(GameState.troop.get_squad_roster()[0].weapon_trainings == [WeaponSchool.Id.SWORD], "Opening Adult has Sword only")
	_expect(GameState.troop.get_squad_roster()[0].generation == 2, "Starter Adult uses normal Generation II")
	_expect(not GameState.pending_seal_choice, "Opening has no Seal gate")
	_expect(not GameState.should_show_player_flag_bearer(), "Guided opening hides the flag bearer")
	_expect(not GameState.is_nursery_unlocked(), "Nursery initially hidden")
	_expect(not GameState.try_plant_fresh_common(0), "Hidden Nursery rejects planting")
	_expect(not GameState.is_school_available(WeaponSchool.Id.SWORD), "No Training school on Day 1")
	for day in range(2, 11):
		GameState.debug_advance_day()
		_expect(GameState.get_upcoming_day() == day, "Day advances without tutorial actions: %d" % day)
		_expect(GameState.is_school_available(WeaponSchool.Id.BOW), "Bow stays available from Day 2")
		_expect(GameState.is_school_available(WeaponSchool.Id.SWORD) == (day >= 3), "Sword schedule")
		_expect(GameState.is_school_available(WeaponSchool.Id.MACE) == (day >= 4), "Mace unlocks on Day 4")
		_expect(GameState.is_school_available(WeaponSchool.Id.SHIELD) == (day >= 7), "Shield schedule")
		_expect(GameState.is_school_available(WeaponSchool.Id.SPEAR) == (day >= 9), "Spear completes the school unlocks on Day 9")
		_expect(GameState.is_feature_available(&"progression") == (day >= 4), "Progression schedule")
		_expect(GameState.is_nursery_unlocked() == (day >= 5), "Nursery schedule")
		_expect(GameState.is_feature_available(&"bench") == (day >= 6), "Bench schedule")
		_expect(GameState.is_feature_available(&"shop") == (day >= 5), "Shop schedule")
		_expect(GameState.is_feature_available(&"mutations") == (day >= 6), "Mutation schedule")
		_expect(GameState.troop.can_unlock_squad_slot() == (day >= 6), "Squad capacity schedule")
		_expect(GameState.nursery.can_unlock_plot() == (day >= 8), "Plot capacity schedule")
		_expect(GameState.is_feature_available(&"compost") == (day >= 7), "Compost schedule")
		_expect(GameState.is_feature_available(&"full_shop") == (day >= 8), "Full Shop schedule")
		_expect(GameState.is_feature_available(&"shop_reroll") == (day >= 8), "Shop reroll schedule")
		_expect(GameState.is_feature_available(&"offer_locks") == (day >= 8), "Shop lock schedule")
		_expect(not GameState.is_feature_available(&"full_seal_pool"), "Guided Run keeps introductory Seal choices")
		_expect(GameState.is_seal_choice_day(day) == (day == 8), "Seal receiving Day %d" % day)
		_expect(GameState.is_feature_available(&"seals") == (day >= 8), "Seals unlock on Day 8")
		_expect(GameState.pending_seal_choice == (day == 8), "Only Day 8 queues a Seal choice")
		_expect(GameState.troop.living_unit_count() == 2, "Reserved Child appears exactly once")
		_expect(not GameState.has_won_run(), "Preparation before the final victory remains active")
		_expect(GameState.should_show_player_flag_bearer() == (day > 8), "Flag bearer appears only after confirming the Day-8 Seal")
		if day == 8:
			_expect(GameState.try_add_seal(GameState.ensure_seal_choice_offers()[0]), "Day-8 Seal can be confirmed")
			GameState.clear_pending_seal_choice()
	_expect(GameState.seals.owned.size() == 1, "Guided Run grants only one Seal")
	_expect(GameState.should_show_player_flag_bearer(), "First confirmed Seal reveals the flag bearer")
	GameState.debug_advance_day()
	_expect(GameState.has_won_run(), "Day-10 victory completes the guided Run")
	_expect(not GameState.pending_seal_choice, "Completion queues no further Seal choice")
	for day in range(11, 16):
		_expect(not GameState.is_seal_choice_day(day), "Guided Seal markers end with Battle 10")
	GameState.reset_run(false)
	_expect(GameState.get_run_length() == 10, "Ordinary length unchanged")
	_expect(GameState.pending_seal_choice, "Ordinary opening retains Seal")
	_expect(GameState.should_show_player_flag_bearer(), "Ordinary flag bearer remains visible before selection")
	_expect(GameState.is_school_available(WeaponSchool.Id.SHIELD), "Ordinary schools unchanged")
	GameState.debug_advance_day()
	_expect(GameState.is_nursery_unlocked(), "Ordinary Nursery still unlocks after Day 1")
	for day in range(1, 11):
		_expect(GameState.is_seal_choice_day(day) == (day in [1, 3, 6, 9]), "Ordinary receiving Day %d" % day)


func _test_guided_biomass() -> void:
	var budgets := [0, 4, 8, 4, 8, 16, 16, 21, 21, 0]
	GameState.reset_run(true)
	_expect(GameState.biomass.amount == 0, "Guided opening needs no paid actions")
	for day in range(1, 11):
		_expect(GuidedRun.biomass_budget_for_day(day) == budgets[day - 1], "Day %d grants its scheduled preparation allowance" % day)
		var target := int(budgets[day]) if day < 10 else 0
		var specs := GuidedRun.specs_for_day(day)
		for savings in [0, 1, target, target + 8]:
			GameState.biomass.amount = savings
			var reward := GameState.battle_reward_for(day, specs)
			_expect(reward == target, "Battle %d grants the full next-Day allowance regardless of savings" % day)
			_expect(GameState.biomass.amount == savings, "Reward preview never grants biomass")
	GameState.reset_run(true)
	var saved := 0
	for day in range(1, 10):
		GameState.debug_advance_day()
		saved += int(budgets[day])
		_expect(GameState.biomass.amount == saved, "Skipped spending carries over alongside the next grant")
	_expect(saved == 98, "Guided Run grants 98 total scheduled biomass")
	GameState.reset_run(false)
	_expect(GameState.biomass.amount == BiomassData.STARTING_AMOUNT, "Ordinary starting biomass is unchanged")
	for day in range(1, 11):
		var specs := EnemyComposer.specs_for_day(day)
		_expect(GameState.battle_reward_for(day, specs) == EnemyComposer.battle_reward_for(day, specs), "Ordinary Battle %d keeps its difficulty reward" % day)

	# Exercise the intended introduction purchases using only earned allowances.
	GameState.reset_run(true)
	var starter: RosterUnitData = GameState.troop.squad[0]
	GameState.debug_advance_day()
	var child: RosterUnitData = GameState.troop.squad[1]
	_expect(GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.BOW), "Day-2 allowance covers Bow")
	GameState.debug_advance_day()
	_expect(GameState.try_cocoon_for_pupation(starter, WeaponSchool.Id.BOW), "Day-3 allowance covers first combo Training")
	_expect(GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.SWORD), "Day-3 allowance covers second combo Training")
	GameState.debug_advance_day()
	_expect(GameState.try_cocoon_for_pupation(starter, WeaponSchool.Id.MACE), "Day-4 allowance covers Mace")
	GameState.debug_advance_day()
	_expect(GameState.try_plant_fresh_common(0), "Day-5 allowance covers fresh planting")
	_expect(GameState.try_buy_fertilizer(GuidedRun.QUICK_GROWTH, GuidedRun.QUICK_GROWTH.biomass_cost), "Day-5 allowance also covers Quick Growth")
	_expect(GameState.nursery.apply_fertilizer_from_stock(0, 0), "Funded Quick Growth can be applied")
	GameState.debug_advance_day()
	_expect(GameState.try_unlock_squad_slot(), "Day-6 allowance covers Squad expansion")
	_expect(GameState.try_buy_mutation(GuidedRun.THORNY, GuidedRun.THORNY.biomass_cost), "Day-6 allowance also covers Thorny")
	_expect(GameState.nursery.apply_mutation_from_stock(0, 0), "Funded Thorny can be applied")
	GameState.debug_advance_day()
	for unit in GameState.nursery.harvest(0):
		GameState.troop.try_add_unit(unit)
	_expect(GameState.try_cocoon_for_pupation(starter, WeaponSchool.Id.SHIELD), "Day-7 allowance covers Shield")
	GameState.debug_advance_day()
	_expect(GameState.try_unlock_plot(), "Day-8 allowance covers second Plot without requiring Compost")
	_expect(GameState.pending_seal_choice and GameState.try_add_seal(GameState.ensure_seal_choice_offers()[0]), "Day-8 Seal remains free")
	GameState.clear_pending_seal_choice()
	var offers := GameState.nursery.spore_shop.offers
	_expect(GameState.try_buy_fertilizer(offers[0].item as FertilizerData, offers[0].cost), "Day-8 allowance covers a full-Shop Fertilizer")
	_expect(GameState.try_buy_mutation(offers[2].item as MutationData, offers[2].cost), "Day-8 allowance covers a full-Shop Mutation")
	_expect(GameState.biomass.try_spend(GameState.nursery.current_shop_reroll_cost()), "Day-8 allowance covers one Shop reroll")
	_expect(GameState.biomass.amount >= 4, "Full Shop purchases leave the rounded 30 percent margin")
	GameState.debug_advance_day()
	_expect(GameState.try_cocoon_for_pupation(starter, WeaponSchool.Id.SPEAR), "Day-9 allowance covers Spear")
	GameState.debug_advance_day()
	_expect(not GameState.pending_seal_choice and GameState.seals.owned.size() == 1, "Day 10 retains the only Seal without another choice")


func _test_late_nursery_and_offers() -> void:
	_prepare_day(7)
	GameState.biomass.add(30)
	_expect(GameState.try_plant_fresh_common(0), "Late first planting succeeds")
	var plot: NurseryPlotData = GameState.nursery.plots[0]
	_expect(plot.remaining_days() == 2, "Guided first grow retains two Days even when planted late")
	var offer: ShopOffer = GameState.nursery.spore_shop.offers[0]
	_expect(offer.item == GuidedRun.QUICK_GROWTH, "Quick Growth remains available for late use")
	_expect(GameState.nursery.spore_shop.offers[2].item == GuidedRun.THORNY, "Thorny remains available")
	_expect(GameState.nursery.spore_shop.offers[1] == null, "Other offers remain hidden")
	GameState.nursery.replace_shop_slot(0)
	GameState.nursery.ensure_shop_offers()
	_expect(GameState.nursery.spore_shop.offers[0] == null, "Refresh never replenishes a bought offer")
	GameState.debug_advance_day()
	_expect(not plot.can_harvest() and plot.remaining_days() == 1, "Unaccelerated first grow still needs its second Day")
	_expect(GameState.nursery.spore_shop.offers[0] != null, "Day 8 fills the newly unlocked full Shop")
	GameState.debug_advance_day()
	_expect(plot.can_harvest(), "Unaccelerated grow is ready after two victories")
	var children := GameState.nursery.harvest(0)
	_expect(children.size() == 1 and not children[0].is_adult_stage(), "Harvest yields a Child")

	_prepare_day(5)
	GameState.biomass.add(30)
	_expect(GameState.try_plant_fresh_common(0), "First Nursery-Day planting succeeds")
	plot = GameState.nursery.plots[0]
	_expect(plot.remaining_days() == 2, "First guided grow has its normal two-Day wait")
	_expect(GameState.try_buy_fertilizer(GuidedRun.QUICK_GROWTH, GuidedRun.QUICK_GROWTH.biomass_cost), "Quick Growth can be bought on Day 5")
	_expect(GameState.nursery.apply_fertilizer_from_stock(0, 0), "Day-5 Quick Growth can be applied")
	_expect(plot.remaining_days() == 1, "Quick Growth saves one Day on the first grow")
	GameState.debug_advance_day()
	_expect(plot.can_harvest(), "Quick Growth makes the first grow ready on Day 6")

	GameState.reset_run(false)
	GameState.debug_advance_day()
	GameState.biomass.add(30)
	_expect(GameState.try_plant_fresh_common(0), "Ordinary first planting succeeds")
	_expect(GameState.nursery.plots[0].remaining_days() == 1, "Ordinary first-grow acceleration is unchanged")


func _test_new_unlock_actions() -> void:
	_prepare_day(6)
	var parent: RosterUnitData = GameState.troop.squad[0]
	_expect(not GameState.try_compost_unit(parent), "Compost rejects actions before Day 7")
	GameState.debug_advance_day()
	_expect(GameState.try_compost_unit(parent), "Day 7 allows Compost")
	_expect(GameState.nursery.has_spore_in_stock(), "Day-7 Compost produces a lineage Spore")
	_expect(GameState.nursery.plant(0, GameState.nursery.first_spore_stock_index()), "The early lineage Spore can be planted")
	GameState.debug_advance_day()
	_expect(GameState.nursery.plots[0].can_harvest(), "Early lineage is ready before Battle 8")

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

	_prepare_day(6)
	GameState.biomass.add(10)
	child = GameState.troop.squad[1]
	before = GameState.biomass.amount
	_expect(not GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.SHIELD), "Shield rejects Training before Day 7")
	_expect(GameState.biomass.amount == before, "Unavailable Shield Training spends no biomass")
	GameState.debug_advance_day()
	before = GameState.biomass.amount
	_expect(GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.SHIELD), "Day 7 allows Shield Training")
	_expect(GameState.biomass.amount == before - WeaponSchool.COCOON_COST, "Shield Training charges its normal price")

	_prepare_day(7)
	GameState.biomass.add(200)
	before = GameState.biomass.amount
	_expect(not GameState.try_unlock_plot(), "Plot expansion rejects purchases before Day 8")
	_expect(GameState.biomass.amount == before, "Unavailable capacity actions leave the balance unchanged")
	GameState.debug_advance_day()
	before = GameState.biomass.amount
	var plot_count := GameState.nursery.unlocked_plot_count
	var plot_cost := GameState.nursery.next_unlock_cost()
	_expect(GameState.try_unlock_plot(), "Day 8 allows a normal Plot expansion purchase")
	_expect(GameState.nursery.unlocked_plot_count == plot_count + 1, "Purchased Plot becomes available")
	_expect(GameState.biomass.amount == before - plot_cost, "Plot purchase charges its normal price")
	_expect(GameState.try_plant_fresh_common(plot_count), "The purchased Plot accepts a fresh grow")
	before = GameState.biomass.amount
	_expect(GameState.nursery.unlocked_plot_count == 2 and not GameState.nursery.can_unlock_plot(), "Guided Plot expansion stops at two total Plots")
	_expect(GameState.nursery.next_unlock_cost() == -1, "Guided Run has no third Plot purchase offer")
	_expect(not GameState.try_unlock_plot() and GameState.biomass.amount == before, "A rejected third Plot purchase spends no biomass")
	_expect(not GameState.nursery.unlock_next_plot(), "The Nursery also rejects directly unlocking a third guided Plot")
	GameState.debug_advance_day()
	_expect(not GameState.try_unlock_plot() and GameState.nursery.unlocked_plot_count == 2, "Two-Plot limit remains after more progression")

	_prepare_day(5)
	GameState.biomass.add(100)
	before = GameState.biomass.amount
	_expect(not GameState.try_unlock_squad_slot() and GameState.biomass.amount == before, "Squad expansion is unavailable before Day 6")
	GameState.debug_advance_day()
	before = GameState.biomass.amount
	var squad_cost := GameState.troop.next_squad_unlock_cost()
	_expect(GameState.try_unlock_squad_slot(), "Squad expansion unlocks on Day 6")
	_expect(GameState.biomass.amount == before - squad_cost, "Squad expansion charges its normal price")

	_prepare_day(8)
	GameState.biomass.add(10)
	child = GameState.troop.squad[1]
	_expect(not GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.SPEAR), "Spear remains unavailable before Day 9")
	GameState.debug_advance_day()
	_expect(GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.SPEAR), "Day 9 allows Spear Training")
	for school in WeaponSchool.DISPLAY_ORDER:
		_expect(GameState.is_school_available(school), "Every school is available by Day 9")
	GameState.reset_run(false)
	GameState.biomass.add(100)
	for count in range(2, 5):
		_expect(GameState.try_unlock_plot() and GameState.nursery.unlocked_plot_count == count, "Ordinary Runs can still expand to %d Plots" % count)
	_expect(not GameState.try_unlock_plot(), "Ordinary Plot capacity still stops at four")


func _test_full_shop_and_restore() -> void:
	_prepare_day(7)
	GameState.biomass.add(200)
	var shop := GameState.nursery.spore_shop
	var intro_offers := shop.offers.duplicate()
	_expect(not GameState.is_guided_shop_slot_available(1) and not GameState.is_guided_shop_slot_available(3), "Additional Shop slots remain hidden before Day 8")
	GameState.nursery.reroll_unlocked_shop_offers()
	_expect(shop.offers == intro_offers, "Early restricted offers cannot be rerolled into the full catalog")
	GameState.debug_advance_day()
	for slot in NurseryData.SHOP_SLOT_COUNT:
		var offer := shop.offers[slot]
		_expect(GameState.is_guided_shop_slot_available(slot) and offer != null, "Day 8 fills Shop slot %d" % slot)
		if offer != null:
			var right_kind := offer.item is FertilizerData if slot < 2 else offer.item is MutationData
			_expect(right_kind, "Full Shop preserves the normal slot type")
	_expect(shop.offers[0].item != shop.offers[1].item, "Full Shop includes distinct normal Fertilizers beyond Quick Growth")
	_expect(shop.offers[0].item == GuidedRun.QUICK_GROWTH, "The first full Shop guarantees Quick Growth")
	_expect(shop.offers[0].cost == GuidedRun.QUICK_GROWTH.biomass_cost, "Scripted Quick Growth keeps its normal price")
	_expect(shop.offers[2].item != shop.offers[3].item, "Full Shop includes distinct normal Mutations beyond Thorny")
	var before := GameState.biomass.amount
	var full_offers := shop.offers.duplicate()
	GameState.ensure_guided_preparation_checkpoint()
	shop.set_locked(1, true)
	var purchase: ShopOffer = shop.offers[0]
	_expect(GameState.try_buy_fertilizer(purchase.item as FertilizerData, SealModifiers.fertilizer_cost(purchase.cost)), "The guaranteed Quick Growth can be bought")
	GameState.nursery.replace_shop_slot(0)
	var prepared_offers := shop.offers.duplicate()
	GameState.nursery.ensure_shop_offers()
	GameState.ensure_guided_preparation()
	_expect(shop.offers == prepared_offers and shop.offers[0] == null, "Ensuring full Shop preserves offers, locks and purchased Quick Growth's empty slot")
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
	_expect(shop.offers == full_offers and not shop.is_locked(1), "Preparation restore keeps the original scripted draw and undoes locks")
	_expect(GameState.biomass.amount == before and GameState.nursery.stock.slots.all(func(item: Resource) -> bool: return item == null), "Preparation restore refunds purchases and removes their Stock")
	shop.set_locked(0, true)
	var locked_offer := shop.offers[0]
	var unlocked_offer := shop.offers[1]
	GameState.nursery.reroll_unlocked_shop_offers()
	_expect(shop.offers[0] == locked_offer and shop.is_locked(0), "A locked full-Shop offer survives reroll")
	_expect(shop.offers[1] != unlocked_offer, "An unlocked full-Shop offer is rerolled")
	var final_offers := shop.offers.duplicate()
	GameState.ensure_guided_preparation()
	GameState.nursery.ensure_shop_offers()
	_expect(shop.offers == final_offers, "Ensuring final-Day preparation never rerolls the full Shop")


func _test_first_full_shop_quick_growth() -> void:
	for draw_seed in range(16):
		_prepare_day(7)
		var shop := GameState.nursery.spore_shop
		if draw_seed % 2 == 0:
			var intro_offer: ShopOffer = shop.offers[0]
			_expect(GameState.try_buy_fertilizer(intro_offer.item as FertilizerData, intro_offer.cost), "Introductory Quick Growth can be bought before the full Shop")
			GameState.nursery.replace_shop_slot(0)
		seed(draw_seed)
		GameState.debug_advance_day()
		var quick_growth_count := 0
		for slot in NurseryData.SHOP_FERTILIZER_SLOT_COUNT:
			if shop.offers[slot].item == GuidedRun.QUICK_GROWTH:
				quick_growth_count += 1
		_expect(quick_growth_count == 1, "First full draw includes exactly one Quick Growth for seed %d" % draw_seed)
		var first_draw := shop.offers.duplicate()
		GameState.nursery.ensure_shop_offers()
		GameState.ensure_guided_preparation()
		_expect(shop.offers == first_draw, "Base refresh keeps the scripted first draw")
		if draw_seed % 2 == 0:
			GameState.nursery.reroll_unlocked_shop_offers()
		else:
			GameState.debug_advance_day()
		for slot in NurseryData.SHOP_FERTILIZER_SLOT_COUNT:
			_expect(shop.offers[slot].item != GuidedRun.QUICK_GROWTH, "Later normal draws exclude the previous Quick Growth instead of scripting it again")


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
		_expect((GameState.nursery.plots[0] as NurseryPlotData).remaining_days() == 2, "Retry undoes grow tick")
		_expect(BattleLaunch.enemy_roster[0].stats.strength == enemy_strength, "Retry preserves exact enemy roll")
	_expect(GameState.restore_guided_preparation(), "Change preparation restores checkpoint")
	_expect(GameState.biomass.amount == starting_biomass, "Change preparation refunds that Day's spending")
	_expect(GameState.troop.squad[1] == child and not child.is_adult_stage(), "Change preparation restores untrained Child")
	_expect((GameState.nursery.plots[0] as NurseryPlotData).is_empty(), "Change preparation removes that Day's grow")
	_expect(GameState.make_upcoming_enemy_roster()[0].stats.strength == enemy_strength, "Change preparation keeps enemy roll")
	_expect(not GameState.has_guided_battle_checkpoint(), "New preparation invalidates old battle checkpoint")


func _test_compost_and_lineage_restore() -> void:
	_prepare_day(7)
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
	_prepare_day(8)
	var offers := GameState.ensure_seal_choice_offers().duplicate()
	_expect(offers == GuidedRun.SEALS and offers.size() == 3, "First Seal choice retains the three introductory offers")
	_expect(not GameState.try_add_seal(SealCatalog.by_id(&"greenhouse")), "Introductory choice rejects an unoffered Seal")
	GameState.ensure_guided_preparation_checkpoint()
	_expect(GameState.try_add_seal(offers[0]), "Introductory Seal can be chosen")
	GameState.clear_pending_seal_choice()
	GameState.capture_guided_battle_checkpoint(GameState.make_upcoming_enemy_roster())
	_expect(GameState.restart_guided_battle() and GameState.seals.owned.size() == 1, "Battle retry retains chosen Seal once")
	_expect(GameState.should_show_player_flag_bearer(), "Battle retry retains the revealed flag bearer")
	_expect(GameState.restore_guided_preparation(), "Seal preparation can be restored")
	_expect(GameState.pending_seal_choice and GameState.seals.owned.is_empty(), "Preparation restores pending choice without bonus")
	_expect(not GameState.should_show_player_flag_bearer(), "Restoring the pending first Seal hides the flag bearer")
	_expect(GameState.ensure_seal_choice_offers() == offers, "Preparation keeps same Seal offers")
	GameState.try_add_seal(offers[0])
	GameState.clear_pending_seal_choice()
	for day in range(9, 12):
		GameState.debug_advance_day()
		_expect(not GameState.pending_seal_choice and GameState.seals.owned.size() == 1, "Day %d never grants another Seal" % day)
	_expect(not GameState.try_add_seal(offers[0]), "An already accepted offer cannot be chosen again without a pending reward")


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
	GameState.current_day = 10
	GameState.finish_run(true)
	_expect(not SettingsServer.guided_run_enabled, "Guided completion unchecks next Run after an earlier end")
	_expect(SettingsServer.guided_run_completed, "Accepted final victory records completion")
	SettingsServer.set_guided_run_enabled(true)
	GameState.reset_run(true)
	GameState.current_day = 10
	GameState.finish_run(true)
	_expect(not SettingsServer.guided_run_enabled, "Completing a guided replay also unchecks next Run")
	SettingsServer.set_guided_run_enabled(true)
	GameState.finish_run(true)
	_expect(SettingsServer.guided_run_enabled, "Repeated completion notification preserves a new menu choice")
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
