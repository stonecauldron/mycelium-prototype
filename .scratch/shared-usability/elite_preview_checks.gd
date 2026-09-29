extends Node

var failures: int = 0
var base: Node
var scout: ScoutBubble
var track: CombatProgressTrack
var colony: TroopSelectionScreen


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	Analytics.ga = null
	GameState.reset_run()
	GameState.run_seed = 42123
	GameState.current_day = 2
	GameState.pending_seal_choice = false
	GameState.troop.seed_if_empty(StarterPackages.build_units(&"great_sword_spear"))
	GameState.biomass.amount = 100
	base = preload("res://assets/base/base.tscn").instantiate()
	get_tree().root.add_child(base)
	get_tree().current_scene = base
	colony = base.get_node("%ColonyScreen") as TroopSelectionScreen
	scout = colony.get_node("ScoutBubble") as ScoutBubble
	track = colony.get_node("HeaderBlock/CombatProgressTrack") as CombatProgressTrack
	await get_tree().create_timer(0.8).timeout
	for upcoming in [3, 8]:
		await _set_day(upcoming)
		await _future_elite(upcoming, 5 if upcoming == 3 else 10)
	for upcoming in [5, 10]:
		await _set_day(upcoming)
		await _current_elite(upcoming)
	print("ELITE_PREVIEW_CHECKS failures=", failures)
	get_tree().quit(failures)


func _set_day(upcoming: int) -> void:
	await _move(Vector2(4, 4))
	GameState.current_day = upcoming - 1
	GameState.clear_upcoming_enemy_formation()
	GameState.reset_scout_reroll_cost()
	base._select_tab(base.TabId.COLONY, true)
	base._refresh_hud()
	await _settle()
	_check(scout.focused_elite_day() == 0, "Day/chapter refresh clears pinned preview")


func _future_elite(upcoming: int, elite_day: int) -> void:
	var reroll := scout.get_node("%ScoutRerollButton") as Button
	var before_purchase := GameState.biomass.amount
	var cost := GameState.current_scout_reroll_cost()
	await _click(reroll)
	_check(GameState.biomass.amount == before_purchase - cost and GameState.scout_rerolls_today == 1,
		"paid Scout reroll creates the cached upcoming army")
	var cached := GameState.upcoming_enemy_formation.duplicate()
	var balance := GameState.biomass.amount
	var launch_before := BattleLaunch.enemy_roster.duplicate()
	var reward := (scout.get_node("%ScoutRewardLabel") as Label).text
	var reroll_label := (scout.get_node("%ScoutRerollCostLabel") as Label).text
	var elite_specs := EnemyComposer.specs_for_day(elite_day)
	var skull := track.get_node("Node%d" % elite_day) as Control
	var back := scout.get_node("%NextBattleButton") as Button
	await _hover(skull)
	_check(scout.focused_elite_day() == 0, "ordinary skull hover does not pin")
	_check(_shown_counts() == _spec_counts(elite_specs), "skull hover shows the chapter's elite army")
	await _move(Vector2(4, 4))
	_check(_shown_counts() == _spec_counts(cached), "leaving an unpinned skull restores upcoming army")
	await _click(skull)
	_check(scout.focused_elite_day() == elite_day and back.visible and not reroll.visible,
		"click pins elite preview with Back instead of Reroll")
	_check(track._focused_elite_day == elite_day, "pinned skull keeps its selected visual")
	for control: Control in [scout.get_node("%ScoutTitle"), back]:
		var canvas_rect := control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
		_check(get_viewport().get_visible_rect().encloses(canvas_rect), "elite title and Back remain inside the viewport")
	_check(_shown_counts() == _spec_counts(elite_specs), "pinned preview shows exact elite composition")
	_check((scout.get_node("%ScoutRewardLabel") as Label).text
		== BiomassDisplay.number(EnemyComposer.battle_reward_for(elite_day, elite_specs), true), "elite reward matches preview")
	var enemy := scout.get_node("%ScoutRow").get_child(0) as ScoutEnemyEntry
	await _hover(enemy.get_node("%PortraitHost") as Control)
	_check(get_viewport().gui_get_hovered_control() == enemy and scout.focused_elite_day() == elite_day,
		"pointer reaches elite enemy while preview remains pinned")
	var overlay := DetailTooltipPopup._instance
	var tip: Control = overlay._tip if is_instance_valid(overlay) else null
	_check(is_instance_valid(tip) and tip.is_visible_in_tree()
		and (tip.get_child(0).get_child(0) as Label).text == enemy._unit_data.display_name,
		"real enemy hover opens the pinned enemy's tooltip")
	await _snapshot("pinned-%d-tooltip" % elite_day)
	_check(GameState.upcoming_enemy_formation == cached and GameState.biomass.amount == balance
		and GameState.scout_rerolls_today == 1 and BattleLaunch.enemy_roster == launch_before,
		"preview and tooltip preserve cached army, biomass, rerolls, and launch state")
	var battle_roster := colony._make_default_enemy_roster()
	var launch_types: Array[EnemyUnitData] = []
	var cached_types: Array[EnemyUnitData] = []
	for unit in battle_roster:
		launch_types.append(unit.enemy_unit_data)
	for spec: EnemyUnitSpec in cached:
		cached_types.append(spec.unit_data)
	_check(launch_types == cached_types, "battle launch roster builder still uses exact upcoming army order")
	_check(base._battle_biomass_preview() == EnemyComposer.battle_reward_for(upcoming, cached),
		"Start Battle reward ignores focused future elite")
	await _click(back)
	_check_returned(cached, reward, reroll_label, balance)
	await _snapshot("returned-%d" % elite_day)
	await _click(skull)
	_check(scout.focused_elite_day() == elite_day, "skull can pin again after Back")
	await _click(skull)
	_check_returned(cached, reward, reroll_label, balance)
	await _move(Vector2(4, 4))
	await _click(skull)
	await _click(base._tab_buttons[base.TabId.NURSERY] as Control)
	await _click(base._tab_buttons[base.TabId.COLONY] as Control)
	_check_returned(cached, reward, reroll_label, balance)
	await _move(Vector2(4, 4))
	skull.grab_focus()
	await _key(KEY_SPACE)
	_check(scout.focused_elite_day() == elite_day, "Space pins the focused skull")
	await _key(KEY_ENTER)
	_check_returned(cached, reward, reroll_label, balance)
	await _click(skull)
	_check(scout.focused_elite_day() == elite_day, "preview is pinned before next Day/chapter refresh")
	print("ELITE_PREVIEW_FLOW upcoming=", upcoming, " elite=", elite_day, " complete")


