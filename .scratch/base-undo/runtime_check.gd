extends Node

class AnalyticsSpy extends RefCounted:
	var events: Array[Array] = []

	func addResourceEvent(flow: String, currency: String, amount: float, item_type: String, item_id: String, _options: Dictionary) -> void:
		events.append([flow, currency, amount, item_type, item_id])

	func addProgressionEvent(_status: String, _first: String, _second: String, _third: String, _options: Dictionary) -> void:
		pass

	func addProgressionEventWithScore(_status: String, _first: String, _second: String, _third: String, _score: int) -> void:
		pass

	func addDesignEvent(_event: String, _options: Dictionary) -> void:
		pass


## Run as a scene, with a real Base and its normal handlers/signals.
var _failures: int = 0
var _base: Node2D
var _nursery: NurseryScreen
var _colony: TroopSelectionScreen
var _analytics_spy := AnalyticsSpy.new()


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func() -> void: get_tree().quit(2))
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		_failures += 1


func _open_base(day: int = 1, seeded: bool = true, pending_seal: bool = false) -> void:
	if is_instance_valid(_base):
		_base.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	GameState.reset_run()
	GameState.current_day = day
	GameState.run_seed = 23456
	GameState.pending_seal_choice = pending_seal
	if seeded:
		GameState.troop.seed_if_empty(StarterPackages.build_units(StarterPackages.PACKAGE_IDS[0]))
	GameState.ensure_nursery_seeded()
	GameState.biomass.amount = 100
	_base = preload("res://assets/base/base.tscn").instantiate()
	get_tree().root.add_child(_base)
	get_tree().current_scene = _base
	_nursery = _base.get_node("%NurseryScreen")
	_colony = _base.get_node("%ColonyScreen")
	await get_tree().process_frame
	await get_tree().process_frame


func _undo(label: String) -> void:
	_check(GameState.base_undo.can_undo(), label + ": recorded")
	_base._on_undo_pressed()


func _fingerprint(unit: RosterUnitData) -> Array:
	return [unit.display_name, unit.stats.strength, unit.stats.dex, unit.stats.con,
		unit.weapon, unit.weapon_trainings.duplicate(), unit.favourite_child_buff]


func _run() -> void:
	var original_ga := Analytics.ga
	Analytics.ga = _analytics_spy
	await _open_base()
	_check_formation_and_shortcuts()
	await _open_base()
	await _check_undo_hover()
	await _open_base()
	_check_shop()
	_check_analytics()
	await _open_base()
	_check_nursery()
	await _open_base()
	_check_training_and_compost()
	await _open_base()
	_check_rerolls()
	await _open_base(2, true, true)
	await _check_seals()
	await _open_base(0, false, false)
	await _check_starter()
	_check_boundaries()
	_base.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not GameState.base_undo.can_undo(), "Leaving Base clears history")
	Analytics.ga = original_ga
	# Let the audio thread release test cues before shutting down the engine.
	if Audio._music_fade != null:
		Audio._music_fade.kill()
	for player: AudioStreamPlayer in Audio.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await get_tree().create_timer(0.1).timeout
	print("BASE UNDO CHECK: ", _failures, " failures")
	get_tree().quit(1 if _failures else 0)


