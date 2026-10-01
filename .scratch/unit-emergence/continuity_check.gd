extends "res://.scratch/unit-emergence/runtime_check.gd"

var _observed: Array[RosterUnitData] = []
var _samples: Array[Dictionary] = []
var _assertions := 0

func _baseline() -> void:
	Analytics.ga = null
	await _open()
	var emerging := _unit([WeaponSchool.Id.BOW], true)
	emerging.display_name = "Emerging"
	var squad_neighbor := _unit([WeaponSchool.Id.SWORD], true)
	squad_neighbor.display_name = "Unrelated Squad"
	var bench_neighbor := _unit([WeaponSchool.Id.SPEAR], true)
	bench_neighbor.display_name = "Unrelated Bench"
	GameState.troop.squad.fill(null)
	GameState.troop.bench.fill(null)
	GameState.troop.squad[0] = emerging
	GameState.troop.squad[1] = squad_neighbor
	GameState.troop.bench[0] = bench_neighbor
	_observed = [squad_neighbor, bench_neighbor]
	_colony.on_screen_shown()
	await _wait(0.5)
	var before_action := _states()
	_colony._on_pupation_confirmed(emerging, WeaponSchool.Id.MACE)
	var before := _states()
	print("CONTINUITY_BEFORE_ACTION ", JSON.stringify(before_action))
	print("CONTINUITY_QUEUED ", JSON.stringify(before))
	_check(GameState.pending_cocoon_emergences.size() == 1, "actual Training queues one emergence")
	var effect := await _await_cocoon()
	_check(is_instance_valid(effect), "queued Cocoon starts actual presenter")
	if not is_instance_valid(effect):
		get_tree().quit(2)
		return
	var during := _states()
	print("CONTINUITY_DURING ", JSON.stringify(during))
	for i in _observed.size():
		_check(before[i].card == during[i].card and before[i].portrait == during[i].portrait,
			"unrelated unit%d keeps card and portrait when reveal starts" % i)
	_check(_colony._squad_slots.all(func(slot: DropSlot) -> bool: return slot.accepts_drops)
		and _colony._bench_slots.all(func(slot: DropSlot) -> bool: return slot.accepts_drops), "formation drops remain enabled during emergence")
	_check(_colony._squad_slots[2]._can_drop_data(Vector2.ZERO, {"source": "bench", "unit": bench_neighbor}), "unrelated unit can target free formation slot during emergence")
	_check(_colony.can_start_combat(), "combat remains startable during cosmetic emergence")
	_check(not _base._start_combat_button.disabled, "Start Battle button remains enabled during cosmetic emergence")
	_check(effect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "presenter itself does not intercept mouse input")
	var last_tick := Time.get_ticks_usec()
	var max_frame_ms := 0.0
	var remaining := 5.0
	while is_instance_valid(effect) and remaining > 0:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var frame_ms := float(now - last_tick) / 1000.0
		max_frame_ms = maxf(max_frame_ms, frame_ms)
		last_tick = now
		_samples.append({"ms": frame_ms, "active": is_instance_valid(_colony._emergence), "units": _states()})
		remaining -= get_process_delta_time()
	await get_tree().process_frame
	var after := _states()
	print("CONTINUITY_AFTER ", JSON.stringify(after))
	for i in _observed.size():
		_check(during[i].card == after[i].card and during[i].portrait == after[i].portrait,
			"unrelated unit%d keeps card and portrait when reveal finishes" % i)
	var trace := FileAccess.open("/tmp/cocoon-continuity-frames.json", FileAccess.WRITE)
	trace.store_string(JSON.stringify({"before_action": before_action, "queued": before, "during": during, "after": after, "frames": _samples}, "\t"))
	trace.close()
	print("CONTINUITY_TIMING frames=", _samples.size(), " max_frame_ms=", max_frame_ms, " (diagnostic, no timing assertion)")
	_base.queue_free()
	await _wait(0.25)

func _states() -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for unit in _observed:
		var card := _colony._find_unit_card(unit)
		var actor := card._portrait_instance as UnitAppearance
		values.append({"name": unit.display_name, "card": card.get_instance_id(), "portrait": actor.get_instance_id(),
			"animation": str(actor.animation_player.current_animation), "phase": actor.animation_player.current_animation_position,
			"length": actor.animation_player.current_animation_length})
	return values


