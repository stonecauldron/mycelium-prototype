extends "res://.scratch/unit-emergence/runtime_check.gd"

## Focused real-scene reward presentation checks. Transactions commit before effects.
var _checks_count := 0
var _summary: Control
var _model_changes := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(120.0).timeout.connect(func() -> void: get_tree().quit(99))
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	_checks_count += 1
	super._check(ok, label)

func _snapshot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--visual"):
		return
	await RenderingServer.frame_post_draw
	var path := "/tmp/biomass-reward-%s.png" % label
	get_viewport().get_texture().get_image().save_png(path)
	print("SCREENSHOT ", path)

func _fresh_summary(amounts: Array[int]) -> void:
	await _clear_scene()
	GameState.reset_run()
	GameState.pending_seal_choice = false
	GameState.current_day = 2
	GameState.run_seed = 32145
	GameState.troop.seed_if_empty([_unit([WeaponSchool.Id.SWORD], true)])
	GameState.ensure_nursery_seeded()
	GameState.show_plot_plant_hint = false
	GameState.show_start_combat_hint = false
	GameState.biomass.amount = 7
	DaySummaryFeed.clear()
	DaySummaryFeed.set_combat_recap(38, 40, [{"unit": GameState.troop.squad[0], "dealt": 42, "taken": 2, "max_hp": 40, "order": 0}])
	for amount in amounts:
		GameState.biomass.add(amount)
		DaySummaryFeed.add_biomass_earned(amount)
	_model_changes = 0
	if not GameState.biomass.changed.is_connected(_on_model_changed):
		GameState.biomass.changed.connect(_on_model_changed)
	_summary = preload("res://assets/day_summary/day_summary.tscn").instantiate()
	get_tree().root.add_child(_summary)
	get_tree().current_scene = _summary

func _clear_scene() -> void:
	get_tree().paused = false
	if is_instance_valid(_summary):
		_summary.queue_free()
	if is_instance_valid(_base):
		_base.queue_free()
	await _wait(0.2)

func _on_model_changed() -> void:
	_model_changes += 1

func _await_gain(source_node: Node, field: String) -> Node:
	var timeout := 2.0
	while is_instance_valid(source_node) and timeout > 0.0:
		var gain := source_node.get(field) as Node
		if is_instance_valid(gain):
			return gain
		await get_tree().process_frame
		timeout -= get_process_delta_time()
	return null

func _displayed(counter: BiomassChip) -> int:
	return counter._amount.text.to_int()

func _sounds(effect: Node) -> Array[Node]:
	return effect.find_children("*", "AudioStreamPlayer", true, false)

func _sound_ownership(sounds: Array[Node], label: String) -> void:
	var freed := true
	for player in sounds:
		freed = freed and not is_instance_valid(player)
	_check(freed, label + " frees all owned reward sounds")

func _fresh_compost(adult: bool, bank: int = 0, starting_balance: int = 100) -> Dictionary:
	await _clear_scene()
	await _open()
	GameState.biomass.amount = starting_balance
	var unit := _unit([WeaponSchool.Id.BOW], adult)
	if bank > 0:
		unit.cap_mutation = load("res://assets/base/nursery/mutations/cap/bank.tres")
		unit.biomass_bank = bank
	GameState.troop.try_add_unit(unit)
	GameState.nursery.stock.clear()
	_colony.on_screen_shown()
	_colony._open_compost_confirm(unit)
	await get_tree().process_frame
	var payout := (8 if adult else 6) + bank
	var dialog := _colony._compost_dialog
	(dialog.get_node("%ConfirmButton") as Button).pressed.emit()
	(dialog.get_node("%ConfirmButton") as Button).pressed.emit()
	_check(GameState.biomass.amount == starting_balance + payout, "actual Compost credits stage plus Bank exactly once")
	_check(not GameState.troop.squad.has(unit) and not GameState.troop.bench.has(unit), "actual Compost removes only committed unit")
	var spores: Array[SporeData] = []
	for item in GameState.nursery.stock.slots:
		if item is SporeData:
			spores.append(item)
	_check(spores.size() == (1 if adult else 0), "actual Compost spore count preserved")
	return {"payout": payout, "unit": unit, "spores": spores, "release": _colony._compost_release, "counter": _base.get_node("%BiomassChip")}

