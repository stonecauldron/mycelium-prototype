extends Node

## Real Base handlers; the fixture commits model actions before inspecting presentation.
var _failures := 0
var _base: Node2D
var _colony: TroopSelectionScreen
var _nursery: NurseryScreen

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(180.0).timeout.connect(func() -> void: get_tree().quit(2))
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		_failures += 1

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _unit(trainings: Array[int] = [], adult: bool = false) -> RosterUnitData:
	var unit := RosterUnitData.new()
	unit.display_name = "Fern"
	unit.lineage_name = "Fern"
	unit.stats = UnitStatsData.new()
	unit.stats.strength = 10
	unit.stats.dex = 10
	unit.stats.con = 10
	unit.weapon_trainings = trainings.duplicate()
	unit.is_imago = adult
	unit.life_stage_id = RosterUnitData.STAGE_IMAGO if adult else RosterUnitData.STAGE_JUVENILE
	unit.sync_weapon_from_trainings()
	return unit

func _open() -> void:
	if is_instance_valid(_base):
		_base.queue_free()
		await _wait(0.35)
	GameState.reset_run()
	GameState.current_day = 1
	GameState.run_seed = 32145
	GameState.pending_seal_choice = false
	GameState.show_plot_plant_hint = false
	GameState.show_start_combat_hint = false
	GameState.troop.seed_if_empty([_unit([WeaponSchool.Id.SWORD], true)])
	GameState.ensure_nursery_seeded()
	GameState.biomass.amount = 100
	_base = preload("res://assets/base/base.tscn").instantiate()
	get_tree().root.add_child(_base)
	get_tree().current_scene = _base
	_colony = _base.get_node("%ColonyScreen")
	_nursery = _base.get_node("%NurseryScreen")
	await _wait(0.35)

func _snapshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "/tmp/unit-emergence-%s.png" % label
	get_viewport().get_texture().get_image().save_png(path)
	print("SCREENSHOT ", path)

func _check_effect(effect: UnitEmergence, count: int, label: String) -> void:
	_check(is_instance_valid(effect), label + " has presenter")
	if not is_instance_valid(effect):
		return
	_check(effect._actors.size() == count, label + " actual retained actor count")
	_check(effect.mouse_filter == Control.MOUSE_FILTER_IGNORE, label + " is passive")
	for actor in effect._actors:
		var actual := actor.get_meta("unit") as RosterUnitData
		_check(GameState.troop.squad.has(actual) or GameState.troop.bench.has(actual), label + " uses committed unit")

func _finished_actors(effect: UnitEmergence, result: Dictionary) -> void:
	result.transforms = []
	result.bounds = []
	result.alpha = []
	for actor in effect._actors:
		var canvas := actor.get_global_transform_with_canvas()
		result.transforms.append(canvas)
		result.bounds.append(canvas * actor.visual_rect_local(true, true))
		result.alpha.append(actor.modulate.a)

func _await_cocoon() -> UnitEmergence:
	var remaining := 2.0
	while not is_instance_valid(_colony._emergence) and remaining > 0.0:
		await get_tree().process_frame
		remaining -= get_process_delta_time()
	return _colony._emergence