func _check_formation_and_shortcuts() -> void:
	var troop := GameState.troop
	var squad_alias := troop.squad
	var first := troop.squad[0] as RosterUnitData
	var second := troop.squad[1] as RosterUnitData
	var button := _base.get_node("%UndoButton") as Button
	_check(button.visible and button.disabled, "Undo button visible and disabled initially")
	var no_op := GameState.base_undo.capture("No change")
	GameState.base_undo.record(no_op)
	_colony._move_unit(first, "squad", 0, "squad", 0)
	_check(not GameState.base_undo.can_undo(), "Unchanged snapshots and same-slot moves add no step")
	_colony._move_unit(first, "squad", 0, "bench", 0)
	_colony._move_unit(second, "squad", 1, "bench", 1)
	_check(not button.disabled, "Formation move enables Undo button")
	_undo("Second formation move")
	_check(troop.squad[1] == second and troop.bench[0] == first, "Undo changes only latest formation move")
	var key := InputEventKey.new()
	key.keycode = KEY_Z
	key.pressed = true
	_base._shortcut_input(key)
	_check(troop.bench[0] == first, "Plain Z is ignored")
	if OS.has_feature("macos"):
		key.meta_pressed = true
	else:
		key.ctrl_pressed = true
	key.shift_pressed = true
	_base._shortcut_input(key)
	key.shift_pressed = false
	key.alt_pressed = true
	_base._shortcut_input(key)
	key.alt_pressed = false
	key.echo = true
	_base._shortcut_input(key)
	key.echo = false
	_check(troop.bench[0] == first, "Shift, Alt and repeated undo keys are ignored")
	get_tree().paused = true
	_base._shortcut_input(key)
	_base._on_undo_pressed()
	get_tree().paused = false
	_check(troop.bench[0] == first, "Paused Base ignores button and keyboard undo")
	var input := LineEdit.new()
	_base.get_node("HudLayer/HudRoot").add_child(input)
	input.grab_focus()
	_base._shortcut_input(key)
	_check(troop.bench[0] == first, "Text editing retains its own Undo shortcut")
	input.release_focus()
	input.queue_free()
	_base._shortcut_input(key)
	_check(GameState.troop == troop and troop.squad[0] == first and squad_alias[0] == first,
		"OS Undo restores unit identity and live formation array aliases")
	_check(not GameState.base_undo.can_undo() and button.disabled, "History exhausts after multiple undo steps")
	_colony._on_squad_unlock_pressed(null)
	_check(troop.unlocked_squad_count == TroopData.STARTING_UNLOCKED_SQUAD_SLOTS + 1, "Squad unlock succeeds")
	_undo("Squad unlock")
	_check(troop.unlocked_squad_count == TroopData.STARTING_UNLOCKED_SQUAD_SLOTS and GameState.biomass.amount == 100,
		"Squad unlock restores capacity and cost")


func _check_undo_hover() -> void:
	var button := _base.get_node("%UndoButton") as Button
	var chip := _base.get_node("%BiomassChip") as Control
	var paper := chip.get_node("Paper") as Control
	var amount := chip.get_node("%BiomassAmount") as Label
	var delta := chip.get_node("%BiomassDelta") as Label
	_check(button.text.is_empty() and button.icon != null, "Undo uses an icon without text")
	_check(button.size.x <= 64.0 and button.size.y <= 64.0, "Undo button fits within 64 by 64 pixels")
	_colony._move_unit(GameState.troop.squad[0], "squad", 0, "bench", 0)
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_transform_with_canvas() * (button.size * 0.5)
	get_viewport().push_input(motion, true)
	await get_tree().create_timer(0.2).timeout
	_check(get_viewport().gui_get_hovered_control() == button, "Viewport pointer hovers Undo")
	_check(BiomassPreview.for_hovered(button).is_empty(), "Formation Undo has no Biomass preview")
	_check(paper.scale.distance_to(Vector2.ONE) < 0.01,
		"Hovering zero-delta Undo keeps Biomass counter at normal size")
	_check(amount.text == BiomassDisplay.number(GameState.biomass.amount) and not delta.is_visible_in_tree(),
		"Zero-delta Undo shows the actual balance without a delta")
	var balance := GameState.biomass.amount
	_colony._on_squad_unlock_pressed(null)
	var refund := balance - GameState.biomass.amount
	await get_tree().create_timer(0.2).timeout
	_check(refund > 0 and BiomassPreview.for_hovered(button).get("delta", 0) == refund,
		"Paid Undo still previews its Biomass refund")
	_check(amount.text == BiomassDisplay.number(balance) and delta.is_visible_in_tree()
		and delta.text == BiomassDisplay.number(refund, true), "Paid Undo shows projected balance and signed refund")
	_check(paper.scale.distance_to(Vector2.ONE * 1.18) < 0.01, "Paid Undo still enlarges Biomass preview")
	_base._on_undo_pressed()
	await get_tree().create_timer(0.2).timeout
	_check(GameState.base_undo.can_undo() and BiomassPreview.for_hovered(button).is_empty()
		and paper.scale.distance_to(Vector2.ONE) < 0.01 and not delta.is_visible_in_tree(),
		"Undoing a paid action clears its preview while hovering the next zero-delta Undo")


