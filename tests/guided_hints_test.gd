extends Node

## Public arrow opportunities; no scene interaction or tutorial action is required.
## Run: godot --headless --path . res://tests/guided_hints_test.tscn
var _failures := 0
var _checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	Analytics.ga = null
	_test_opening_opportunities()
	_test_day_three_training_completion()
	_test_day_four_actions()
	_test_nursery_opportunities()
	_test_later_unlocks()
	_test_final_unlocks()
	_test_lineage_prerequisites()
	_test_mode_and_history()
	print("Guided hint checks: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_opening_opportunities() -> void:
	_prepare_day(1)
	_expect(_hint_id() == "battle", "Day 1 points to Battle with the fixed troop ready")
	GameState.debug_advance_day()
	var bow := GuidedRunHints.next_hint()
	var child: RosterUnitData = GameState.troop.squad[1]
	_expect(str(bow.get("id")) == "training_%d" % WeaponSchool.Id.BOW, "Day 2 introduces Bow")
	_expect(bow.get("source", {}).get("unit") == child, "Bow source is the actual available Child")
	_expect(GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.BOW), "Suggested Bow Training can be performed")
	_expect(GuidedRunHints.next_hint().is_empty(), "Training already in progress is not suggested again")
	GameState.debug_advance_day()
	GameState.biomass.add(10)
	_seen(GuidedRunHints.next_hint())
	_expect(GuidedRunHints.next_hint().is_empty(), "A ranged Unit ahead of melee does not create a recurring Formation arrow")
	_prepare_day(2)
	_spend_all()
	_expect(GuidedRunHints.next_hint().is_empty(), "Unaffordable Training is skipped without a Battle fallback")
	_prepare_day(3)
	var sword := GuidedRunHints.next_hint()
	_expect(str(sword.get("id")) == "training_%d" % WeaponSchool.Id.SWORD, "Day 3 introduces Sword")
	_seen(sword)
	_expect(GuidedRunHints.next_hint().is_empty(), "Missing Day-2 Bow Training does not bring its arrow back on Day 3")
	_prepare_day(4)
	var progression := GuidedRunHints.next_hint()
	_expect(progression.get("target") == &"progression" and progression.get("action_required", false), "Day 4 progression stays until the elite is activated")
	_seen(progression)
	var early_mace := GuidedRunHints.next_hint()
	_expect(str(early_mace.get("id")) == "training_%d" % WeaponSchool.Id.MACE, "Day 4 offers Mace after progression inspection")
	_expect(early_mace.get("target") == &"school" and early_mace.get("school") == WeaponSchool.Id.MACE and not early_mace.has("source"), "Day 4 points directly to the Mace cocoon")
	_seen(early_mace)
	_expect(GuidedRunHints.next_hint().is_empty(), "Viewed Day-4 unlocks finish without requiring an action")
	_prepare_day(6)
	_expect(_hint_id() == "mutation", "Day 6 introduces Thorny without repeating skipped Mace guidance")


func _test_day_three_training_completion() -> void:
	_prepare_day(2)
	var child: RosterUnitData = GameState.troop.squad[1]
	_expect(GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.BOW), "Day-2 Training prepares the second Adult")
	GameState.debug_advance_day()
	GameState.biomass.add(40)
	GameState.ensure_guided_preparation_checkpoint()
	var adult: RosterUnitData = GameState.troop.squad[0]
	_expect(not GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.MACE), "A locked school rejects Training")
	_expect(GameState.try_cocoon_for_pupation(adult, WeaponSchool.Id.SWORD), "First Day-3 Unit can train")
	_expect(_hint_id() == "training_%d" % WeaponSchool.Id.SWORD, "Earlier Training and failed attempts do not dismiss Day-3 guidance")
	_expect(GameState.try_cocoon_for_pupation(adult, WeaponSchool.Id.BOW), "The same Adult can train again")
	_expect(not GuidedRunHints.next_hint().is_empty(), "Retraining one Unit does not count as two Units")
	_expect(GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.SWORD), "Second distinct Day-3 Unit can train")
	_expect(GuidedRunHints.next_hint().is_empty(), "Training two Units dismisses Day-3 arrows")
	_expect(GameState.restore_guided_preparation(), "Day-3 preparation can be restored")
	_expect(GuidedRunHints.next_hint().is_empty(), "Restoring preparation keeps learned Day-3 guidance dismissed")
	GameState.debug_advance_day()
	_expect(_hint_id() == "progression", "Day-4 unlock guidance still appears")
	_prepare_day(3)
	_expect(_hint_id() == "training_%d" % WeaponSchool.Id.SWORD, "A new Run resets Day-3 Training completion")


