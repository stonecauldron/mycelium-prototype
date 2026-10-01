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
	await _cancel_drag(host)
	failures += _expect(chip, null, "cancelled drag clears preview")
	failures += _check(GameState.biomass.amount == 30 and stock.get_at(0) == fertilizer
		and GameState.nursery.plots[0].is_empty(), "all previews leave balance and items unchanged")
	failures += await _sell_region_checks(nursery, host, chip)
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


static func _sell_region_checks(nursery: NurseryScreen, host: Control, chip: Control) -> int:
	var failures := 0
	var camera := host.get_tree().current_scene.get_node("%BaseCamera") as Camera2D
	var saved_camera_position := camera.position
	# Nursery normally has an identity canvas transform; pan slightly to test conversion.
	camera.position += Vector2(48, 24)
	camera.force_update_scroll()
	await _settle(host)
	var zone := nursery.get_node("%ShopDropZone") as ShopDropZone
	var stock := GameState.nursery.stock
	var items := {
		"fertilizer": load("res://assets/base/nursery/fertilizers/finesse.tres"),
		"spore": load("res://assets/base/nursery/common_spore.tres"),
		"mutation": load("res://assets/base/nursery/mutations/body/thorny.tres"),
	}
	var zone_tint := zone.modulate
	failures += _check(not zone.get_global_transform_with_canvas().origin.is_equal_approx(zone.global_position),
		"sell checks exercise the Nursery camera offset")
	for item_type: String in items:
		var item := items[item_type] as Resource
		stock.set_at(0, item)
		nursery._refresh()
		await _settle(host)
		var data := {"type": item_type, "stock_index": 0}
		data[item_type] = item
		var balance := GameState.biomass.amount
		var sale := BiomassData.sell_value(int(item.get("biomass_cost")))
		var offer: ShopOfferCard = nursery._shop_cards[0]
		var offer_point := offer.get_global_transform_with_canvas() * (offer.size * 0.5)
		# Blank Shop space below the shorter Offer cards, away from the centered badge.
		var gap_point := zone.get_global_transform_with_canvas() * Vector2(zone.size.x * 0.8, zone.size.y - 4.0)
		for outside_point: Vector2 in [offer_point, gap_point]:
			nursery._stock_slots[0].force_drag(data, null)
			await _move(host, outside_point)
			var overlay: ShopSellOverlay = zone._sell_overlay
			failures += _check(overlay != null and not overlay.contains_sell_point(outside_point),
				item_type + " outside target is beyond the paper button")
			failures += _check(host.get_viewport().gui_get_hovered_control() != overlay,
				item_type + " outside Shop hover is not captured by sell overlay")
			failures += _expect(chip, null, item_type + " outside Shop area has no sale preview")
			var zone_point := zone.get_global_transform_with_canvas().affine_inverse() * outside_point
			failures += _check(not zone._can_drop_data(zone_point, data),
				item_type + " outside Shop area rejects sale")
			await _release_drag(host, outside_point)
			failures += _check(stock.get_at(0) == item and GameState.biomass.amount == balance,
				item_type + " release outside preserves Stock and biomass")

		nursery._stock_slots[0].force_drag(data, null)
		await _settle(host)
		var overlay: ShopSellOverlay = zone._sell_overlay
		var badge := overlay.get_node("%Badge") as PanelContainer
		await _hover(badge)
		failures += _check(host.get_viewport().gui_get_hovered_control() == overlay,
			item_type + " visible sell button owns hover")
		failures += _expect(chip, sale, item_type + " sell button previews exact payout")
		failures += _check(badge.scale.x > 1.1 and badge.modulate != Color.WHITE,
			item_type + " sell button has scale and tint feedback")
		failures += _check(zone.modulate == zone_tint, item_type + " hover does not tint the whole Shop")
		if item_type == "fertilizer":
			var paper := badge.get_theme_stylebox("panel") as StyleBoxTexture
			var paper_rect := Rect2(Vector2.ZERO, badge.size).grow_individual(
				paper.expand_margin_left, paper.expand_margin_top,
				paper.expand_margin_right, paper.expand_margin_bottom)
			var edge_local := Vector2(paper_rect.get_center().x, paper_rect.end.y - 2.0)
			var edge_point := badge.get_global_transform_with_canvas() * edge_local
			await _move(host, edge_point)
			failures += _check(host.get_viewport().gui_get_hovered_control() == overlay,
				"scaled paper margin remains a live sell target")
			failures += _expect(chip, sale, "scaled paper edge retains sale preview")
			await _snapshot(host, "/tmp/usability-sell-button-edge.png")
			var beyond_edge := badge.get_global_transform_with_canvas() * Vector2(
				paper_rect.end.x + 12.0, paper_rect.get_center().y)
			await _move(host, beyond_edge)
			failures += _expect(chip, null, "leaving scaled paper clears sale preview")
			failures += _check(badge.modulate == Color.WHITE and badge.scale.is_equal_approx(Vector2.ONE),
				"leaving scaled paper clears hover feedback")
			await _snapshot(host, "/tmp/usability-sell-button-outside.png")
			await _hover(badge)
		await _snapshot(host, "/tmp/usability-sell-button-%s.png" % item_type)
		var inside_point := badge.get_global_transform_with_canvas() * (badge.size * 0.5)
		await _release_drag(host, inside_point)
		failures += _check(stock.get_at(0) == null and GameState.biomass.amount == balance + sale,
			item_type + " release on paper sells exactly once for the previewed value")
		failures += _check(not host.get_viewport().gui_is_dragging() and not overlay.visible,
			item_type + " sale ends drag and hides overlay")
		await _move(host, Vector2(4, 4))
		failures += _expect(chip, null, item_type + " completed sale clears its preview")
		print("SELL_REGION_CHECK ", item_type, " payout=", sale, " balance=", GameState.biomass.amount)
	camera.position = saved_camera_position
	camera.force_update_scroll()
	await _settle(host)
	return failures


static func _release_drag(host: Control, point: Vector2) -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = host.get_viewport().get_final_transform() * point
	release.global_position = release.position
	release.pressed = false
	Input.parse_input_event(release)
	await _settle(host)


static func _snapshot(host: Control, path: String) -> void:
	if not OS.get_cmdline_user_args().has("--visual"):
		return
	await RenderingServer.frame_post_draw
	var picture := host.get_viewport().get_texture().get_image()
	if picture != null and not picture.is_empty():
		picture.save_png(path)


static func _expect(chip: Control, delta: Variant, label: String) -> int:
	var expected_delta := 0 if delta == null else int(delta)
	var amount := chip.get_node("%BiomassAmount") as Label
	var change := chip.get_node("%BiomassDelta") as Label
	var unaffordable := expected_delta < 0 and GameState.biomass.amount + expected_delta < 0
	var total := GameState.biomass.amount if unaffordable else GameState.biomass.amount + expected_delta
	var expected_text := "Not enough\nbiomass" if unaffordable else BiomassDisplay.number(expected_delta, true)
	var matches := (
		amount.text == BiomassDisplay.number(total)
		and change.is_visible_in_tree() == (expected_delta != 0)
		and (expected_delta == 0 or change.text == expected_text)
		and amount.get_theme_color("font_color") == StatDisplay.change_color(expected_delta, true)
		and change.get_theme_constant("outline_size") == (0 if unaffordable else 3)
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