func _check_shop() -> void:
	var shop := GameState.nursery.spore_shop
	var offer := shop.offers[0]
	var item := offer.item
	var old_sequence: Variant = item.get_meta(&"_nursery_stock_seq") if item.has_meta(&"_nursery_stock_seq") else null
	_nursery._on_shop_lock_toggled(_nursery._shop_cards[0])
	_nursery._on_shop_offer_clicked(_nursery._shop_cards[0])
	_check(GameState.nursery.stock.get_at(0) == item, "Shop purchase adds offered item")
	_undo("Shop purchase")
	_check(shop.offers[0] == offer and offer.locked and GameState.nursery.stock.get_at(0) == null,
		"Purchase restores the same locked offer and empty Stock")
	var restored_sequence: Variant = item.get_meta(&"_nursery_stock_seq") if item.has_meta(&"_nursery_stock_seq") else null
	_check(GameState.biomass.amount == 100 and restored_sequence == old_sequence,
		"Purchase restores biomass and shared item FIFO metadata")
	_undo("Offer lock")
	_check(not offer.locked, "Offer lock is reversible")
	GameState.biomass.amount = 0
	_nursery._on_shop_offer_clicked(_nursery._shop_cards[0])
	_check(not GameState.base_undo.can_undo(), "Failed purchase adds no step")
	GameState.biomass.amount = 100
	_nursery._on_shop_offer_clicked(_nursery._shop_cards[0])
	GameState.base_undo.clear()
	_nursery._on_stock_item_dropped(_nursery._stock_slots[1], {"type": "fertilizer", "stock_index": 0})
	_check(GameState.nursery.stock.get_at(1) == item, "Stock drag moves item")
	_undo("Stock move")
	_check(GameState.nursery.stock.get_at(0) == item and GameState.nursery.stock.get_at(1) == null, "Stock move restores slots")
	var balance := GameState.biomass.amount
	_nursery._on_shop_sell_dropped(null, {"type": "fertilizer", "stock_index": 0})
	_undo("Stock sale")
	_check(GameState.nursery.stock.get_at(0) == item and GameState.biomass.amount == balance, "Stock sale restores item and payout")


func _check_analytics() -> void:
	_analytics_spy.events.clear()
	_nursery._on_shop_offer_clicked(_nursery._shop_cards[1])
	_undo("Purchase analytics")
	_check_inverse_events("sink", "Purchase undo emits matching source")
	_analytics_spy.events.clear()
	_nursery._on_shop_sell_dropped(null, {"type": "fertilizer", "stock_index": 0})
	_undo("Sale analytics")
	_check_inverse_events("source", "Sale undo emits matching sink")
	_analytics_spy.events.clear()
	GameState.debug_mode_active = true
	_nursery._on_shop_offer_clicked(_nursery._shop_cards[1])
	GameState.debug_mode_active = false
	_undo("Suppressed purchase analytics")
	_check(_analytics_spy.events.is_empty(), "Undo sends no inverse for analytics suppressed during original action")


func _check_inverse_events(flow: String, label: String) -> void:
	if _analytics_spy.events.size() != 2:
		_check(false, label + " (expected two events)")
		return
	var inverse := _analytics_spy.events[0].duplicate()
	inverse[0] = "source" if flow == "sink" else "sink"
	_check(_analytics_spy.events[0][0] == flow and _analytics_spy.events[1] == inverse, label)


