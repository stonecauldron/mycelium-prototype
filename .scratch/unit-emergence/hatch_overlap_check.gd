extends "res://.scratch/unit-emergence/runtime_check.gd"

func _run() -> void:
	Analytics.ga = null
	var guided_preference := SettingsServer.guided_run_enabled
	SettingsServer.guided_run_enabled = false
	await _open()
	await _prepare_pair()
	await _click_plot(0)
	var first := _latest_hatch()
	_check(is_instance_valid(first), "first GUI click starts hatch")
	await _wait(0.6)
	await _click_plot(1)
	var second := _latest_hatch()
	_check(is_instance_valid(second) and second != first, "second GUI click starts another hatch through the result card")
	_check(_nursery._hatch_reveals.size() == 2 and is_instance_valid(first) and not first._done, "both hatch animations overlap")
	_check(_count() == 3, "both harvests commit exactly once")
	_check(_nursery._hatch_toasts.size() == 1 and _nursery._hatch_toasts[0].unit_data == second._actors[0].get_meta("unit"), "latest hatch owns immediate result card")
	_check(_nursery._hatch_toasts[0].scale.is_equal_approx(Vector2.ONE), "result card retains original size")
	_nursery._tiles[1].plot_pressed.emit(_nursery._tiles[1])
	_check(_count() == 3 and _nursery._hatch_reveals.size() == 2, "repeat click on harvested Plot cannot duplicate units")
	while is_instance_valid(first):
		await get_tree().process_frame
	_check(is_instance_valid(second) and _nursery._hatch_reveals.size() == 1, "first completion leaves second hatch running")
	while is_instance_valid(second):
		await get_tree().process_frame
	_check(_nursery._hatch_reveals.is_empty(), "both completions retire their own animations")
	await _prepare_pair()
	await _click_plot(0)
	first = _latest_hatch()
	await _click_plot(1)
	second = _latest_hatch()
	first.cancel()
	_check(_nursery._hatch_reveals.size() == 1 and _nursery._hatch_toasts.size() == 1, "cancelling earlier hatch preserves latest animation and card")
	_nursery.dismiss_hatch_results()
	_check(second._done and _nursery._hatch_reveals.is_empty() and _nursery._hatch_toasts.is_empty(), "dismissal cancels all remaining presentation")
	await _prepare_pair()
	await _click_plot(0)
	first = _latest_hatch()
	await _click_plot(1)
	second = _latest_hatch()
	_base._on_undo_pressed()
	_check(first._done and second._done and _nursery._hatch_reveals.is_empty(), "Undo cancels every concurrent hatch")
	_check(_count() == 2 and (GameState.nursery.plots[1] as NurseryPlotData).can_harvest(), "Undo reverses only latest harvest")
	await _prepare_pair()
	await _click_plot(0)
	first = _latest_hatch()
	await _click_plot(1)
	second = _latest_hatch()
	_base._select_tab(_base.TabId.COLONY, true)
	_check(first._done and second._done and _nursery._hatch_reveals.is_empty(), "tab departure cancels every concurrent hatch")
	_check(_count() == 3, "tab cancellation preserves committed harvests")
	await _interruptions()
	SettingsServer.guided_run_enabled = guided_preference
	_base.queue_free()
	await _wait(0.1)
	print("HATCH_OVERLAP_CHECKS failures=", _failures)
	get_tree().quit(1 if _failures else 0)

func _prepare_pair() -> void:
	await _prepare_harvest(1, 7)
	GameState.nursery.unlocked_plot_count = 2
	_nursery._build_plot_tiles()
	var plot := GameState.nursery.plots[1] as NurseryPlotData
	plot.clear()
	plot.planted_spore = SporeData.new()
	plot.remaining_time = 0
	_nursery._refresh()
	await _wait(0.1)

func _click_plot(index: int) -> void:
	var egg := _nursery._tiles[index].get_node("%EggVisual") as Control
	var click := InputEventMouseButton.new()
	click.position = egg.get_global_transform_with_canvas() * (egg.size * 0.5)
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	get_viewport().push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	get_viewport().push_input(click, true)
	await get_tree().process_frame