func _observe_gain(effect: BiomassGain, counter: BiomassChip, amount: int, label: String) -> Dictionary:
	var result := {"finished": false, "count": 0, "text": "", "all_arrived": false}
	_check(is_instance_valid(effect), label + " starts shared presenter")
	if not is_instance_valid(effect):
		return result
	effect.finished.connect(_record_finished.bind(effect, result))
	result.count = effect._icons.size()
	_check(effect._amount == amount and effect._number.text == "+0", label + " starts counted label at0 for exact credit")
	_check(effect.mouse_filter == Control.MOUSE_FILTER_IGNORE, label + " presentation does not intercept input")
	var authoritative := GameState.biomass.amount
	var changes_before := _model_changes
	var previous_number := 0
	var previous_counter := _displayed(counter)
	var monotonic := true
	var counter_monotonic := true
	var model_unchanged := true
	var dropped := false
	var rose := false
	var max_growth := 0.0
	var max_counter_growth := 0.0
	var first_y := INF
	var drawn := false
	var sounds: Array[Node] = []
	var sfx_bus := true
	var observed_arrivals: Array[bool] = []
	observed_arrivals.resize(effect._icons.size())
	observed_arrivals.fill(false)
	var arrival_ok := true
	var max_arrival_distance := 0.0
	var previous_target := _counter_icon_bounds(counter)
	var timeout := 6.0
	var animation_start := Time.get_ticks_msec()
	var start_delay := effect._delay
	while is_instance_valid(effect) and not result.finished and timeout > 0.0:
		var number := effect._number.text.to_int()
		monotonic = monotonic and number >= previous_number and number <= amount
		previous_number = number
		var displayed := _displayed(counter)
		counter_monotonic = counter_monotonic and displayed >= previous_counter and displayed <= authoritative
		previous_counter = displayed
		model_unchanged = model_unchanged and GameState.biomass.amount == authoritative
		max_growth = maxf(max_growth, effect._gain_row.scale.x)
		max_counter_growth = maxf(max_counter_growth, counter._amount_row.scale.x)
		if effect._gain_row.visible:
			first_y = minf(first_y, effect._gain_row.position.y)
			dropped = dropped or effect._gain_row.position.y > first_y + 80.0
		var target := _counter_icon_bounds(counter)
		for i in effect._icons.size():
			var icon := effect._icons[i]
			if icon.visible:
				rose = rose or icon.position.y < effect._source.y - 40.0
			if effect._arrived[i] and not observed_arrivals[i]:
				observed_arrivals[i] = true
				var point := icon.get_global_transform_with_canvas().origin
				# The counter pulses on receipt. Check its painted target at arrival,
				# before/after that pulse, not its later neutral resting position.
				arrival_ok = arrival_ok and (previous_target.grow(2).has_point(point) or target.grow(2).has_point(point))
				max_arrival_distance = maxf(max_arrival_distance, minf(point.distance_to(target.get_center()), point.distance_to(previous_target.get_center())))
		previous_target = target
		for sound in _sounds(effect):
			if not sounds.has(sound):
				sounds.append(sound)
				sfx_bus = sfx_bus and (sound as AudioStreamPlayer).bus == &"SFX"
		if not drawn and effect._elapsed > effect._delay + 0.65:
			drawn = true
			await _snapshot(label + "-flight")
		await get_tree().process_frame
		timeout -= get_process_delta_time()
	var animation_seconds := float(Time.get_ticks_msec() - animation_start) / 1000.0
	_check(result.finished, label + " finishes without blocking")
	_check(animation_seconds < 2.2 + start_delay, label + " completes faster in under 2.2 seconds plus its start delay")
	_check(monotonic and result.text == BiomassDisplay.number(amount, true), label + " counts monotonically from0 to exact credit")
	_check(dropped and max_growth > 1.2, label + " label falls and visibly grows")
	_check(rose and result.all_arrived and arrival_ok and observed_arrivals.all(func(value: bool) -> bool: return value), label + " all biomass sprites arc upward into counter")
	_check(counter_monotonic and max_counter_growth > 1.08 and _displayed(counter) == authoritative, label + " counter animates to committed balance")
	_check(model_unchanged and _model_changes == changes_before, label + " animation never mutates currency")
	_check(not sounds.is_empty() and sfx_bus, label + " owned reward cues use SFX bus")
	var completion_stream := Sfx.SOUNDS[Sfx.Cue.BIOMASS_COMPLETE].stream as AudioStream
	await _wait(maxf(0.25, completion_stream.get_length() - BiomassGain._SETTLE_TIME + 0.1))
	_sound_ownership(sounds, label)
	print("GAIN_METRICS ", label, " amount=", amount, " sprites=", result.count, " label_scale=", max_growth, " counter_scale=", max_counter_growth, " final=", _displayed(counter), " max_arrival_distance=", max_arrival_distance, " seconds=", animation_seconds)
	return result