func _check_nursery() -> void:
	var data := GameState.nursery
	var plot := data.plots[0] as NurseryPlotData
	_nursery._on_plant_pressed(_nursery._tiles[0])
	_check(not plot.is_empty(), "Fresh planting succeeds")
	_undo("Fresh planting")
	_check(plot.is_empty() and not data._first_spore_planted and GameState.show_plot_plant_hint,
		"Plant undo restores plot, first-plant rule and hint")
	_check(GameState.biomass.amount == 100, "Plant undo refunds biomass")
	_nursery._try_unlock_plot()
	_undo("Plot unlock")
	_check(data.unlocked_plot_count == NurseryData.STARTING_UNLOCKED_PLOTS and GameState.biomass.amount == 100,
		"Plot unlock restores capacity and biomass")
	_nursery._on_plant_pressed(_nursery._tiles[0])
	GameState.base_undo.clear()
	var spore := plot.planted_spore
	var remaining := plot.remaining_time
	var fertilizer := preload("res://assets/base/nursery/fertilizers/brute_force.tres") as FertilizerData
	data.add_fertilizer(fertilizer)
	_nursery._on_plot_item_dropped(_nursery._tiles[0], {"type": "fertilizer", "stock_index": 0})
	_undo("Fertilizer application")
	_check(plot.applied_fertilizers.is_empty() and data.stock.get_at(0) == fertilizer, "Fertilizer undo restores Stock and plot")
	data.stock.clear()
	var mutation := preload("res://assets/base/nursery/mutations/body/fat.tres") as MutationData
	data.add_mutation(mutation)
	_nursery._on_plot_item_dropped(_nursery._tiles[0], {"type": "mutation", "stock_index": 0})
	_undo("Mutation application")
	_check(plot.body_mutation == null and data.stock.get_at(0) == mutation, "Mutation undo restores Stock and plot")
	data.stock.clear()
	plot.body_mutation = mutation
	plot.applied_fertilizers.append(fertilizer)
	var fungicide := preload("res://assets/base/nursery/fertilizers/fungicide.tres") as FertilizerData
	data.add_fertilizer(fungicide)
	_nursery._on_plot_item_dropped(_nursery._tiles[0], {"type": "fertilizer", "stock_index": 0})
	_check(plot.is_empty() and plot.pending_stat_bonus > 0, "Fungicide clears grow and leaves nutrition")
	_undo("Fungicide")
	_check(plot.planted_spore == spore and plot.remaining_time == remaining and plot.pending_stat_bonus == 0,
		"Fungicide restores the same spore, timer and nutrition")
	_check(plot.body_mutation == mutation and plot.applied_fertilizers == [fertilizer] and data.stock.get_at(0) == fungicide,
		"Fungicide restores mutations, fertilizers and consumed item")
	GameState.seals.add(preload("res://assets/base/seals/favourite_child.tres"))
	plot.remaining_time = 0
	GameState.base_undo.clear()
	var before_units := GameState.troop.get_squad_roster()
	_nursery._on_plot_pressed(_nursery._tiles[0])
	var harvested := GameState.troop.squad[2] as RosterUnitData
	_check(harvested != null and GameState.favourite_child_used_today, "Harvest adds Favourite Child")
	var first_result := _fingerprint(harvested)
	_undo("Harvest")
	_check(plot.can_harvest() and GameState.troop.get_squad_roster() == before_units,
		"Harvest restores READY plot and removes generated unit")
	_check(not GameState.favourite_child_used_today and GameState.show_plot_harvest_hint and _nursery._hatch_toasts.is_empty(),
		"Harvest restores daily bonus and hint and dismisses toast")
	_nursery._on_plot_pressed(_nursery._tiles[0])
	_check(_fingerprint(GameState.troop.squad[2]) == first_result, "Harvest replay preserves name and rolled stats")