func _run() -> void:
	await _baseline()
	await _unrelated_move()
	await _target_swap()
	await _reuse_and_queue()
	await _pending_school_reuse()
	await _unlock()
	for action in ["pause", "tab", "undo"]:
		await _cleanup(action)
	await _battle_launch()
	print("COCOON_CONTINUITY_CHECKS assertions=", _assertions, " failures=", _failures)
	get_tree().quit(_failures)


func _fresh_reveal() -> Dictionary:
	await _open()
	var unit := _unit([WeaponSchool.Id.BOW], true)
	var squad_neighbor := _unit([WeaponSchool.Id.SWORD], true)
	var bench_neighbor := _unit([WeaponSchool.Id.SPEAR], true)
	GameState.troop.squad.fill(null)
	GameState.troop.bench.fill(null)
	GameState.troop.squad[0] = unit
	GameState.troop.squad[1] = squad_neighbor
	GameState.troop.bench[0] = bench_neighbor
	_colony.on_screen_shown()
	await _wait(0.15)
	_colony._on_pupation_confirmed(unit, WeaponSchool.Id.MACE)
	var effect := await _await_cocoon()
	_check(is_instance_valid(effect), "interaction begins with actual queued emergence")
	return {"unit": unit, "squad": squad_neighbor, "bench": bench_neighbor, "effect": effect}


func _drop_unit(unit: RosterUnitData, source: DropSlot, destination: DropSlot, source_name: String) -> void:
	var data := {"unit": unit, "source": source_name, "slot": source}
	_check(destination._can_drop_data(Vector2.ZERO, data), "real DropSlot accepts unrelated unit payload")
	# Use the DropSlot's regular signal route into TroopSelectionScreen/model logic.
	destination._drop_data(Vector2.ZERO, data)


func _unrelated_move() -> void:
	var state := await _fresh_reveal()
	var effect := state.effect as UnitEmergence
	_drop_unit(state.bench, _colony._bench_slots[0], _colony._squad_slots[2], "bench")
	_check(GameState.troop.squad[2] == state.bench and GameState.troop.bench[0] == null, "unrelated move commits during emergence")
	_check(_colony._emergence == effect and not effect._done, "unrelated move leaves current flight running")
	var card := _colony._find_unit_card(state.unit)
	_check(card != null and card.modulate.a == 0.0, "unrelated move keeps landing target hidden")
	await effect.finished
	await get_tree().process_frame
	_check(is_instance_valid(card) and _colony._find_unit_card(state.unit) == card and card.modulate.a == 1.0, "natural finish reveals retained target after unrelated move")


func _target_swap() -> void:
	var state := await _fresh_reveal()
	var effect := state.effect as UnitEmergence
	_drop_unit(state.bench, _colony._bench_slots[0], _colony._squad_slots[0], "bench")
	_check(_colony._emergence == null and effect._done, "swapping occupied landing slot cancels cosmetic flight immediately")
	_check(GameState.troop.bench[0] == state.unit and GameState.troop.squad[0] == state.bench, "target swap keeps committed unit identities")
	_check(_colony._find_unit_card(state.unit).modulate.a == 1.0, "swapped destination card is restored")
	await _wait(0.35)
	_check(not is_instance_valid(effect) and Audio._reveal_audio_leases == 0, "target swap removes owned effect and audio")


func _reuse_and_queue() -> void:
	var state := await _fresh_reveal()
	_colony._on_pupation_confirmed(state.squad, WeaponSchool.Id.BOW)
	_check(GameState.pending_cocoon_emergences.size() == 1, "second committed Training waits while first flight plays")
	var slot := _school(WeaponSchool.Id.MACE)
	_colony._on_cocoon_drop(slot, {"unit": state.bench, "source": "bench"})
	_check(_colony._emergence == null and is_instance_valid(_colony._pupation_dialog), "reusing active Cocoon cancels flight and opens Training")
	_check(_colony._find_unit_card(state.unit).modulate.a == 1.0, "Cocoon reuse restores first result")
	await _wait(0.1)
	_check(_colony._emergence == null and GameState.pending_cocoon_emergences.size() == 1, "pending second result waits for confirmation to close")
	(_colony._pupation_dialog.get_node("%CloseButton") as Button).pressed.emit()
	var second := await _await_cocoon()
	_check(is_instance_valid(second) and _colony._revealing_unit == state.squad, "second queued result resumes after cancellation and dialog close")
	_check(GameState.pending_cocoon_emergences.is_empty(), "second queue entry consumed once")
	_colony._cancel_emergence()
	await _wait(0.1)
	_check(_colony._find_unit_card(state.squad).modulate.a == 1.0, "second cancellation restores target")