func _test_day_four_actions() -> void:
	_prepare_day(4)
	GameState.ensure_guided_preparation_checkpoint()
	GuidedRunHints.record_day_inspected(4)
	_expect(_hint_id() == "progression", "Inspecting a non-elite Day does not dismiss the elite arrow")
	GuidedRunHints.record_day_inspected(5)
	var mace := GuidedRunHints.next_hint()
	_expect(str(mace.get("id")) == "training_%d" % WeaponSchool.Id.MACE and mace.get("action_required", false), "Elite activation advances to Mace guidance until Training")
	var unit: RosterUnitData = GameState.troop.squad[0]
	_expect(GameState.try_cocoon_for_pupation(unit, WeaponSchool.Id.SWORD), "Other Training remains optional and available")
	_expect(_hint_id() == "training_%d" % WeaponSchool.Id.MACE, "Sword Training does not dismiss Mace guidance")
	_spend_all()
	_expect(not GameState.try_cocoon_for_pupation(unit, WeaponSchool.Id.MACE), "Unaffordable Mace Training fails")
	GameState.biomass.add(40)
	_expect(_hint_id() == "training_%d" % WeaponSchool.Id.MACE, "Failed Mace Training does not complete its guidance")
	_expect(GameState.try_cocoon_for_pupation(unit, WeaponSchool.Id.MACE), "One Unit successfully trains with Mace")
	_expect(GuidedRunHints.next_hint().is_empty(), "One Mace Training dismisses Day-4 guidance")
	_expect(GameState.restore_guided_preparation() and GuidedRunHints.next_hint().is_empty(), "Retrying preparation preserves both Day-4 dismissals")
	_prepare_day(4)
	unit = GameState.troop.squad[0]
	_expect(GameState.try_cocoon_for_pupation(unit, WeaponSchool.Id.MACE), "Mace Training can happen before inspecting the elite")
	_expect(_hint_id() == "progression", "Early Mace Training still leaves the elite introduction available")
	GuidedRunHints.record_day_inspected(5)
	_expect(GuidedRunHints.next_hint().is_empty(), "Elite activation does not repeat an already completed Mace introduction")


func _test_nursery_opportunities() -> void:
	_prepare_day(5)
	var plant := GuidedRunHints.next_hint()
	_expect(plant.get("target") == &"plot" and plant.get("tab") == &"nursery", "New Nursery points to an available Plot")
	_expect(str(plant.get("id")) == "plant", "Empty Nursery offers the first fresh planting")
	_spend_all()
	_expect(GuidedRunHints.next_hint().is_empty(), "No fresh planting suggestion when its fee is unaffordable")
	GameState.biomass.add(40)
	_expect(GameState.try_plant_fresh_common(0), "First fresh grow can be planted")
	_expect(_hint_id() == "quick_growth", "Day 5 introduces Quick Growth after planting")
	_expect(GameState.nursery.plots[0].remaining_days() == 2, "The first grow makes Quick Growth useful")
	_seen(GuidedRunHints.next_hint())
	_expect(GuidedRunHints.next_hint().is_empty(), "Viewed Nursery-Day opportunities add no recurring prompts")

	_prepare_day(6)
	var mutation := GuidedRunHints.next_hint()
	_expect(str(mutation.get("id")) == "mutation", "Day 6 introduces Thorny")
	_expect(mutation.get("source", {}).get("target") == &"shop", "An unowned mutation points to its real Shop offer")
	var snapshot := BaseUndoSnapshot.new()
	snapshot.capture()
	var history_before := GameState.guided_hint_history.duplicate(true)
	for attempt in 3:
		GuidedRunHints.next_hint()
	_expect(snapshot.matches_current_state() and GameState.guided_hint_history == history_before, "Selecting arrows leaves resources, Plot, troop, offers and history unchanged")
	_spend_all()
	_expect(GuidedRunHints.next_hint().is_empty(), "Unaffordable Mutation is not suggested")
	GameState.biomass.add(GuidedRun.THORNY.biomass_cost)
	_expect(GameState.try_buy_mutation(GuidedRun.THORNY, GuidedRun.THORNY.biomass_cost), "Thorny can be acquired normally")
	_spend_all()
	mutation = GuidedRunHints.next_hint()
	var source: Dictionary = mutation.get("source", {})
	var stock_index := int(source.get("stock_index", -1))
	_expect(str(mutation.get("id")) == "mutation" and source.get("target") == &"stock", "Owned Thorny is suggested even when another purchase is unaffordable")
	_expect(stock_index >= 0 and GameState.nursery.stock.get_at(stock_index) == GuidedRun.THORNY, "Mutation source identifies the owned Stock item")
	_expect(GameState.nursery.apply_mutation_from_stock(0, stock_index), "Suggested owned mutation can be applied")
	_expect(GuidedRunHints.next_hint().is_empty(), "Already-applied mutation is not suggested again")