func _current_elite(day: int) -> void:
	var cached := GameState.upcoming_enemy_formation.duplicate()
	var balance := GameState.biomass.amount
	var skull := track.get_node("Node%d" % day) as Control
	await _click(skull)
	await _move(Vector2(4, 4))
	var reroll := scout.get_node("%ScoutRerollButton") as Button
	_check(scout.focused_elite_day() == 0 and not (scout.get_node("%NextBattleButton") as Button).visible,
		"upcoming Elite Day has no redundant pin or Back button")
	_check(not reroll.visible and reroll.disabled, "upcoming Elite Day cannot reroll")
	_check(_shown_counts() == _spec_counts(cached) and GameState.upcoming_enemy_formation == cached
		and GameState.biomass.amount == balance and GameState.scout_rerolls_today == 0,
		"upcoming Elite Day click preserves actual army and currency")
	await _snapshot("current-%d" % day)


func _check_returned(cached: Array, reward: String, reroll_label: String, balance: int) -> void:
	var reroll := scout.get_node("%ScoutRerollButton") as Button
	_check(scout.focused_elite_day() == 0 and not (scout.get_node("%NextBattleButton") as Button).visible,
		"return clears focus and Back button")
	_check(track._focused_elite_day == 0, "return clears the skull's selected visual")
	_check(GameState.upcoming_enemy_formation == cached and _shown_counts() == _spec_counts(cached),
		"return restores the exact rerolled upcoming army")
	_check((scout.get_node("%ScoutRewardLabel") as Label).text == reward
		and (scout.get_node("%ScoutRerollCostLabel") as Label).text == reroll_label
		and reroll.visible and not reroll.disabled and GameState.biomass.amount == balance
		and GameState.scout_rerolls_today == 1, "return restores reward and reroll state without a transaction")


func _shown_counts() -> Dictionary:
	var counts := {}
	for entry: ScoutEnemyEntry in scout.get_node("%ScoutRow").get_children():
		counts[entry._unit_data.id] = (entry.get_node("%CountLabel") as Label).text.to_int()
	return counts


func _spec_counts(specs: Array) -> Dictionary:
	var counts := {}
	for spec: EnemyUnitSpec in specs:
		counts[spec.unit_data.id] = int(counts.get(spec.unit_data.id, 0)) + 1
	return counts


func _click(control: Control) -> void:
	await _hover(control)
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = get_viewport().get_final_transform() * point
		event.global_position = event.position
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _settle()


func _hover(control: Control) -> void:
	await _move(control.get_global_transform_with_canvas() * (control.size * 0.5))


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _settle()


func _move(point: Vector2) -> void:
	get_viewport().warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_final_transform() * point
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _settle()


func _settle() -> void:
	await get_tree().create_timer(0.45).timeout


func _snapshot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--visual"):
		return
	await RenderingServer.frame_post_draw
	var path := "/tmp/usability-elite-%s.png" % label
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("ELITE_PREVIEW_SCREENSHOT ", path, " result=", result)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("ELITE_PREVIEW_CHECK failed: " + label)