func _observe_cocoon(effect: UnitEmergence, unit: RosterUnitData, label: String, expected: Transform2D) -> void:
	_check_effect(effect, 1, label)
	if not is_instance_valid(effect):
		return
	var finished := {}
	effect.finished.connect(_finished_actors.bind(effect, finished))
	var previous := Vector2.ZERO
	var previous_time := 0.0
	var max_step := 0.0
	var scale_ok := true
	var opaque := true
	var continuous := true
	var peak_dim := 0.0
	var contained := true
	var recovered := false
	var cue_at := -1.0
	var release_at := -1.0
	var captured := false
	var remaining := 8.0
	while is_instance_valid(effect) and remaining > 0.0:
		peak_dim = maxf(peak_dim, effect._backdrop.color.a)
		if effect._cue_started and cue_at < 0:
			cue_at = effect._elapsed
		if effect._released:
			if release_at < 0:
				release_at = effect._elapsed
			var actor := effect._actors[0]
			var canvas := actor.get_global_transform_with_canvas()
			contained = contained and get_viewport().get_visible_rect().grow(1).encloses(canvas * actor.visual_rect_local(true, true))
			if effect._elapsed > effect._anticipation + 0.5:
				recovered = effect._backdrop.color.a < 0.01
			scale_ok = scale_ok and canvas.get_scale().distance_to(expected.get_scale()) < 0.01
			opaque = opaque and actor.modulate.a > 0.99
			if previous_time > 0:
				var step := canvas.origin.distance_to(previous)
				max_step = maxf(max_step, step)
				continuous = continuous and step < maxf(90.0, (effect._elapsed - previous_time) * 5000.0)
			previous = canvas.origin
			previous_time = effect._elapsed
			if not captured and effect._elapsed - effect._anticipation > 0.35:
				captured = true
				await _snapshot(label + "-arc")
		await get_tree().process_frame
		remaining -= get_process_delta_time()
	_check(not is_instance_valid(effect) and not finished.is_empty(), label + " completes bounded launch arc")
	_check(scale_ok and opaque and continuous, label + " keeps destination scale/opacity with continuous travel")
	_check(peak_dim > 0.1 and recovered, label + " dims anticipation then recovers after release")
	_check(contained, label + " full painted actor stays in viewport along arc")
	if not finished.is_empty():
		await get_tree().process_frame
		var arrived: Transform2D = finished.transforms[0]
		var restored := _colony._find_unit_card(unit)
		_check(restored != null and restored.modulate.a > 0.99, label + " restores live card after landing")
		if restored != null:
			expected = restored.portrait_canvas_transform()
			_check(arrived.origin.distance_to(expected.origin) < 1.0
				and arrived.get_scale().distance_to(expected.get_scale()) < 0.01, label + " lands exactly on restored destination portrait")
		print("ARC_GEOMETRY ", label, " destination=", expected, " arrival=", arrived, " max_frame_step=", max_step)
	_check(absf(cue_at + Sfx.COCOON_EMERGE_TRANSIENT_SECONDS - release_at) <= 0.018, label + " cue aligns with release within one60fps frame")
	await _snapshot(label + "-arrived")

func _instant(adult: bool, bench: bool = false) -> void:
	await _open()
	var trainings: Array[int] = []
	if adult:
		trainings = [WeaponSchool.Id.MACE, WeaponSchool.Id.BOW]
	var unit := _unit(trainings, adult)
	unit.cocoon_duration_days = 0
	if adult:
		unit.body_mutation = load("res://assets/base/nursery/mutations/body/fat.tres")
		unit.cap_mutation = load("res://assets/base/nursery/mutations/cap/inky.tres")
	if bench:
		GameState.troop.bench[0] = unit
	else:
		GameState.troop.try_add_unit(unit)
	_colony.on_screen_shown()
	_colony._open_pupation_confirm(unit, WeaponSchool.Id.BOW)
	await get_tree().process_frame
	var dialog := _colony._pupation_dialog
	(dialog.get_node("%ConfirmButton") as Button).pressed.emit()
	(dialog.get_node("%ConfirmButton") as Button).pressed.emit()
	var card := _colony._find_unit_card(unit)
	_check(card != null and card.modulate.a == 0.0, "queued destination preserves layout without painted result flash")
	var expected := card.portrait_canvas_transform() if card != null else Transform2D.IDENTITY
	var effect := await _await_cocoon()
	_check(is_instance_valid(effect), "instant confirmed dialog starts reveal")
	if not is_instance_valid(effect):
		return
	var charged := GameState.biomass.amount
	_check(charged == 100 - WeaponSchool.COCOON_COST and GameState.biomass.amount == charged, "same-frame repeated ConfirmButton input spends once")
	_check(unit.is_adult_stage() and unit.weapon_trainings == ([WeaponSchool.Id.BOW, WeaponSchool.Id.BOW] if adult else [WeaponSchool.Id.BOW]), "instant actual stage and ordered result")
	await _observe_cocoon(effect, unit, "bench" if bench else ("adult" if adult else "child"), expected)
	_check(_colony._emergence == null, "instant presenter finishes and frees")
	_check(Audio._reveal_audio_leases == 0 and is_equal_approx(Audio._reveal_music_gain, 1.0), "instant music recovers")
	_colony.on_screen_shown()
	await _wait(0.1)
	_check(_colony._emergence == null and GameState.pending_cocoon_emergences.is_empty(), "instant reveal does not replay")