func _test_later_unlocks() -> void:
	_prepare_day(6)
	_expect(GameState.try_plant_fresh_common(0), "Plant the introductory grow")
	_expect(GameState.try_buy_fertilizer(GuidedRun.QUICK_GROWTH, GuidedRun.QUICK_GROWTH.biomass_cost), "Buy Quick Growth for a Day-7 harvest")
	_expect(GameState.nursery.apply_fertilizer_from_stock(0, 0), "Apply Quick Growth")
	GameState.debug_advance_day()
	_expect(_hint_id() == "compost", "Day 7 introduces Compost without pointing Shield at a starter Unit")
	_expect(not GuidedRunHints.next_hint().has("source"), "Before a harvest, Day 7 points directly at Compost without a Unit arrow")
	var before_harvest := BaseUndoSnapshot.new()
	before_harvest.capture()
	var harvested := GameState.nursery.harvest(0)
	_expect(harvested.size() == 1, "First grow produces a new Unit")
	_expect(_hint_id() == "compost", "Harvested Unit outside the Troop cannot receive Shield guidance")
	GameState.troop.try_add_unit(harvested[0])
	var shield := GuidedRunHints.next_hint()
	_expect(str(shield.get("id")) == "training_%d" % WeaponSchool.Id.SHIELD, "Day 7 introduces Shield for the newly harvested Unit")
	_expect(shield.get("source", {}).get("unit") == harvested[0], "Shield guidance starts at the newly harvested Unit")
	_expect(GameState.can_cocoon_for_pupation(shield.get("source", {}).get("unit"), WeaponSchool.Id.SHIELD), "Shield source is eligible for that school")
	before_harvest.restore()
	_expect(_hint_id() == "compost", "Undoing Harvest never redirects Shield guidance to an older Unit")
	harvested = GameState.nursery.harvest(0)
	GameState.troop.try_add_unit(harvested[0])
	_expect(GuidedRunHints.next_hint().get("source", {}).get("unit") == harvested[0], "Harvesting again points to the replacement Unit")
	GameState.troop.remove_unit(harvested[0])
	_expect(_hint_id() == "compost", "Losing the new Unit does not fall back to a starter")
	GameState.troop.try_add_unit(harvested[0])
	var before_hover := BaseUndoSnapshot.new()
	before_hover.capture()
	GuidedRunHints.record_shield_hover()
	_expect(before_hover.matches_current_state(), "Shield hover changes no gameplay state")
	_expect(_hint_id() == "compost", "Viewing Shield advances to the newly unlocked Compost")
	GuidedRunHints.record_compost_hover()
	_expect(GuidedRunHints.next_hint().is_empty(), "Viewed Day-7 unlocks leave no recurring Battle or Nursery hint")
	_prepare_day(6)
	while GameState.troop.first_empty_unlocked_squad() >= 0:
		GameState.troop.try_add_unit(GuidedRun.make_starter(false))
	GameState.troop.try_add_unit(GuidedRun.make_starter(false))
	_expect(_hint_id() == "squad_slot", "Day 6 introduces Squad expansion when another Unit needs room")
	_seen(GuidedRunHints.next_hint())
	_expect(_hint_id() == "mutation", "Viewed Squad expansion leaves the new Thorny introduction")
	_prepare_day(8)
	_expect(GameState.try_plant_fresh_common(0), "The existing Plot can be occupied")
	var capacity := GuidedRunHints.next_hint()
	_expect(str(capacity.get("id")) == "plot_slot" and capacity.get("tab") == &"nursery", "An occupied Nursery offers Plot expansion on Day 8")
	_spend_all()
	_expect(GuidedRunHints.next_hint().is_empty(), "Unaffordable Plot expansion is skipped")
	GameState.biomass.add(GameState.nursery.next_unlock_cost())
	_expect(_hint_id() == "plot_slot", "Plot expansion is suggested again when affordable")
	_expect(GameState.try_unlock_plot(), "The suggested Plot can be unlocked normally")
	_expect(GuidedRunHints.next_hint().is_empty(), "Buying the second Plot finishes the available Day-8 guidance")
	_prepare_day(9)
	var spear := GuidedRunHints.next_hint()
	_expect(str(spear.get("id")) == "training_%d" % WeaponSchool.Id.SPEAR, "Day 9 introduces Spear")
	_expect(spear.get("target") == &"school" and spear.get("school") == WeaponSchool.Id.SPEAR and not spear.has("source"), "Day 9 points directly to the Spear cocoon without a Unit arrow")
	before_hover = BaseUndoSnapshot.new()
	before_hover.capture()
	GuidedRunHints.record_spear_hover()
	_expect(before_hover.matches_current_state(), "Spear hover changes no gameplay state")
	_expect(GuidedRunHints.next_hint().is_empty(), "Viewed Spear leaves no repeated Shop guidance on Day 9")


