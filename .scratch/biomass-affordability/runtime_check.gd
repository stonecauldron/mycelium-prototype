extends Node

var _failures: int = 0
var _base: Node2D
var _screen: NurseryScreen
var _scout: ScoutBubble
var _training: PupationConfirmDialog
var _seals: SealChoiceDialog
var _balance_changes: int = 0


func _ready() -> void:
	get_tree().create_timer(15.0).timeout.connect(func() -> void: get_tree().quit(2))
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		_failures += 1


func _run() -> void:
	GameState.reset_run()
	GameState.pending_seal_choice = false
	GameState.troop.seed_if_empty(StarterPackages.build_units(StarterPackages.PACKAGE_IDS[0]))
	GameState.current_day = 1
	seed(12345)
	_base = preload("res://assets/base/base.tscn").instantiate()
	get_tree().root.add_child(_base)
	get_tree().current_scene = _base
	_screen = _base.get_node("%NurseryScreen")
	_scout = _base.get_node("%ColonyScreen").get_node("%ScoutBubble")
	var plant: Button = _screen._tiles[0].get_node("%PlantButton")
	var card: ShopOfferCard = _screen._shop_cards[0]
	GameState.biomass.amount = SealModifiers.fresh_plant_cost() + card.cost - 1
	_screen._refresh()
	_check(not plant.disabled, "Plant enabled before shop purchase")
	_screen._on_shop_offer_clicked(card)
	_check(not GameState.biomass.can_afford(SealModifiers.fresh_plant_cost()), "Shop purchase crosses Plant affordability threshold")
	_check(plant.disabled, "Plant disabled after shop purchase")
	GameState.biomass.amount = SealModifiers.fresh_plant_cost()
	_screen._refresh()
	_check(not plant.disabled, "Plant enabled before shop reroll")
	_screen._on_reroll_pressed()
	_check(not GameState.biomass.can_afford(SealModifiers.fresh_plant_cost()), "Shop reroll crosses Plant affordability threshold")
	_check(plant.disabled, "Plant disabled after shop reroll")
	GameState.biomass.add(20)
	_check(not plant.disabled, "Plant enabled when biomass increases")
	GameState.biomass.try_spend(GameState.biomass.amount)
	_check(plant.disabled, "Plant disabled when biomass is spent elsewhere")
	_training = preload("res://assets/base/pupation/pupation_confirm_dialog.tscn").instantiate()
	_training.setup(GameState.troop.squad[0], WeaponSchool.Id.SWORD)
	add_child(_training)
	_seals = preload("res://assets/base/seals/seal_choice_dialog.tscn").instantiate()
	add_child(_seals)
	GameState.biomass.add(30)
	_check_affordability("gain")
	GameState.biomass.try_spend(29)
	_check_affordability("spend")
	GameState.biomass.add(29)
	_check_affordability("refund")
	GameState.biomass.amount = 0
	_check_affordability("direct assignment")
	GameState.biomass.reset()
	_check_affordability("reset")
	_check_edge_cases()
	GameState.biomass.changed.connect(_on_balance_changed)
	GameState.biomass.amount = 0
	_balance_changes = 0
	_check(not GameState.biomass.try_spend(1), "Unaffordable spend rejected")
	GameState.biomass.try_spend(0)
	GameState.biomass.add(0)
	GameState.biomass.amount = 0
	_check(_balance_changes == 0, "Failed spends and unchanged balances do not emit changes")
	GameState.biomass.add(1)
	GameState.biomass.try_spend(1)
	GameState.biomass.reset()
	_check(_balance_changes == 3, "Gain, spend and reset each emit one change")
	_base.queue_free()
	_training.queue_free()
	_seals.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("BIOMASS AFFORDABILITY CHECK: ", _failures, " failures")
	get_tree().quit(1 if _failures else 0)


func _on_balance_changed() -> void:
	_balance_changes += 1