func _prepare_harvest(yield_count: int, free_slots: int) -> void:
	_nursery.dismiss_hatch_results()
	GameState.troop.squad.fill(null)
	GameState.troop.bench.fill(null)
	for i in 8 - free_slots:
		GameState.troop.try_add_unit(_unit([WeaponSchool.Id.SWORD], true))
	var plot := GameState.nursery.plots[0] as NurseryPlotData
	plot.clear()
	plot.planted_spore = SporeData.new()
	plot.remaining_time = 0
	if yield_count == 6:
		plot.applied_fertilizers = [load("res://assets/base/nursery/fertilizers/meiosis.tres"), load("res://assets/base/nursery/fertilizers/triploid_cells.tres")]
	_base._select_tab(_base.TabId.NURSERY, true)
	_nursery._refresh()
	GameState.base_undo.clear()
	await _wait(0.08)

func _count() -> int:
	var count := GameState.troop.get_squad_roster().size()
	for unit in GameState.troop.bench:
		if unit != null:
			count += 1
	return count

func _harvest(yield_count: int, free_slots: int) -> void:
	await _prepare_harvest(yield_count, free_slots)
	var before := _count()
	var retained := mini(yield_count, free_slots)
	_nursery._tiles[0].plot_pressed.emit(_nursery._tiles[0])
	var effect := _nursery._hatch_reveal
	_nursery._tiles[0].plot_pressed.emit(_nursery._tiles[0])
	_check(_count() == before + retained, "harvest yield %d capacity %d commits once" % [yield_count, free_slots])
	_check((GameState.nursery.plots[0] as NurseryPlotData).is_empty() == (free_slots > 0), "full Troop preserves ready egg; successful harvest clears it")
	if retained == 0:
		_check(effect == null, "full Troop has no reveal")
		return
	_check_effect(effect, retained, "harvest-%d" % retained)
	if not is_instance_valid(effect):
		return
	var cards := _nursery._hatch_toasts.duplicate()
	_check(cards.size() == retained, "harvest shows retained result cards immediately")
	var finished := {}
	effect.finished.connect(_finished_actors.bind(effect, finished))
	var seen_walking: Array[bool] = []
	seen_walking.resize(retained)
	seen_walking.fill(false)
	var previous_x: Array[float] = []
	previous_x.resize(retained)
	previous_x.fill(-INF)
	var moving_right := true
	var opaque := true
	var scale_ok := true
	var cards_present := true
	var peak_dim := 0.0
	var captured_hatch := false
	var captured_walk := false
	var remaining := 10.0
	while is_instance_valid(effect) and remaining > 0.0:
		peak_dim = maxf(peak_dim, effect._backdrop.color.a)
		cards_present = cards_present and _nursery._hatch_toasts == cards
		for i in effect._actors.size():
			var actor := effect._actors[i]
			if actor.visible:
				opaque = opaque and actor.modulate.a > 0.99
				scale_ok = scale_ok and actor.scale.is_equal_approx(Vector2.ONE * UnitCard.PORTRAIT_SCALE)
			if effect._walking[i]:
				seen_walking[i] = actor.animation_player.current_animation == "walk"
				moving_right = moving_right and actor.position.x >= previous_x[i] - 0.1
				previous_x[i] = actor.position.x
		if not captured_hatch and effect._elapsed > 0.55:
			captured_hatch = true
			await _snapshot("hatch-%d-release" % retained)
		if not captured_walk and effect._walking[0] and effect._elapsed > 1.25:
			captured_walk = true
			await _snapshot("hatch-%d-walk" % retained)
		await get_tree().process_frame
		remaining -= get_process_delta_time()
	_check(not is_instance_valid(effect) and not finished.is_empty(), "hatch finishes after bounded walk")
	_check(not seen_walking.has(false) and moving_right and opaque and scale_ok, "all retained hatchlings walk right at normal scale without fading")
	_check(cards_present and peak_dim > 0.1, "hatch dims anticipation with the same result cards already shown")
	if not finished.is_empty():
		for bounds: Rect2 in finished.bounds:
			_check(bounds.position.x > get_viewport().get_visible_rect().end.x, "whole painted hatchling leaves screen")
	_check(_nursery._hatch_reveal == null and _nursery._hatch_toasts.size() == retained, "finished harvest shows only retained result cards")
	for card in _nursery._hatch_toasts:
		var bounds := card.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, card.size)
		_check(get_viewport().get_visible_rect().grow(1).encloses(bounds), "harvest result card fits viewport")
	await _snapshot("hatch-%d-cards" % retained)

