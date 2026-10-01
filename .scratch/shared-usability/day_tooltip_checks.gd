extends "res://.scratch/shared-usability/elite_preview_checks.gd"

## Focused lifetime regression; uses real pointer/key input and inspects visible cards.
func _run() -> void:
	Analytics.ga = null
	GameState.reset_run()
	GameState.current_day = 2
	GameState.pending_seal_choice = false
	GameState.troop.seed_if_empty(StarterPackages.build_units(&"great_sword_spear"))
	base = preload("res://assets/base/base.tscn").instantiate()
	get_tree().root.add_child(base)
	get_tree().current_scene = base
	colony = base.get_node("%ColonyScreen") as TroopSelectionScreen
	scout = colony.get_node("ScoutBubble") as ScoutBubble
	track = colony.get_node("HeaderBlock/CombatProgressTrack") as CombatProgressTrack
	await _settle()
	var normal := track.get_node("Node4") as Button
	await _move(Vector2(4, 4))
	await _hover(normal)
	_check(_visible_day_tooltip(4), "ordinary hover shows native Day tooltip")
	await _move(Vector2(4, 4))
	_check(not _visible_day_tooltip(4), "ordinary pointer exit clears Day tooltip")

	# Stay below the configured 100ms hover delay, then immediately leave.
	var quick_started := Time.get_ticks_msec()
	await _point_now(normal.get_global_transform_with_canvas() * (normal.size * 0.5))
	await _click_now(normal)
	_check(Time.get_ticks_msec() - quick_started < 100, "quick click occurs before native hover delay")
	await _move(Vector2(4, 4))
	_check(normal.has_focus() and scout.focused_day() == 4, "quick click focuses and pins normal Day")
	_check(not _visible_day_tooltip(4) and not normal.has_node("FocusTooltipLease"),
		"quick click then leave has no persistent focus tooltip")
	await _snapshot("tooltip-quick-click-left")

	scout.return_to_next_battle()
	normal.release_focus()
	await _hover(normal)
	_check(_visible_day_tooltip(4), "delayed hover shows Day tooltip before click")
	await _click_now(normal)
	await _move(Vector2(4, 4))
	_check(scout.focused_day() == 4 and not _visible_day_tooltip(4),
		"delayed hover click then leave clears tooltip and preserves pin")
	await _hover(normal)
	_check(_visible_day_tooltip(4), "rehovering a focused Day still shows native tooltip")
	await _move(Vector2(4, 4))
	_check(not _visible_day_tooltip(4) and scout.focused_day() == 4,
		"rehover exit clears tooltip without changing selection")

	scout.return_to_next_battle()
	(track.get_node("Node3") as Control).grab_focus()
	await _key(KEY_TAB)
	_check(normal.has_focus() and _visible_day_tooltip(4) and normal.has_node("FocusTooltipLease"),
		"real Tab navigation creates the keyboard Day tooltip")
	await _key(KEY_SPACE)
	_check(scout.focused_day() == 4 and _visible_day_tooltip(4), "Space pins and keeps keyboard tooltip")
	await _snapshot("tooltip-keyboard-focus")
	await _move(Vector2(8, 8))
	_check(normal.has_focus() and scout.focused_day() == 4 and not _visible_day_tooltip(4)
		and not normal.has_node("FocusTooltipLease"),
		"mouse interaction dismisses keyboard tooltip without releasing focus or pin")
	await _snapshot("tooltip-keyboard-to-mouse")
	print("DAY_TOOLTIP_CHECKS failures=", failures)
	get_tree().quit(failures)


func _point_now(point: Vector2) -> void:
	get_viewport().warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_final_transform() * point
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await get_tree().process_frame


func _click_now(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = get_viewport().get_final_transform() * point
		event.global_position = event.position
		Input.parse_input_event(event)
		await get_tree().process_frame


func _visible_day_tooltip(day: int) -> bool:
	var overlay := DetailTooltipPopup._instance
	if not is_instance_valid(overlay):
		return false
	# Include fading cards, so clearing only the manager pointer cannot hide a failure.
	for tip: Control in overlay._host.get_children():
		if not tip.is_visible_in_tree() or tip.modulate.a <= 0.01:
			continue
		for label: Label in tip.find_children("*", "Label", true, false):
			if label.text == "Day %d" % day:
				return true
	return false