func _check_training_and_compost() -> void:
	var adult := GameState.troop.squad[0] as RosterUnitData
	var child := GameState.troop.squad[1] as RosterUnitData
	var stats := adult.stats
	var adult_before := _fingerprint(adult)
	_colony._on_pupation_confirmed(adult, WeaponSchool.Id.BOW)
	_check(adult.weapon_trainings != adult_before[5], "Adult retraining changes weapon schools")
	_undo("Adult training")
	_check(adult.stats == stats and _fingerprint(adult) == adult_before and GameState.biomass.amount == 100,
		"Adult training restores same stats resource, schools, weapon and cost")
	_colony._on_pupation_confirmed(child, WeaponSchool.Id.SWORD)
	_check(GameState.pupation.get_occupant(WeaponSchool.Id.SWORD) == child, "Child enters cocoon")
	var cancel := GameState.base_undo.capture("Cancel Training")
	GameState.try_cancel_pupation(WeaponSchool.Id.SWORD)
	GameState.base_undo.record(cancel)
	_undo("Training cancellation")
	_check(GameState.pupation.get_occupant(WeaponSchool.Id.SWORD) == child and GameState.troop.squad[1] == null,
		"Cancel undo returns child to cocoon")
	_undo("Child training")
	_check(GameState.pupation.get_occupant(WeaponSchool.Id.SWORD) == null and GameState.troop.squad[1] == child,
		"Training undo restores original formation")
	adult.cap_mutation = preload("res://assets/base/nursery/mutations/cap/bank.tres")
	adult.biomass_bank = 10
	child.cap_mutation = preload("res://assets/base/nursery/mutations/cap/mould.tres")
	var child_before := _fingerprint(child)
	for i in NurseryData.STOCK_SLOT_COUNT:
		GameState.nursery.add_spore(SporeData.new())
	var stock_before := GameState.nursery.stock.slots.duplicate()
	var sequence_before := GameState.nursery._next_stock_seq
	_colony._on_compost_confirmed(adult)
	_check(adult.biomass_bank == 0 and child.mould_compost_stacks == 1 and GameState.nursery.first_lineage_spore != null,
		"Compost pays Bank, grows Mould and emits lineage spore into full Stock")
	_undo("Compost")
	_check(GameState.troop.squad[0] == adult and adult.biomass_bank == 10 and not adult.emitted_death_spore and adult.last_death_biomass_yield == 0,
		"Compost restores same adult and death bookkeeping")
	_check(_fingerprint(child) == child_before and child.mould_compost_stacks == 0 and GameState.biomass.amount == 100,
		"Compost restores ally Mould stats and balance")
	_check(GameState.nursery.stock.slots == stock_before and GameState.nursery._next_stock_seq == sequence_before and GameState.nursery.first_lineage_spore == null,
		"Compost restores FIFO eviction, sequence and lineage hint")


func _check_rerolls() -> void:
	var scout := _colony.get_node("%ScoutBubble") as ScoutBubble
	for reroll: Callable in [_nursery._on_reroll_pressed, scout._on_scout_reroll_pressed]:
		_nursery._on_shop_lock_toggled(_nursery._shop_cards[0])
		GameState.biomass.amount = 0
		reroll.call()
		_check(GameState.base_undo.can_undo(), "Failed %s retains history" % reroll.get_method())
		GameState.biomass.amount = 100
		reroll.call()
		_check(not GameState.base_undo.can_undo(), "Successful %s clears history" % reroll.get_method())
		var balance := GameState.biomass.amount
		var formation := GameState.upcoming_enemy_formation.duplicate()
		var offers := GameState.nursery.spore_shop.offers.duplicate()
		_nursery._on_shop_lock_toggled(_nursery._shop_cards[0])
		_undo("Action after reroll")
		_check(GameState.biomass.amount == balance and GameState.upcoming_enemy_formation == formation and GameState.nursery.spore_shop.offers == offers,
			"Undo after reroll retains new offers, army and paid cost")
		_check(not GameState.base_undo.can_undo(), "Cannot undo across reroll barrier")