func _interruptions() -> void:
	await _prepare_harvest(1, 7)
	_nursery._tiles[0].plot_pressed.emit(_nursery._tiles[0])
	await _wait(0.4)
	var effect := _nursery._hatch_reveal
	(_base.get_node("%UndoButton") as Button).pressed.emit()
	await _wait(0.35)
	_check(not is_instance_valid(effect) and _count() == 1 and (GameState.nursery.plots[0] as NurseryPlotData).can_harvest(), "Undo cancels reveal and restores committed harvest")
	_check(_nursery._hatch_toasts.is_empty(), "Undo has no stale cards")
	_nursery._tiles[0].plot_pressed.emit(_nursery._tiles[0])
	await _wait(0.4)
	_base._select_tab(_base.TabId.COLONY, true)
	await _wait(1.1)
	_check(_nursery._hatch_reveal == null and _nursery._hatch_toasts.is_empty() and _count() == 2, "tab departure cancels presentation without losing harvest")
	await _prepare_harvest(1, 7)
	_nursery._tiles[0].plot_pressed.emit(_nursery._tiles[0])
	await _wait(0.4)
	effect = _nursery._hatch_reveal
	var owned_sounds := effect.find_children("*", "AudioStreamPlayer", false, false)
	var menu := _base.get_node("RunMenu") as RunMenu
	menu.open_menu()
	await _wait(0.4)
	_check(not is_instance_valid(effect) and _nursery._hatch_reveal == null, "pause removes reveal synchronously")
	for sound in owned_sounds:
		_check(not is_instance_valid(sound), "cancel frees owned sound")
	_check(Audio._reveal_audio_leases == 0 and is_equal_approx(Audio._reveal_music_gain, 1.0), "music recovers while paused")
	menu.close_menu()
	await _prepare_harvest(1, 7)
	GameState.pending_seal_choice = true
	_nursery._tiles[0].plot_pressed.emit(_nursery._tiles[0])
	await _wait(0.4)
	(_base.get_node("%StartCombatButton") as Button).pressed.emit()
	await _wait(1.1)
	_check(_colony.is_seal_choice_visible() and _nursery._hatch_reveal == null and _nursery._hatch_toasts.is_empty(), "reopened Seal chooser has no hatch overlay or late cards")
	_colony.hide_seal_choice()
	GameState.pending_seal_choice = false
	await _prepare_harvest(1, 7)
	_nursery._tiles[0].plot_pressed.emit(_nursery._tiles[0])
	await _wait(0.4)
	_nursery._shop_cards[0].lock_toggled.emit(_nursery._shop_cards[0])
	await _wait(1.1)
	_check(_nursery._hatch_reveal == null and _nursery._hatch_toasts.is_empty() and _count() == 2, "shop lock dismisses presentation and keeps harvested unit")
	await _prepare_harvest(1, 7)
	_base._select_tab(_base.TabId.COLONY, true)
	_base._select_tab(_base.TabId.NURSERY)
	_nursery._tiles[0].plot_pressed.emit(_nursery._tiles[0])
	_check((GameState.nursery.plots[0] as NurseryPlotData).can_harvest() and _nursery._hatch_reveal == null, "camera-pan harvest input does not consume egg")
	await _wait(0.4)
	_nursery._tiles[0].plot_pressed.emit(_nursery._tiles[0])
	await _wait(0.4)
	_base._on_debug_advance_day_pressed()
	await _wait(1.1)
	_check(_nursery._hatch_reveal == null and _nursery._hatch_toasts.is_empty(), "debug advance cancels hatch and late cards")
	_colony.hide_seal_choice()
	GameState.pending_seal_choice = false