func _pending_school_reuse() -> void:
	var state := await _fresh_reveal()
	_colony._on_pupation_confirmed(state.squad, WeaponSchool.Id.SWORD)
	_check(GameState.pending_cocoon_emergences.size() == 1, "instant second result is pending for reused school")
	var child := _unit()
	child.cocoon_duration_days = 1
	GameState.troop.bench[1] = child
	_colony._sync_all_slots()
	_colony._on_pupation_confirmed(child, WeaponSchool.Id.SWORD)
	_check(GameState.pending_cocoon_emergences.is_empty(), "new delayed Training retires old pending result for its school")
	_check(_colony._emergence == state.effect and not state.effect._done, "reusing pending school preserves unrelated current flight")
	_check(_school(WeaponSchool.Id.SWORD).get_occupant() == child, "new delayed Child remains in reused Cocoon")
	_check(_colony._find_unit_card(state.squad).modulate.a == 1.0, "skipped old result becomes visible immediately")
	await (state.effect as UnitEmergence).finished
	await _wait(0.1)
	_check(_colony._emergence == null and _school(WeaponSchool.Id.SWORD).get_occupant() == child, "old pending reveal cannot hide or replace the new Cocoon occupant")


func _unlock() -> void:
	var state := await _fresh_reveal()
	var count := GameState.troop.unlocked_squad_count
	var before := GameState.biomass.amount
	var cost := GameState.troop.next_squad_unlock_cost()
	_colony._on_squad_unlock_pressed(_colony._squad_unlock_slot)
	_check(GameState.troop.unlocked_squad_count == count + 1 and GameState.biomass.amount == before - cost, "unlock works and charges once during emergence")
	_check(_colony._emergence == null and _colony._find_unit_card(state.unit).modulate.a == 1.0, "unlock cancels outdated flight and restores destination")


func _cleanup(action: String) -> void:
	var state := await _fresh_reveal()
	var effect := state.effect as UnitEmergence
	await _wait(0.45)
	var sounds := effect.find_children("*", "AudioStreamPlayer", false, false)
	match action:
		"pause": (_base.get_node("RunMenu") as RunMenu).open_menu()
		"tab": _base._select_tab(_base.TabId.NURSERY, true)
		"undo": _base._on_undo_pressed()
	await _wait(0.4)
	_check(not is_instance_valid(effect) and _colony._emergence == null, action + " clears effect and dim")
	for sound in sounds:
		_check(not is_instance_valid(sound), action + " frees owned cue")
	_check(Audio._reveal_audio_leases == 0 and is_equal_approx(Audio._reveal_music_gain, 1.0), action + " releases and recovers music")
	_check(_colony._find_unit_card(state.unit).modulate.a == 1.0, action + " restores landing card")
	var expected: Array[int] = [WeaponSchool.Id.BOW, WeaponSchool.Id.MACE]
	if action == "undo":
		expected = [WeaponSchool.Id.BOW]
	_check(state.unit.weapon_trainings == expected, action + " preserves committed Training unless explicitly undone")
	if action == "pause":
		(_base.get_node("RunMenu") as RunMenu).close_menu()
	elif action == "tab":
		_base._select_tab(_base.TabId.COLONY, true)
	await _wait(0.1)
	_check(_colony._emergence == null and GameState.pending_cocoon_emergences.is_empty(), action + " does not replay consumed presentation")


func _battle_launch() -> void:
	var state := await _fresh_reveal()
	_colony._on_pupation_confirmed(state.squad, WeaponSchool.Id.BOW)
	_check(_colony.can_start_combat() and not _base._start_combat_button.disabled, "Battle remains available with active and pending results")
	_base._start_combat_button.pressed.emit()
	_check(SceneTransition.is_transitioning() and _colony._emergence == null, "Start Battle input starts transition and cancels flight")
	_check(GameState.pending_cocoon_emergences.is_empty() and not GameState.base_undo.can_undo(), "Battle clears pending presentation replay and Base Undo")
	await _wait(0.9)
	_check(not is_instance_valid(state.effect) and not is_instance_valid(_base), "Battle transition disposes Base and its owned reveal")
	_check(GameState.pending_cocoon_emergences.is_empty() and Audio._reveal_audio_leases == 0, "Battle starts without pending reveal or audio ownership")


func _school(school: int) -> CocoonSlot:
	for slot: CocoonSlot in _colony._cocoon_slots:
		if slot.school == school:
			return slot
	return null


func _check(ok: bool, label: String) -> void:
	_assertions += 1
	super._check(ok, label)
