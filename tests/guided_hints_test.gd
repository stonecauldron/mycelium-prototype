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
	_test_nursery_opportunities()
	_test_later_unlocks()
	_test_cutoff()
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
	_expect(progression.get("target") == &"progression" and progression.get("passive", false), "Day 4 presents passive progression inspection")
	_seen(progression)
	var early_mace := GuidedRunHints.next_hint()
	_expect(str(early_mace.get("id")) == "training_%d" % WeaponSchool.Id.MACE, "Day 4 offers Mace after progression inspection")
	_expect(GameState.can_cocoon_for_pupation(early_mace.get("source", {}).get("unit"), WeaponSchool.Id.MACE), "Day 4 Mace points to an eligible unit")
	_seen(early_mace)
	_expect(GuidedRunHints.next_hint().is_empty(), "Viewed Day-4 unlocks finish without requiring an action")
	_prepare_day(5)
	_expect(GuidedRunHints.next_hint().is_empty(), "Day 5 stays quiet even when Mace Training was skipped")
	_prepare_day(10)
	_expect(GuidedRunHints.next_hint().is_empty(), "Day 10 adds no elite Scout or recurring Nursery arrow")


func _test_nursery_opportunities() -> void:
	_prepare_day(6)
	var plant := GuidedRunHints.next_hint()
	_expect(plant.get("target") == &"plot" and plant.get("tab") == &"nursery", "New Nursery points to an available Plot")
	_expect(str(plant.get("id")) == "plant", "Empty Nursery offers the first fresh planting")
	_spend_all()
	_expect(GuidedRunHints.next_hint().is_empty(), "No fresh planting suggestion when its fee is unaffordable")
	GameState.biomass.add(40)
	_expect(GameState.try_plant_fresh_common(0), "First fresh grow can be planted")
	GameState.debug_advance_day()
	_expect(GuidedRunHints.next_hint().is_empty(), "Day 7 does not repeat Nursery arrows or offer Quick Growth to a ready grow")
	for unit in GameState.nursery.harvest(0):
		_expect(not GameState.troop.try_add_unit(unit).is_empty(), "Harvested Child enters the troop")
	_expect(GameState.try_plant_fresh_common(0), "Next grow is planted through normal gameplay")
	GameState.guided_hint_history.clear()
	_expect(_hint_id() == "quick_growth", "Quick Growth is suggested for an actual growing Plot")

	_prepare_day(8)
	var mutation := GuidedRunHints.next_hint()
	_expect(str(mutation.get("id")) == "mutation", "Day 8 introduces Thorny")
	_expect(mutation.get("source", {}).get("target") == &"shop", "An unowned mutation points to its real Shop offer")
	var snapshot := BaseUndoSnapshot.new()
	snapshot.capture()
	var history_before := GameState.guided_hint_history.duplicate(true)
	for attempt in 3:
		GuidedRunHints.next_hint()
	_expect(snapshot.matches_current_state() and GameState.guided_hint_history == history_before, "Selecting arrows leaves resources, Plot, troop, offers and history unchanged")
	_spend_all()
	_expect(GuidedRunHints.next_hint().is_empty(), "Unaffordable Shop item and Shield Training are not suggested")
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
	_prepare_day(8)
	_seen(GuidedRunHints.next_hint())
	var shield := GuidedRunHints.next_hint()
	_expect(str(shield.get("id")) == "training_%d" % WeaponSchool.Id.SHIELD, "Day 8 introduces Shield after the Mutation opportunity")
	_expect(GameState.can_cocoon_for_pupation(shield.get("source", {}).get("unit"), WeaponSchool.Id.SHIELD), "Shield source is eligible for that school")
	_seen(shield)
	_expect(GuidedRunHints.next_hint().is_empty(), "Viewed Day-8 unlocks leave no recurring Battle or Nursery hint")
	_prepare_day(9)
	while GameState.troop.first_empty_unlocked_squad() >= 0:
		GameState.troop.try_add_unit(GuidedRun.make_starter(false))
	_expect(GameState.troop.try_add_unit(GuidedRun.make_starter(false)) == "bench", "Capacity fixture has a real Unit waiting on the Bench")
	_expect(GameState.try_plant_fresh_common(0), "The existing Plot can be occupied")
	_expect(_hint_id() == "squad_slot", "Day 9 introduces Squad expansion when another Unit needs room")
	_seen(GuidedRunHints.next_hint())
	var capacity := GuidedRunHints.next_hint()
	_expect(str(capacity.get("id")) == "plot_slot" and capacity.get("tab") == &"nursery", "An occupied Nursery offers affordable Plot expansion on Day 9")
	_spend_all()
	_expect(GuidedRunHints.next_hint().is_empty(), "Unaffordable Plot expansion is skipped")
	GameState.biomass.add(GameState.nursery.next_unlock_cost())
	_expect(_hint_id() == "plot_slot", "Plot expansion is suggested again when affordable")
	_expect(GameState.try_unlock_plot(), "The suggested Plot can be unlocked normally")
	_expect(_hint_id() != "plot_slot", "An available empty Plot suppresses more capacity hints")


func _test_cutoff() -> void:
	for day in [12, 13, 14, 15]:
		_prepare_day(day, false)
		_expect(GameState.pending_seal_choice, "Cutoff fixture retains a pending Seal on Day %d" % day)
		_expect(GuidedRunHints.next_hint().is_empty(), "Pending Seal cannot bypass the Day-%d arrow cutoff" % day)
		_choose_seal()
		_expect(GuidedRunHints.next_hint().is_empty(), "Full Shop and late school unlocks show no arrows on Day %d" % day)
		var squad := GameState.troop.get_squad_roster()
		for index in squad.size():
			GameState.troop.remove_unit(squad[index])
			GameState.troop.bench[index] = squad[index]
		_expect(GameState.troop.squad_unit_count() == 0 and GameState.troop.living_unit_count() > 0, "Cutoff fixture has an empty Squad with available Bench units")
		_expect(GuidedRunHints.next_hint().is_empty(), "Empty Squad cannot bypass the Day-%d arrow cutoff" % day)


func _test_lineage_prerequisites() -> void:
	_prepare_day(6)
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

	_prepare_day(11, false)
	var seal := GuidedRunHints.next_hint()
	_expect(str(seal.get("id")) == "seal" and seal.get("target") == &"battle", "Pending Seal points to the Battle/Select Seal control")
	_seen(seal)
	_expect(GuidedRunHints.next_hint().is_empty() and GameState.pending_seal_choice, "Viewing a Seal arrow does not resolve the required choice")
	_choose_seal()
	var compost := GuidedRunHints.next_hint()
	var parent := compost.get("source", {}).get("unit") as RosterUnitData
	_expect(str(compost.get("id")) == "compost" and parent != null and parent.is_adult_stage(), "Day 11 offers a real removable Adult for Compost")
	_expect(GameState.try_compost_unit(parent), "Suggested Adult can actually be composted")
	_expect(GameState.nursery.has_spore_in_stock(), "Compost still produces its real lineage Spore")
	_expect(GuidedRunHints.next_hint().is_empty(), "Day 11 Compost does not reintroduce an earlier Nursery planting arrow")
	GameState.debug_advance_day()
	_expect(GuidedRunHints.next_hint().is_empty(), "Day 12 stays quiet with an unplanted lineage Spore available")


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
	_prepare_day(16)
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