func _delayed() -> void:
	await _open()
	var first := _unit()
	var second := _unit()
	first.cocoon_duration_days = 1
	second.cocoon_duration_days = 1
	GameState.troop.try_add_unit(first)
	GameState.troop.try_add_unit(second)
	_check(GameState.try_cocoon_for_pupation(first, WeaponSchool.Id.BOW) and GameState.try_cocoon_for_pupation(second, WeaponSchool.Id.MACE), "two delayed Children enter actual cocoons")
	_base._select_tab(_base.TabId.NURSERY, true)
	GameState.emerge_pupations()
	_check(GameState.pending_cocoon_emergences.size() == 2 and first.is_adult_stage() and second.is_adult_stage(), "day emergence commits and queues both actual results")
	# An unrelated reversible Nursery action must not erase the already-committed queue.
	_nursery._shop_cards[0].lock_toggled.emit(_nursery._shop_cards[0])
	_base._on_undo_pressed()
	_check(GameState.pending_cocoon_emergences.size() == 2, "unrelated Undo preserves valid pending delayed reveals")
	_base._select_tab(_base.TabId.COLONY, true)
	await _wait(0.65)
	_check_effect(_colony._emergence, 1, "delayed-first")
	await _snapshot("delayed-apex")
	_base._select_tab(_base.TabId.NURSERY, true)
	_check(GameState.pending_cocoon_emergences.size() == 1, "hide cancels active but retains unplayed queue")
	_base._select_tab(_base.TabId.COLONY, true)
	var card := _colony._find_unit_card(second)
	var expected := card.portrait_canvas_transform() if card != null else Transform2D.IDENTITY
	var effect := await _await_cocoon()
	await _observe_cocoon(effect, second, "delayed-second", expected)
	_check(_colony._emergence == null and GameState.pending_cocoon_emergences.is_empty(), "remaining delayed reveal drains exactly once")

func _start_compost(adult: bool, full_stock: bool = false) -> Dictionary:
	await _open()
	var unit := _unit([WeaponSchool.Id.BOW], adult)
	GameState.troop.try_add_unit(unit)
	GameState.nursery.stock.clear()
	if full_stock:
		for i in GameState.nursery.stock.slots.size():
			GameState.nursery.stock.slots[i] = SporeData.new()
	var before := GameState.nursery.stock.slots.duplicate()
	var payout := int(GameState.preview_compost_outcome(unit).biomass)
	_colony.on_screen_shown()
	_colony._open_compost_confirm(unit)
	await get_tree().process_frame
	var dialog := _colony._compost_dialog
	(dialog.get_node("%ConfirmButton") as Button).pressed.emit()
	(dialog.get_node("%ConfirmButton") as Button).pressed.emit()
	await _wait(0.05)
	var actual: Array[SporeData] = []
	for item in GameState.nursery.stock.slots:
		if item is SporeData and not before.has(item):
			actual.append(item)
	_check(not GameState.troop.squad.has(unit) and not GameState.troop.bench.has(unit)
		and GameState.biomass.amount == 100 + payout, "Compost double confirmation commits removal and payout once")
	_check(actual.size() == (1 if adult else 0), "Compost creates only authoritative Adult spores")
	return {"effect": _colony._compost_release, "unit": unit, "spores": actual, "before": before}