func _check_edge_cases() -> void:
	var shop_cost := GameState.nursery.current_shop_reroll_cost()
	GameState.biomass.amount = shop_cost * 2
	_screen._on_reroll_pressed()
	_check(GameState.nursery.current_shop_reroll_cost() == shop_cost + 1, "Shop reroll increases price")
	_check_affordability("shop reroll")
	var scout_cost := GameState.current_scout_reroll_cost()
	GameState.biomass.amount = scout_cost * 2
	_scout._on_scout_reroll_pressed()
	_check(GameState.current_scout_reroll_cost() == scout_cost + 1, "Scout reroll increases price")
	_check_affordability("Scout reroll")
	var seal_cost := _seals._current_seal_reroll_cost()
	GameState.biomass.amount = seal_cost * 2
	_seals._on_reroll_pressed()
	_check(_seals._current_seal_reroll_cost() == seal_cost + 1, "Seal reroll increases price")
	_check_affordability("Seal reroll")
	var stock_before := GameState.nursery.stock.get_at(0)
	var shop_card_before := _screen._shop_cards[0]
	GameState.biomass.add(1)
	_check(GameState.nursery.stock.get_at(0) == stock_before and _screen._shop_cards[0] == shop_card_before, "Balance-only refresh preserves inventory and shop cards")
	_scout.preview_elite_for_day(5)
	GameState.biomass.add(100)
	_check(not _scout._scout_reroll_button.visible and _scout._scout_reroll_button.disabled, "Elite preview keeps Scout reroll unavailable after gain")
	_scout.clear_preview()
	GameState.current_day = 4
	_scout.refresh()
	GameState.biomass.add(1)
	_check(not _scout._scout_reroll_button.visible and _scout._scout_reroll_button.disabled, "Elite day keeps Scout reroll unavailable after gain")
	GameState.current_day = 1
	_scout.refresh()
	var opening_seals: SealChoiceDialog = preload("res://assets/base/seals/seal_choice_dialog.tscn").instantiate()
	opening_seals.setup([], false)
	add_child(opening_seals)
	GameState.biomass.add(1)
	_check(not opening_seals._reroll_button.visible and opening_seals._reroll_button.disabled, "Opening Seal reroll remains unavailable after gain")
	opening_seals.queue_free()
	_screen._on_plant_pressed(_screen._tiles[0])
	_check(GameState.nursery.plots[0].get_state() == NurseryPlotData.State.GROWING, "Plant still starts a fresh grow")
	GameState.biomass.add(1)
	_check(not _screen._tiles[0].get_node("%PlantButton").visible, "Growing plot keeps Plant hidden after gain")
	_check(not _screen._tiles[0]._should_show_plant_hint(), "Growing plot keeps Plant hint hidden")


func _check_affordability(context: String) -> void:
	var plant: Button = _screen._tiles[0].get_node("%PlantButton")
	_check(plant.disabled == not GameState.biomass.can_afford(SealModifiers.fresh_plant_cost()), context + ": Plant")
	_check(_screen._tiles[0]._should_show_plant_hint() == GameState.biomass.can_afford(SealModifiers.fresh_plant_cost()), context + ": Plant hint")
	var plot_unlock: Button = _screen._tiles[1].get_node("%UnlockButton")
	_check(plot_unlock.disabled == not GameState.biomass.can_afford(GameState.nursery.next_unlock_cost()), context + ": plot unlock")
	var colony: TroopSelectionScreen = _base.get_node("%ColonyScreen")
	var squad_unlock: Button = colony._squad_unlock_slot.get_node("%UnlockButton")
	_check(squad_unlock.disabled == not GameState.biomass.can_afford(colony._squad_unlock_slot.unlock_cost), context + ": squad unlock")
	_check(_scout._scout_reroll_button.disabled == not GameState.biomass.can_afford(GameState.current_scout_reroll_cost()), context + ": Scout reroll")
	_check(_training._confirm_button.disabled == not GameState.biomass.can_afford(WeaponSchool.COCOON_COST), context + ": training")
	_check(_seals._reroll_button.disabled == not GameState.biomass.can_afford(_seals._current_seal_reroll_cost()), context + ": Seal reroll")
	for offer in _screen._shop_cards:
		_check(offer._can_afford == GameState.biomass.can_afford(offer.cost), context + ": shop offer %d" % offer.slot_index)
	_check(is_equal_approx(_screen._reroll_button.modulate.a, 1.0 if GameState.biomass.can_afford(GameState.nursery.current_shop_reroll_cost()) else 0.45), context + ": shop reroll appearance")
	_check(not _screen._reroll_button.disabled, context + ": shop reroll keeps rejection feedback")
	_check(_base.get_node("%BiomassChip").get_node("%BiomassAmount").text == BiomassDisplay.number(GameState.biomass.amount), context + ": biomass display")
