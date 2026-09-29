extends RefCounted


## Exercise real Nursery controls and drag payloads, restoring the run afterwards.
static func run(base: Node) -> int:
	var nursery := base.get_node("%NurseryScreen") as NurseryScreen
	var colony := base.get_node("%ColonyScreen") as TroopSelectionScreen
	var chip := base.get_node("%BiomassChip") as Control
	var host := base.get_node("HudLayer/HudRoot") as Control
	var saved_nursery := GameState.nursery
	var saved_troop := GameState.troop
	var saved_seals := GameState.seals
	var saved_balance := GameState.biomass.amount
	var saved_day := GameState.current_day
	var saved_pending := GameState.pending_seal_choice
	var saved_tab: int = base._current_tab
	GameState.nursery = NurseryData.new()
	GameState.troop = TroopData.new()
	GameState.troop.seed_if_empty(StarterPackages.build_units(&"great_sword_spear"))
	GameState.seals = SealsCollection.new()
	GameState.current_day = 2
	GameState.pending_seal_choice = false
	GameState.biomass.amount = 30
	base._select_tab(base.TabId.NURSERY, true)
	await _settle(host)
	var failures := 0
	var card: ShopOfferCard = nursery._shop_cards[0]
	await _hover(card.get_node("%PriceLabel"))
	failures += _expect(chip, -int(card.payload.cost), "Shop click purchase")
	GameState.biomass.amount = 0
	await _settle(host)
	failures += _expect(chip, -int(card.payload.cost), "unaffordable Shop purchase")
	card.set_locked(true)
	await _hover(card.get_node("%LockIcon"))
	failures += _expect(chip, null, "Offer lock has no biomass action")
	card.set_locked(false)
	GameState.biomass.amount = 30
	await _hover(nursery.get_node("%RerollButton"))
	failures += _expect(chip, -GameState.nursery.current_shop_reroll_cost(), "Shop reroll")
	GameState.nursery.advance_shop_reroll_cost()
	await _settle(host)
	failures += _expect(chip, -GameState.nursery.current_shop_reroll_cost(), "live Shop reroll cost")

	var tile: PlotTile = nursery._tiles[0]
	await _hover(tile.get_node("%PlantButton"))
	failures += _expect(chip, -SealModifiers.fresh_plant_cost(), "fresh Plant")
	GameState.seals.add(load("res://assets/base/seals/rotten_thumb.tres") as SealData)
	await _settle(host)
	var plant_cost := SealModifiers.fresh_plant_cost()
	failures += _check(plant_cost < BiomassData.COMMON_SPORE_COST, "Rotten Thumb lowers cost")
	failures += _expect(chip, -plant_cost, "Seal discount changes under pointer")
	await _hover(nursery._tiles[1].get_node("%UnlockButton"))
	failures += _expect(chip, -GameState.nursery.next_unlock_cost(), "Plot unlock")
	GameState.biomass.amount = 0
	await _settle(host)
	failures += _expect(chip, -GameState.nursery.next_unlock_cost(), "unaffordable Plot unlock")
	GameState.biomass.amount = 30

	var fertilizer := load("res://assets/base/nursery/fertilizers/finesse.tres") as FertilizerData
	var stock := GameState.nursery.stock
	stock.slots.fill(fertilizer)
	nursery._refresh()
	await _hover(card.get_node("%PriceLabel"))
	failures += _expect(chip, null, "full Stock blocks click purchase")
	var plot_card: ShopOfferCard = nursery._shop_cards.back()
	plot_card.force_drag(plot_card.payload.duplicate(), null)
	await _hover(tile)
	failures += _expect(chip, -int(plot_card.payload.cost), "Shop direct Plot bypasses full Stock")
	await _hover(nursery._stock_slots[0])
	failures += _expect(chip, null, "full Stock blocks Shop drop")
	await _cancel_drag(host)
	stock.clear()
	nursery._refresh()
	plot_card.force_drag(plot_card.payload.duplicate(), null)
	await _hover(nursery._stock_slots[0])
	failures += _expect(chip, -int(plot_card.payload.cost), "Shop drop into available Stock")
	await _cancel_drag(host)

	stock.set_at(0, fertilizer)
	nursery._refresh()
	var owned_drag := {"type": "fertilizer", "fertilizer": fertilizer, "stock_index": 0}
	nursery._stock_slots[0].force_drag(owned_drag, null)
	await _hover(tile)
	failures += _expect(chip, null, "owned Fertilizer application is free")
	await _hover(nursery._stock_slots[1])
	failures += _expect(chip, null, "Stock rearrangement is free")
	await _hover(card)
	failures += _check(host.get_viewport().gui_get_hovered_control() is ShopSellOverlay,
		"sell overlay owns hover above an existing Shop offer")
	failures += _expect(chip, BiomassData.sell_value(fertilizer.biomass_cost), "Stock sell overlay")
	await _cancel_drag(host)
	failures += _expect(chip, null, "cancelled drag clears preview")
	failures += _check(GameState.biomass.amount == 30 and stock.get_at(0) == fertilizer
		and GameState.nursery.plots[0].is_empty(), "all previews leave balance and items unchanged")
	var before_plant := GameState.biomass.amount
	failures += _check(GameState.try_plant_fresh_common(0), "fresh Plant action succeeds")
	failures += _check(GameState.biomass.amount == before_plant - plant_cost,
		"actual Plant spends its Seal-discounted preview")

	colony._hydrate_from_troop_data()
	colony._build_squad_ui()
	base._select_tab(base.TabId.COLONY, true)
	await _settle(host)
	await _hover(colony._squad_unlock_slot.get_node("%UnlockButton"))
	failures += _expect(chip, -GameState.troop.next_squad_unlock_cost(), "Squad slot unlock")
	GameState.biomass.amount = 0
	await _settle(host)
	failures += _expect(chip, -GameState.troop.next_squad_unlock_cost(), "unaffordable Squad unlock")

	await _move(host, Vector2(4, 4))
	GameState.nursery = saved_nursery
	GameState.troop = saved_troop
	GameState.seals = saved_seals
	GameState.biomass.amount = saved_balance
	GameState.current_day = saved_day
	GameState.pending_seal_choice = saved_pending
	colony._hydrate_from_troop_data()
	colony._build_squad_ui()
	colony._sync_all_slots()
	nursery._hydrate_and_refresh()
	base._select_tab(saved_tab, true)
	await _settle(host)
	print("BIOMASS_NURSERY_CHECKS failures=", failures)
	return failures