func _finished_spores(effect: CompostRelease, result: Dictionary) -> void:
	result.bounds = []
	for icon in effect._spores:
		result.bounds.append(icon.get_global_transform_with_canvas() * icon.get_rect())

func _compost(adult: bool, full_stock: bool = false) -> void:
	var state := await _start_compost(adult, full_stock)
	var effect := state.effect as CompostRelease
	var label := "compost-adult" if adult else "compost-child"
	if full_stock:
		label += "-full-stock"
	_check(is_instance_valid(effect), label + " has passive presenter")
	if not is_instance_valid(effect):
		return
	_check(effect.mouse_filter == Control.MOUSE_FILTER_IGNORE and effect._spores.size() == state.spores.size(), label + " mirrors actual spore additions")
	for i in effect._spores.size():
		var icon := effect._spores[i]
		_check(icon.get_meta("spore") == state.spores[i] and icon.modulate == state.spores[i].tint, label + " keeps spore identity and tint")
	var finished := {}
	effect.finished.connect(_finished_spores.bind(effect, finished))
	var ground := effect._bin.position
	var grounded := true
	var opaque := true
	var squished := false
	var stretched := false
	var recovered := false
	var peak_dim := 0.0
	var captured_squish := false
	var captured_release := false
	var remaining := 4.0
	while is_instance_valid(effect) and remaining > 0.0:
		grounded = grounded and effect._bin.position.is_equal_approx(ground)
		squished = squished or effect._bin.scale.y < effect._bin_scale.y * 0.8
		stretched = stretched or effect._bin.scale.y > effect._bin_scale.y * 1.1
		peak_dim = maxf(peak_dim, effect._dim.color.a)
		if effect._elapsed > effect._ANTICIPATION + 0.5:
			recovered = effect._dim.color.a < 0.01
		for icon in effect._spores:
			opaque = opaque and icon.modulate.a > 0.99
		if not captured_squish and effect._elapsed > 0.32:
			captured_squish = true
			await _snapshot(label + "-squish")
		if not captured_release and effect._elapsed > 0.95:
			captured_release = true
			await _snapshot(label + "-flight")
		await get_tree().process_frame
		remaining -= get_process_delta_time()
	_check(not is_instance_valid(effect) and not finished.is_empty(), label + " completes bounded release")
	_check(grounded and squished and stretched and opaque, label + " bin squishes at fixed ground and spores remain opaque")
	_check(peak_dim > 0.1 and recovered, label + " dims anticipation then recovers")
	if not finished.is_empty():
		for bounds: Rect2 in finished.bounds:
			_check(bounds.end.x < 0.0, label + " complete spore icon exits left")
	_check(not _colony._compost_bin._release_active and _colony._compost_release == null, label + " restores live bin")
	_check(Audio._reveal_audio_leases == 0 and is_equal_approx(Audio._reveal_music_gain, 1.0), label + " releases music duck")
	await _snapshot(label + "-restored")