func _record_finished(effect: BiomassGain, result: Dictionary) -> void:
	result.finished = true
	result.text = effect._number.text
	result.all_arrived = effect._arrived.all(func(value: bool) -> bool: return value)

func _summary_rewards() -> void:
	var counts: Array[int] = []
	for total in [3, 60]:
		var amounts: Array[int] = [3]
		if total == 60:
			amounts = [20, 40]
		await _fresh_summary(amounts)
		_check(_displayed(_summary._biomass_counter) == 7, "summary starts at pre-award balance without a flash")
		var amount := 0
		for part in amounts:
			amount += part
		var effect := await _await_gain(_summary, "_biomass_gain") as BiomassGain
		var result := await _observe_gain(effect, _summary._biomass_counter, amount, "summary-%d" % amount)
		counts.append(int(result.count))
		_check(is_instance_valid(effect) and effect._gain_row.visible and effect._number.text == BiomassDisplay.number(amount, true), "summary keeps final award label readable")
		_check(_summary._biomass_reward_amount == amount, "summary uses numeric aggregate reward")
		await _snapshot("summary-%d-complete" % amount)
	_check(counts[1] > counts[0] and counts[0] > 0, "larger reward emits more biomass sprites")
	await _fresh_summary([0])
	await _wait(0.6)
	_check(not is_instance_valid(_summary._biomass_gain) and _summary._biomass_reward_source == null, "zero reward has no false gain animation")
	_check(_displayed(_summary._biomass_counter) == 7 and _model_changes == 0, "zero reward displays actual unchanged balance")

func _summary_exit() -> void:
	await _fresh_summary([20])
	var effect := await _await_gain(_summary, "_biomass_gain") as BiomassGain
	await _wait(0.3)
	var sounds := _sounds(effect)
	_summary.queue_free()
	await _wait(0.2)
	_check(not is_instance_valid(effect), "summary exit frees active reward presenter")
	_sound_ownership(sounds, "summary exit")
	_check(GameState.biomass.amount == 27 and _model_changes == 0, "summary exit retains committed reward without another credit")