static func _expect(chip: Control, delta: Variant, label: String) -> int:
	var expected_delta := 0 if delta == null else int(delta)
	var amount := chip.get_node("%BiomassAmount") as Label
	var change := chip.get_node("%BiomassDelta") as Label
	var matches := (
		amount.text == BiomassDisplay.number(GameState.biomass.amount + expected_delta)
		and change.is_visible_in_tree() == (expected_delta != 0)
		and (expected_delta == 0 or change.text == BiomassDisplay.number(expected_delta, true))
	)
	if not matches:
		var viewport := chip.get_viewport()
		var hovered := viewport.gui_get_hovered_control()
		var drag: Variant = viewport.gui_get_drag_data()
		print("NURSERY_PREVIEW_DIAGNOSTIC ", label, " hovered=", hovered.get_path() if hovered != null else "null",
			" preview=", BiomassPreview.for_hovered(hovered), " dragging=", viewport.gui_is_dragging(),
			" drag_type=", drag.get("type", "") if drag is Dictionary else "none", " amount=", amount.text,
			" delta=", change.text, " expected=", expected_delta)
	return _check(matches, label)


static func _hover(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	await _move(control, point)


static func _move(host: Control, point: Vector2) -> void:
	host.get_viewport().warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	# Keep Input's mouse position aligned when drag highlights trigger hit-testing again.
	motion.position = host.get_viewport().get_final_transform() * point
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _settle(host)


static func _cancel_drag(host: Control) -> void:
	await _move(host, Vector2(4, 4))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = Vector2(4, 4)
	release.pressed = false
	host.get_viewport().push_input(release, true)
	await _settle(host)


static func _settle(host: Control) -> void:
	await host.get_tree().create_timer(0.2).timeout


static func _check(condition: bool, label: String) -> int:
	if condition:
		return 0
	push_error("BIOMASS_NURSERY_CHECK failed: " + label)
	return 1