func _cancel_presenter(kind: String, action: String) -> void:
	var effect: Control
	var unit: RosterUnitData
	if kind == "compost":
		var state := await _start_compost(true)
		effect = state.effect
		unit = state.unit
	elif kind == "cocoon":
		await _open()
		unit = _unit()
		unit.cocoon_duration_days = 0
		GameState.troop.try_add_unit(unit)
		_colony.on_screen_shown()
		_colony._open_pupation_confirm(unit, WeaponSchool.Id.BOW)
		await get_tree().process_frame
		(_colony._pupation_dialog.get_node("%ConfirmButton") as Button).pressed.emit()
		effect = await _await_cocoon()
	else:
		await _open()
		await _prepare_harvest(1, 7)
		_nursery._tiles[0].plot_pressed.emit(_nursery._tiles[0])
		effect = _nursery._hatch_reveal
	_check(is_instance_valid(effect), kind + " " + action + " has active effect")
	if not is_instance_valid(effect):
		return
	await _wait(0.45)
	var owned_sounds := effect.find_children("*", "AudioStreamPlayer", false, false)
	var window := get_window()
	var prior_size := window.size
	match action:
		"undo": _base._on_undo_pressed()
		"pause": (_base.get_node("RunMenu") as RunMenu).open_menu()
		"tab": _base._select_tab(_base.TabId.NURSERY, true)
		"resize": window.size = prior_size + Vector2i(24, 16)
		"exit": _base.queue_free()
	await _wait(0.4)
	_check(not is_instance_valid(effect), kind + " " + action + " removes owned visuals and dim")
	for sound in owned_sounds:
		_check(not is_instance_valid(sound), kind + " " + action + " frees owned cue")
	_check(Audio._reveal_audio_leases == 0 and is_equal_approx(Audio._reveal_music_gain, 1.0), kind + " " + action + " restores music")
	if action == "pause":
		(_base.get_node("RunMenu") as RunMenu).close_menu()
	if action == "resize":
		window.size = prior_size
		await _wait(0.1)
	if action != "exit":
		if kind == "compost":
			_check(not _colony._compost_bin._release_active, kind + " " + action + " restores bin")
			_check(GameState.troop.squad.has(unit) == (action == "undo"), kind + " " + action + " changes transaction only for Undo")
		elif kind == "cocoon":
			_check(unit.is_adult_stage() == (action != "undo"), kind + " " + action + " changes transaction only for Undo")
			var card := _colony._find_unit_card(unit)
			_check(card != null and card.modulate.a > 0.99, kind + " " + action + " restores target card")

func _audio() -> void:
	var bus := AudioServer.get_bus_index("Music")
	var bus_db := AudioServer.get_bus_volume_db(bus)
	var owner_one := Node.new()
	var owner_two := Node.new()
	add_child(owner_one)
	add_child(owner_two)
	Audio.acquire_reveal_audio(owner_one)
	Audio.acquire_reveal_audio(owner_two)
	await _wait(0.22)
	_check(is_equal_approx(Audio._reveal_music_gain, 0.07), "overlapping leases reach reveal music floor")
	owner_one.queue_free()
	await _wait(0.1)
	_check(Audio._reveal_audio_leases == 1 and is_equal_approx(Audio._reveal_music_gain, 0.07), "one owner cancellation preserves other duck")
	Audio.play_battle_music()
	await _wait(0.1)
	for player in Audio._music_levels:
		_check(is_equal_approx(player.volume_linear, Audio._music_levels[player] * Audio._reveal_music_gain), "crossfade and duck compose independently")
	owner_two.queue_free()
	await _wait(0.3)
	_check(is_equal_approx(Audio._reveal_music_gain, 1.0) and AudioServer.get_bus_volume_db(bus) == bus_db, "last owner restores music without changing Settings bus")
	Audio.play_base_music()

func _run() -> void:
	Analytics.ga = null
	get_window().mode = Window.MODE_WINDOWED
	await _wait(0.1)
	await _instant(false)
	await _instant(true)
	await _instant(true, true)
	await _delayed()
	await _open()
	for spec in [[1, 7], [6, 7], [6, 2], [1, 0]]:
		await _harvest(spec[0], spec[1])
	await _interruptions()
	await _audio()
	await _compost(true)
	await _compost(false)
	await _compost(true, true)
	for kind in ["cocoon", "compost"]:
		for action in ["undo", "pause", "tab", "resize", "exit"]:
			await _cancel_presenter(kind, action)
	await _cancel_presenter("egg", "resize")
	await _prepare_harvest(1, 7)
	_nursery._tiles[0].plot_pressed.emit(_nursery._tiles[0])
	await _wait(0.4)
	var effect := _nursery._hatch_reveal
	_base.queue_free()
	await _wait(0.4)
	_check(not is_instance_valid(effect) and Audio._reveal_audio_leases == 0 and is_equal_approx(Audio._reveal_music_gain, 1.0), "scene exit frees reveal and recovers music")
	print("UNIT_EMERGENCE_CHECKS failures=", _failures)
	get_tree().quit(1 if _failures else 0)