func _summary_click(mode: String) -> void:
	var amount := 20
	if mode == "zero":
		amount = 0
	await _fresh_summary([amount])
	if mode == "pending-continue":
		_summary._biomass_delay_left = 1.0 # Keep the pending branch stable through native input dispatch.
	var effect: BiomassGain
	var sounds: Array[Node] = []
	var signal_counts := {"finished": 0, "cancelled": 0}
	if mode != "pending-continue" and mode != "zero":
		effect = await _await_gain(_summary, "_biomass_gain") as BiomassGain
		effect.finished.connect(func() -> void: signal_counts.finished += 1)
		effect.cancelled.connect(func() -> void: signal_counts.cancelled += 1)
		if mode == "finished":
			while not effect.is_finished():
				await get_tree().process_frame
		else:
			await _wait(0.45)
			sounds = _sounds(effect)
	else:
		await get_tree().process_frame
		await get_tree().process_frame
	var button := _summary.get_node("%ContinueButton") as Button
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	var mouse_button := MOUSE_BUTTON_LEFT
	if mode == "mid-background" or mode == "mid-right":
		point = Vector2(1800, 400)
		if mode == "mid-right":
			mouse_button = MOUSE_BUTTON_RIGHT
	elif mode == "mid-label":
		var label := _summary.get_node("%Title") as Control
		point = label.get_global_transform_with_canvas() * (label.size * 0.5)
	var expects_skip := mode in ["mid-background", "mid-label", "mid-right"]
	if mode != "finished" and mode != "zero":
		_check(is_instance_valid(effect) or _summary._biomass_pending_token > 0, mode + " begins while reward is pending")
	if mode == "mid-touch":
		var old_emulation := Input.emulate_mouse_from_touch
		Input.emulate_mouse_from_touch = true
		for pressed in [true, false]:
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.position = get_viewport().get_final_transform() * point
			touch.pressed = pressed
			Input.parse_input_event(touch)
			await get_tree().process_frame
		Input.emulate_mouse_from_touch = old_emulation
	elif mode == "mid-keyboard":
		button.grab_focus()
		for pressed in [true, false]:
			var key := InputEventKey.new()
			key.keycode = KEY_ENTER
			key.pressed = pressed
			Input.parse_input_event(key)
			await get_tree().process_frame
	else:
		await _mouse_click(point, mouse_button)
	if expects_skip:
		_check(is_instance_valid(_summary) and get_tree().current_scene == _summary and not _summary._continuing, mode + " first click is consumed without advancing")
		if not is_instance_valid(_summary):
			return
		_check(_displayed(_summary._biomass_counter) == 27 and _summary._biomass_counter._gain_total == 0, mode + " immediately displays exact final balance")
		if is_instance_valid(effect):
			_check(effect.is_finished() and effect._icons.all(func(icon: Sprite2D) -> bool: return not icon.visible), mode + " immediately finishes and hides all particles")
			_check(signal_counts.finished == 1 and signal_counts.cancelled == 0, mode + " emits finished once without cancellation")
			_check(effect._number.text == "+20" and effect._gain_row.visible, mode + " retains final reward label")
			var sound_stopped := true
			for sound in sounds:
				sound_stopped = sound_stopped and (not is_instance_valid(sound) or not (sound as AudioStreamPlayer).playing)
			_check(sound_stopped, mode + " stops active reward sounds immediately")
			effect.finish_immediately()
			_check(signal_counts.finished == 1, mode + " repeated finishing is idempotent")
		else:
			var source := _summary._biomass_reward_source as Control
			var captions := source.find_children("*", "Label", true, false)
			_check(captions.size() == 1 and (captions[0] as Label).text == "+20", mode + " pending skip retains one final award")
		await _wait(0.2)
		_check(GameState.biomass.amount == 27 and _model_changes == 0, mode + " never credits twice")
		if mode == "mid-background":
			await _snapshot("background-finished")
		await _mouse_click(button.get_global_transform_with_canvas() * (button.size * 0.5))
	else:
		_check(is_instance_valid(_summary) and _summary._continuing and SceneTransition.is_transitioning(), mode + " first Continue activation immediately starts advancing")
	await _wait(0.1)
	var timeout := 3.0
	while SceneTransition.is_transitioning() and timeout > 0.0:
		await get_tree().process_frame
		timeout -= get_process_delta_time()
	_base = get_tree().current_scene as Node2D
	_check(is_instance_valid(_base) and _base.scene_file_path == "res://assets/base/base.tscn", mode + " Continue reaches Base")
	_check(GameState.biomass.amount == 7 + amount and _model_changes == 0, mode + " leaves the authoritative credit unchanged")
	_check(not is_instance_valid(effect), mode + " leaving summary frees retained presenter")
	_sound_ownership(sounds, mode)