func _test_final_unlocks() -> void:
	_prepare_day(8, false)
	var seal := GuidedRunHints.next_hint()
	_expect(str(seal.get("id")) == "seal" and seal.get("target") == &"battle", "Day 8 introduces the only Seal before other opportunities")
	_seen(seal)
	_expect(GuidedRunHints.next_hint().is_empty() and GameState.pending_seal_choice, "Viewing the Seal arrow does not resolve the required choice")
	_choose_seal()
	_expect(_hint_id() in ["full_shop", "shop_reroll"], "Confirming the Day-8 Seal leaves new Shop guidance without repeating Compost")
	_prepare_day(10)
	_expect(GuidedRunHints.next_hint().is_empty(), "Day 10 does not repeat the full-Shop introduction")
	_prepare_day(8)
	var fertilizer := load("res://assets/base/nursery/fertilizers/reinforced_chitin.tres") as FertilizerData
	var shop := GameState.nursery.spore_shop
	shop.offers.fill(null)
	var offer := ShopOffer.new()
	offer.item = fertilizer
	offer.cost = fertilizer.biomass_cost
	shop.offers[1] = offer
	var item := GuidedRunHints.next_hint()
	_expect(str(item.get("id")) == "full_shop" and item.get("source", {}).get("shop_index") == 1, "Day 8 full Shop points to an available compatible item")
	_expect(item.get("target") == &"plot" and item.get("plot_action") == &"apply", "Full Shop points from its item to a compatible Plot")
	var snapshot := BaseUndoSnapshot.new()
	snapshot.capture()
	GuidedRunHints.next_hint()
	_expect(snapshot.matches_current_state(), "Full-Shop selection leaves gameplay unchanged")
	_spend_all()
	_expect(GuidedRunHints.next_hint().is_empty(), "Unaffordable full-Shop purchase and reroll are skipped")
	GameState.biomass.add(offer.cost)
	_expect(GameState.try_buy_fertilizer(fertilizer, offer.cost), "The full-Shop Fertilizer can be bought")
	shop.replace_slot(1)
	var owned := GuidedRunHints.next_hint()
	var stock_index := int(owned.get("source", {}).get("stock_index", -1))
	_expect(str(owned.get("id")) == "full_shop" and owned.get("source", {}).get("target") == &"stock", "A bought item follows its Stock location even at zero biomass")
	_expect(GameState.nursery.apply_fertilizer_from_stock(0, stock_index), "The suggested owned item applies to its Plot")
	_expect(GuidedRunHints.next_hint().is_empty(), "A consumed full-Shop item is no longer suggested")
	GameState.biomass.add(GameState.nursery.current_shop_reroll_cost())
	_expect(_hint_id() == "shop_reroll", "Day 8 can introduce an affordable reroll for empty Shop slots")
	for index in shop.offers.size():
		var locked := ShopOffer.new()
		locked.item = GuidedRun.THORNY
		locked.cost = GuidedRun.THORNY.biomass_cost
		locked.locked = true
		shop.offers[index] = locked
	_expect(_hint_id() != "shop_reroll", "Reroll is not suggested when every offer is locked")
	GameState.debug_advance_day()
	_seen(GuidedRunHints.next_hint()) # Spear introduction.
	_expect(GuidedRunHints.next_hint().is_empty(), "Day 9 does not repeat the full-Shop introduction")
	GameState.debug_advance_day()
	_expect(GuidedRunHints.next_hint().is_empty(), "Day 10 adds no new Shop guidance")
	GameState.debug_advance_day()
	_expect(GameState.has_won_run() and GuidedRunHints.next_hint().is_empty(), "Completion after Battle 10 suppresses all further arrows")