func _check_seals() -> void:
	var dialog := _colony._seal_dialog
	_check(is_instance_valid(dialog), "Pending Seal dialog opens")
	var locked := GameState.nursery.spore_shop.offers[0].locked
	_nursery._on_shop_lock_toggled(_nursery._shop_cards[0])
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_Z
		key.pressed = pressed
		if OS.has_feature("macos"):
			key.meta_pressed = true
		else:
			key.ctrl_pressed = true
		get_viewport().push_input(key, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(GameState.nursery.spore_shop.offers[0].locked == locked and not GameState.base_undo.can_undo(),
		"Viewport dispatch routes OS Undo through visible Seal chooser")
	_check(_colony.is_seal_choice_visible(), "Keyboard undo retains visible Seal chooser")
	_nursery._on_shop_lock_toggled(_nursery._shop_cards[0])
	var button := _base.get_node("%UndoButton") as Button
	var center := button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = center
	get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = center
		click.pressed = pressed
		get_viewport().push_input(click, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(GameState.nursery.spore_shop.offers[0].locked == locked and not GameState.base_undo.can_undo(),
		"Viewport mouse click reaches Undo above visible Seal chooser")
	dialog = _colony._seal_dialog
	_nursery._on_shop_lock_toggled(_nursery._shop_cards[0])
	GameState.biomass.amount = 0
	dialog._on_reroll_pressed()
	_check(GameState.base_undo.can_undo(), "Failed Seal reroll retains history")
	GameState.biomass.amount = 100
	dialog._on_reroll_pressed()
	_check(not GameState.base_undo.can_undo() and GameState.seal_rerolls_this_pick == 1, "Paid Seal reroll clears history and retains count")
	var offers := dialog._offers.duplicate()
	var balance := GameState.biomass.amount
	dialog._on_card_pressed(dialog._offers[0])
	dialog._on_confirm_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not GameState.pending_seal_choice and GameState.seals.owned.size() == 1, "Seal pick is applied")
	_undo("Seal choice")
	await get_tree().process_frame
	await get_tree().process_frame
	var restored := _colony._seal_dialog
	_check(GameState.pending_seal_choice and GameState.seals.owned.is_empty() and is_instance_valid(restored), "Undo Seal reopens pending picker")
	_check(restored._offers == offers and restored._rerolls_this_pick == 1 and GameState.biomass.amount == balance,
		"Undo Seal retains exact paid offers, price counter and balance")
	_check(not GameState.base_undo.can_undo(), "Seal undo cannot cross paid reroll")
	# Greenhouse mutates an existing grow; Golden Mould changes opening balance.
	GameState.pending_seal_choice = false
	_colony.refresh_after_undo()
	var plot := GameState.nursery.plots[0] as NurseryPlotData
	GameState.try_plant_fresh_common(0)
	var remaining := plot.remaining_time
	var snapshot := GameState.base_undo.capture("Choose Greenhouse")
	GameState.try_add_seal(preload("res://assets/base/seals/greenhouse.tres"))
	GameState.base_undo.record(snapshot)
	_undo("Greenhouse")
	_check(plot.remaining_time == remaining and GameState.seals.owned.is_empty(), "Greenhouse undo restores existing grow timer")
	GameState.current_day = 0
	balance = GameState.biomass.amount
	snapshot = GameState.base_undo.capture("Choose Golden Mould")
	GameState.try_add_seal(preload("res://assets/base/seals/golden_mould.tres"))
	GameState.base_undo.record(snapshot)
	_undo("Golden Mould")
	_check(GameState.biomass.amount == balance and GameState.seals.owned.is_empty(), "Opening Golden Mould undo removes its biomass grant")


func _check_starter() -> void:
	var dialog := _colony._starter_dialog
	_check(is_instance_valid(dialog), "Unseeded troop opens starter picker")
	dialog._on_card_pressed(StarterPackages.PACKAGE_IDS[0])
	dialog._on_confirm_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	var first := _fingerprint(GameState.troop.squad[0])
	var second := _fingerprint(GameState.troop.squad[1])
	_undo("Starter choice")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not GameState.troop.is_seeded() and GameState.troop.living_unit_count() == 0 and is_instance_valid(_colony._starter_dialog),
		"Starter undo restores unseeded troop and picker")
	dialog = _colony._starter_dialog
	dialog._on_card_pressed(StarterPackages.PACKAGE_IDS[0])
	dialog._on_confirm_pressed()
	await get_tree().process_frame
	_check(_fingerprint(GameState.troop.squad[0]) == first and _fingerprint(GameState.troop.squad[1]) == second,
		"Starter replay preserves both names and rolled stats")


func _check_boundaries() -> void:
	var stale := GameState.base_undo.capture("Stale")
	GameState.base_undo.clear()
	GameState.biomass.add(1)
	GameState.base_undo.record(stale)
	_check(not GameState.base_undo.can_undo(), "Pre-barrier snapshot cannot reenter history")
	GameState.base_undo.end_visit()
	_check(GameState.base_undo.capture("Outside Base") == null, "Actions outside a Base visit cannot record")
	GameState.base_undo.begin_visit()
	var battle_snapshot := GameState.base_undo.capture("Before Battle")
	GameState.biomass.add(1)
	GameState.base_undo.record(battle_snapshot)
	# Exercise launch bookkeeping without replacing the test scene during its checks.
	SceneTransition._busy = true
	_colony.start_combat()
	SceneTransition._busy = false
	_check(not GameState.base_undo.can_undo(), "Battle launch clears history immediately")
	GameState.base_undo.begin_visit()
	var snapshot := GameState.base_undo.capture("Before reset")
	GameState.biomass.add(1)
	GameState.base_undo.record(snapshot)
	GameState.reset_run()
	_check(not GameState.base_undo.can_undo(), "New Run clears history")