func _mouse_click(point: Vector2, mouse_button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	get_viewport().warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_final_transform() * point
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = get_viewport().get_final_transform() * point
		event.global_position = event.position
		event.button_index = mouse_button
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame

func _compost_reward(adult: bool, bank: int) -> void:
	var state := await _fresh_compost(adult, bank)
	var release := state.release as CompostRelease
	var effect := _colony._compost_gain
	_check(is_instance_valid(release) and is_instance_valid(effect), "Compost runs gain alongside bin release")
	if not is_instance_valid(release) or not is_instance_valid(effect):
		return
	_check(release._spores.size() == state.spores.size(), "Compost release retains exact created spores")
	for i in release._spores.size():
		_check(release._spores[i].get_meta("spore") == state.spores[i], "Compost release preserves actual spore identity")
	var label := "compost-bank" if bank > 0 else ("compost-adult" if adult else "compost-child")
	await _observe_gain(effect, state.counter, state.payout, label)
	_check(not is_instance_valid(release) and not _colony._compost_bin._release_active, label + " normal bin release completes and restores art")
	_check(GameState.biomass.amount == 100 + int(state.payout), label + " no repeated transaction on finish")

func _compost_cancel(action: String) -> void:
	var state := await _fresh_compost(true)
	var effect := _colony._compost_gain
	var counter := state.counter as BiomassChip
	await _wait(0.85)
	var sounds := _sounds(effect)
	var window := get_window()
	var prior_size := window.size
	match action:
		"pause": (_base.get_node("RunMenu") as RunMenu).open_menu()
		"tab": _base._select_tab(_base.TabId.NURSERY, true)
		"resize": window.size = prior_size + Vector2i(24, 16)
		"exit": _base.queue_free()
	await _wait(0.3)
	_check(not is_instance_valid(effect), "Compost " + action + " cancels gain visuals")
	_sound_ownership(sounds, "Compost " + action)
	_check(GameState.biomass.amount == 108, "Compost " + action + " preserves committed credit")
	if action != "exit":
		_check(_displayed(counter) == 108 and counter._gain_total == 0
			and counter._paper.scale.is_equal_approx(Vector2.ONE) and counter._amount_row.scale.is_equal_approx(Vector2.ONE), "Compost " + action + " restores neutral actual counter")
		_check(not _colony._compost_bin._release_active, "Compost " + action + " restores normal bin")
	if action == "pause":
		(_base.get_node("RunMenu") as RunMenu).close_menu()
	if action == "resize":
		window.size = prior_size
		await _wait(0.1)

func _purchase_during_gain() -> void:
	var state := await _fresh_compost(false, 0, 1)
	var effect := _colony._compost_gain
	var counter := state.counter as BiomassChip
	await _wait(0.55)
	_check(_displayed(counter) == 1 and GameState.biomass.amount == 7, "pending Child credit is cosmetic while7 is spendable")
	var fertilizer := preload("res://assets/base/nursery/fertilizers/finesse.tres")
	_check(GameState.try_buy_fertilizer(fertilizer, fertilizer.biomass_cost), "authoritative purchase can spend credited balance")
	_check(GameState.biomass.amount == 5 and _displayed(counter) == 5, "purchase immediately shows new balance without negative stale replay")
	await _wait(0.2)
	_check(not is_instance_valid(effect) and counter._gain_total == 0, "purchase cancels superseded gain presentation")
	await _wait(1.0)
	_check(_displayed(counter) == 5 and GameState.nursery.stock.slots.has(fertilizer), "purchase remains committed after old animation end")

func _summary_resize() -> void:
	await _fresh_summary([12])
	var effect := await _await_gain(_summary, "_biomass_gain") as BiomassGain
	await _wait(0.45)
	var window := get_window()
	var previous := window.size
	window.size = previous + Vector2i(24, 16)
	await _wait(0.3)
	_check(not is_instance_valid(effect) and _displayed(_summary._biomass_counter) == 19, "summary resize cancels flight and restores actual total")
	var fallback := _summary._biomass_reward_source as Control
	var captions := fallback.find_children("*", "Label", true, false)
	_check(captions.size() == 1 and (captions[0] as Label).text == "+12", "summary resize keeps one readable final reward fallback")
	window.size = previous
	await _wait(0.2)
	_check(fallback.find_children("*", "Label", true, false).size() == 1, "repeated resize does not duplicate fallback label")

func _run() -> void:
	Analytics.ga = null
	get_viewport().warp_mouse(Vector2(4, 4))
	await _fresh_summary([0])
	await _wait(1.0)
	if OS.get_cmdline_user_args().has("--continue-only"):
		for mode in ["pending-continue", "mid-continue", "mid-keyboard", "mid-touch", "mid-background"]:
			await _summary_click(mode)
		await _clear_scene()
		print("BIOMASS_CONTINUE checks=", _checks_count, " failures=", _failures)
		get_tree().quit(_failures)
		return
	await _summary_rewards()
	for mode in ["pending-continue", "mid-background", "mid-label", "mid-continue", "mid-right", "mid-keyboard", "mid-touch", "finished", "zero"]:
		await _summary_click(mode)
	await _summary_exit()
	await _summary_resize()
	if OS.get_cmdline_user_args().has("--summary-only"):
		await _compost_reward(false, 0)
		await _clear_scene()
		print("BIOMASS_SUMMARY_CLICK checks=", _checks_count, " failures=", _failures)
		get_tree().quit(_failures)
		return
	await _compost_reward(false, 0)
	await _compost_reward(true, 0)
	await _compost_reward(true, 30)
	for action in ["pause", "tab", "resize", "exit"]:
		await _compost_cancel(action)
	await _purchase_during_gain()
	await _clear_scene()
	print("BIOMASS_REWARD checks=", _checks_count, " failures=", _failures)
	get_tree().quit(_failures)

func _counter_icon_bounds(counter: BiomassChip) -> Rect2:
	var icon := counter.get_node("Paper/BiomassChip/InfoFrame/InfoVBox/AmountRow/Icon") as Control
	return icon.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, icon.size)