func _test_lineage_prerequisites() -> void:
	_prepare_day(5)
	var fallen_parent: RosterUnitData = GameState.troop.squad[0]
	GameState.nursery.add_death_spore(fallen_parent)
	GameState.troop.remove_unit(fallen_parent)
	_spend_all()
	var lineage := GuidedRunHints.next_hint()
	var stock_index := int(lineage.get("source", {}).get("stock_index", -1))
	var spore := GameState.nursery.stock.get_at(stock_index) as SporeData
	_expect(str(lineage.get("id")) == "lineage" and spore != null and spore.is_lineage_spore(), "New Nursery can point to an actual Adult's lineage Spore in Stock")
	_expect(GameState.nursery.plant(0, stock_index), "Suggested lineage planting remains free at zero biomass")
	_expect(GuidedRunHints.next_hint().is_empty(), "Consumed lineage Spore is no longer suggested")

	_prepare_day(7)
	var compost := GuidedRunHints.next_hint()
	var parent: RosterUnitData = GameState.troop.squad[0]
	_expect(str(compost.get("id")) == "compost" and compost.get("target") == &"compost" and not compost.has("source"), "Day 7 points directly at Compost without a Unit arrow")
	GameState.ensure_guided_preparation_checkpoint()
	var before_hover := BaseUndoSnapshot.new()
	before_hover.capture()
	GuidedRunHints.record_compost_hover()
	_expect(_hint_id() != "compost", "Hovering Compost dismisses its guidance without composting")
	_expect(before_hover.matches_current_state(), "Compost hover changes no gameplay state")
	_expect(GameState.restore_guided_preparation() and GuidedRunHints.next_hint().is_empty(), "Day-7 preparation restoration preserves the Compost hover dismissal")
	_expect(GameState.try_compost_unit(parent), "Player can still choose an Adult to compost")
	_expect(GameState.nursery.has_spore_in_stock(), "Compost still produces its real lineage Spore")
	_expect(GuidedRunHints.next_hint().is_empty(), "Compost does not add a repeated planting or Unit arrow")
	GameState.debug_advance_day()
	_choose_seal()
	_expect(_hint_id() != "compost", "Day 8 never repeats the previous Day's Compost introduction")


func _test_mode_and_history() -> void:
	GameState.reset_run(false)
	_expect(GuidedRunHints.next_hint().is_empty(), "Ordinary Runs receive no guided arrows")
	_prepare_day(2)
	GameState.debug_mode_active = true
	_expect(GuidedRunHints.next_hint().is_empty(), "Debug mode receives no guided arrows")
	GameState.debug_mode_active = false
	GameState.ensure_guided_preparation_checkpoint()
	GameState.capture_guided_battle_checkpoint(GameState.make_upcoming_enemy_roster())
	var hint := GuidedRunHints.next_hint()
	_seen(hint)
	var viewed := GameState.guided_hint_history.duplicate(true)
	_expect(GameState.restart_guided_battle(), "Battle snapshot can be restarted")
	_expect(GameState.guided_hint_history == viewed and GuidedRunHints.next_hint().is_empty(), "Restart preserves viewed arrows without adding Battle guidance")
	_expect(GameState.restore_guided_preparation(), "Preparation snapshot can be restored")
	_expect(GameState.guided_hint_history == viewed, "Changing preparation preserves arrow presentation history")
	GameState.reset_run(true)
	_expect(GameState.guided_hint_history.is_empty() and _hint_id() == "battle", "A new Run resets arrow history")
	_prepare_day(11)
	_expect(GuidedRunHints.next_hint().is_empty(), "Completed guided Runs receive no further arrows")


func _prepare_day(day: int, choose_seals: bool = true) -> void:
	GameState.reset_run(true)
	while GameState.get_upcoming_day() < day:
		GameState.debug_advance_day()
		if choose_seals:
			_choose_seal()
	GameState.biomass.add(40)


func _choose_seal() -> void:
	if not GameState.pending_seal_choice:
		return
	GameState.ensure_seal_choice_offers()
	_expect(GameState.try_add_seal(GameState.seal_choice_offers[0]), "Pending Seal can be selected")
	GameState.clear_pending_seal_choice()


func _spend_all() -> void:
	GameState.biomass.try_spend(GameState.biomass.amount)


func _hint_id() -> String:
	return str(GuidedRunHints.next_hint().get("id", ""))


func _seen(hint: Dictionary) -> void:
	GameState.guided_hint_history[GuidedRunHints.history_key(hint)] = true


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
