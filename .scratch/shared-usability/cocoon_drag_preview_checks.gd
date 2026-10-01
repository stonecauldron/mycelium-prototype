extends Node

const CHECKS := preload("res://.scratch/shared-usability/preview_checks.gd")
const PORTRAITS := preload("res://.scratch/shared-usability/portrait_checks.gd")

var failures: int = 0
var base: Node
var host: Control
var colony: TroopSelectionScreen
var child: RosterUnitData
var adult: RosterUnitData


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	Analytics.ga = null
	GameState.reset_run()
	GameState.pending_seal_choice = false
	GameState.current_day = 2
	GameState.biomass.amount = 50
	GameState.troop.seed_if_empty(StarterPackages.build_units(&"great_sword_spear"))
	GameState.troop.squad.fill(null)
	GameState.troop.bench.fill(null)
	child = CHECKS.make_unit([], false)
	adult = CHECKS.make_unit([WeaponSchool.Id.SWORD], true)
	GameState.troop.squad[0] = child
	GameState.troop.bench[0] = adult
	base = preload("res://assets/base/base.tscn").instantiate()
	get_tree().root.add_child(base)
	get_tree().current_scene = base
	host = base.get_node("HudLayer/HudRoot") as Control
	colony = base.get_node("%ColonyScreen") as TroopSelectionScreen
	await get_tree().create_timer(0.8).timeout
	# Settle the initial native pointer warp before starting the first forced drag.
	await _move(Vector2(4, 4))
	await _valid_previews()
	await _rejected_previews()
	await _cleanup_checks()
	await _shared_renderer_checks()
	print("COCOON_DRAG_PREVIEW_CHECKS failures=", failures)
	get_tree().quit(failures)


func _valid_previews() -> void:
	var bow := _slot(WeaponSchool.Id.BOW)
	var mace := _slot(WeaponSchool.Id.MACE)
	await _start_drag(child, "squad")
	await _hover(bow)
	_check_preview(bow, child)
	var first_tip := bow._drag_preview_tip
	await _hover(bow)
	_check(bow._drag_preview_tip == first_tip, "same hovered school reuses the comparison")
	await _snapshot("child-bow")
	await _hover(mace)
	_check_cleared(bow, "switching schools")
	_check_preview(mace, child)
	_check(GameState.biomass.amount == 50 and child.weapon_trainings.is_empty()
		and GameState.troop.squad[0] == child, "hover does not spend, train, or move Child")
	await _move(Vector2(4, 4))
	_check_cleared(mace, "leaving a school")
	await _cancel_drag()

	await _start_drag(adult, "bench")
	await _hover(mace)
	_check_preview(mace, adult)
	await _snapshot("adult-bench")
	await _cancel_drag()
	_check_cleared(mace, "drag cancellation")
	_check(mace.tooltip_text == WeaponSchool.display_name(mace.school), "ordinary school tooltip text restores after drag")
	await _move(Vector2(4, 4))
	await _hover(mace)
	_check(is_instance_valid(DetailTooltipPopup._instance._tip)
		and DetailTooltipPopup._instance._tip is SchoolTrainingDetailCard,
		"ordinary school hover works after drag cancellation")

	GameState.troop.squad[0] = adult
	GameState.troop.bench[0] = child
	adult.favourite_child_buff = true
	for seal_name in ["favourite_child", "bulwark", "ranger"]:
		GameState.seals.add(load("res://assets/base/seals/%s.tres" % seal_name) as SealData)
	colony._sync_all_slots()
	await _start_drag(adult, "squad")
	await _hover(mace)
	_check_preview(mace, adult)
	if not is_instance_valid(mace._drag_preview_tip):
		await _cancel_drag()
		return
	var signature := _signature(mace._drag_preview_tip._comparison)
	await _snapshot("adult-seals")
	await _release(mace)
	_check_cleared(mace, "drop opens modal")
	var dialog := colony._pupation_dialog
	_check(is_instance_valid(dialog), "valid drop opens confirmation")
	if is_instance_valid(dialog):
		_check(_signature(dialog._comparison) == signature, "modal and passive preview show identical results")
		_check(not dialog._comparison.result_only
			and (dialog._comparison.get_node("%LeftColumn") as Control).is_visible_in_tree()
			and (dialog._comparison.get_node("%MidColumn") as Control).is_visible_in_tree()
			and dialog._comparison._right_portrait.is_visible_in_tree(),
			"confirmation retains the full before/after comparison")
		await _snapshot("full-confirmation")
		_check(GameState.biomass.amount == 50, "opening modal does not spend")
		await _click(dialog.get_node("%ConfirmButton") as Control)
		_check(GameState.biomass.amount == 50 - WeaponSchool.COCOON_COST
			and adult.weapon_trainings == [WeaponSchool.Id.SWORD, WeaponSchool.Id.MACE],
			"real confirmation applies previewed Training and spends once")

	# The actual confirmation now has its own emergence presentation; let it finish.
	var remaining := 3.0
	while (colony._has_active_reveal() or not GameState.pending_cocoon_emergences.is_empty()) and remaining > 0.0:
		await get_tree().process_frame
		remaining -= get_process_delta_time()
	GameState.biomass.amount = 0
	await _start_drag(adult, "squad")
	await _hover(bow)
	_check_preview(bow, adult)
	_check(bow._biomass_preview_delta() == -WeaponSchool.COCOON_COST,
		"unaffordable hover still previews the hypothetical cost")
	await _release(bow)
	_check_cleared(bow, "unaffordable drop")
	dialog = colony._pupation_dialog
	_check(is_instance_valid(dialog) and (dialog.get_node("%ConfirmButton") as Button).disabled,
		"unaffordable modal cannot confirm")
	if is_instance_valid(dialog):
		await _click(dialog.get_node("%CloseButton") as Control)
	_check(GameState.biomass.amount == 0 and adult.weapon_trainings == [WeaponSchool.Id.SWORD, WeaponSchool.Id.MACE],
		"unaffordable preview and dismissal preserve balance and Trainings")
	GameState.biomass.amount = 50


func _rejected_previews() -> void:
	var bow := _slot(WeaponSchool.Id.BOW)
	var sword := _slot(WeaponSchool.Id.SWORD)
	var unchanged := CHECKS.make_unit([WeaponSchool.Id.BOW, WeaponSchool.Id.BOW], true)
	GameState.troop.bench[1] = unchanged
	colony._sync_all_slots()
	await _start_drag(unchanged, "bench")
	await _hover(bow)
	_check_cleared(bow, "unchanged Training")
	_check(ActionFeedback._tag.visible and ActionFeedback._message.text == "No changes from this Training.",
		"unchanged Training keeps its existing rejection")
	await _release(bow)
	_check(not is_instance_valid(colony._pupation_dialog) and GameState.biomass.amount == 50,
		"unchanged drop neither opens confirmation nor spends")

	GameState.pupation.try_place(CHECKS.make_unit([], false), WeaponSchool.Id.SWORD)
	sword.sync_from_state()
	await _start_drag(adult, "squad")
	await _hover(sword)
	_check_cleared(sword, "occupied school")
	await _cancel_drag()
	GameState.pupation.take_occupant(WeaponSchool.Id.SWORD)
	sword.sync_from_state()
	await _start_drag(adult, "stock")
	await _hover(bow)
	_check_cleared(bow, "invalid source")
	await _cancel_drag()


func _cleanup_checks() -> void:
	var bow := _slot(WeaponSchool.Id.BOW)
	await _start_drag(adult, "squad")
	await _hover(bow)
	_check_preview(bow, adult)
	bow.hide()
	await _settle()
	_check_cleared(bow, "hidden school")
	bow.show()
	await _cancel_drag()

	await _start_drag(adult, "squad")
	await _hover(bow)
	await _key(KEY_1)
	_check_cleared(bow, "tab switch")
	await _cancel_drag()
	await _key(KEY_2)
	await _start_drag(adult, "squad")
	await _hover(bow)
	await _key(KEY_ESCAPE)
	_check(get_tree().paused and not get_viewport().gui_is_dragging(), "pause cancels active drag")
	_check_cleared(bow, "pause")
	await _key(KEY_ESCAPE)
	_check(not get_tree().paused, "pause closes normally")

	await _start_drag(adult, "squad")
	await _hover(bow)
	colony._open_compost_confirm(adult)
	await _settle()
	_check_cleared(bow, "another modal opens")
	await _cancel_drag()
	if is_instance_valid(colony._compost_dialog):
		await _click(colony._compost_dialog.get_node("%CloseButton") as Control)
	_check(GameState.biomass.amount == 50, "cleanup actions never transact")


func _check_preview(slot: CocoonSlot, unit: RosterUnitData) -> void:
	var tip := slot._drag_preview_tip
	_check(get_viewport().gui_is_dragging() and get_viewport().gui_get_hovered_control() == slot,
		"real drag pointer still reaches its Cocoon")
	_check(is_instance_valid(tip) and tip.is_visible_in_tree() and tip._unit == unit and tip._school == slot.school,
		"valid troop drag shows the requested comparison")
	if not is_instance_valid(tip):
		return
	var comparison := tip._comparison
	_check(comparison.result_only
		and not (comparison.get_node("%LeftColumn") as Control).is_visible_in_tree()
		and not (comparison.get_node("%MidColumn") as Control).is_visible_in_tree()
		and comparison._right_portrait.is_visible_in_tree(), "drag preview shows only result column")
	var visible_portraits := 0
	for portrait in [comparison._left_portrait, comparison._right_portrait]:
		for actor in portrait.get_children():
			if actor is UnitAppearance and actor.is_visible_in_tree():
				visible_portraits += 1
				var body: Rect2 = actor.transform * actor.visual_rect_local(false, true)
				_check(body.size.y >= 55.0 and actor.scale.x > 0.35, "single result portrait remains readable")
	_check(visible_portraits == 1, "drag preview has exactly one visible unit")
	_check(comparison._duration_suffix.is_visible_in_tree()
		and comparison._duration_chip.get_parent().get_parent() == comparison._right_portrait.get_parent(),
		"duration remains visible beneath the result")
	failures += CHECKS._check_portrait_alignment(comparison, "Right")
	var actual := unit.duplicate(true) as RosterUnitData
	_check(actual.apply_pupation_training(slot.school), "actual Training accepts preview fixture")
	_check(comparison._preview_unit.weapon_trainings == actual.weapon_trainings
		and CHECKS._stats(comparison._preview_unit) == CHECKS._stats(actual),
		"passive result order and Stats match actual Training")
	var before_atk := SealModifiers.effective_attack_damage(unit)
	var before_hp := SealModifiers.effective_max_hp(unit)
	# Evaluate the actual result in the same real formation, then restore before yielding.
	var row: Array = GameState.troop.squad if GameState.troop.squad.has(unit) else GameState.troop.bench
	var index := row.find(unit)
	row[index] = actual
	var after_atk := SealModifiers.effective_attack_damage(actual)
	var after_hp := SealModifiers.effective_max_hp(actual)
	row[index] = unit
	failures += CHECKS._check_combat_preview(comparison, "Atk", before_atk, after_atk)
	failures += CHECKS._check_combat_preview(comparison, "Hp", before_hp, after_hp)
	var changed: Array[int] = [actual.weapon_trainings.size() - 1]
	failures += CHECKS._check_weapon_equation(comparison._right_weapon_row, actual, "Drag result", changed)
	var visual := tip.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, tip.size)
	_check(get_viewport().get_visible_rect().grow(-8.0).encloses(visual), "comparison stays inside viewport")
	for control in tip.find_children("*", "Control", true, false):
		_check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE and control.focus_mode == Control.FOCUS_NONE,
			"passive comparison cannot intercept pointer or keyboard: " + control.name)
		_check(not control is BaseButton, "passive comparison has no action buttons")


func _signature(comparison: TrainingComparison) -> Array:
	var values: Array = [comparison._preview_unit.weapon_trainings.duplicate(), CHECKS._stats(comparison._preview_unit),
		comparison._preview_unit.weapon.resource_path]
	for name in ["LeftAtkChip", "LeftHpChip", "RightAtkChip", "RightHpChip", "LeftStr", "LeftDex", "LeftCon", "RightStr", "RightDex", "RightCon"]:
		values.append((comparison.get_node("%" + name).get_node("%Value") as Label).text)
	for name in ["RightAtkDelta", "RightHpDelta", "DurationSuffix", "LeftStage", "RightStage"]:
		values.append((comparison.get_node("%" + name) as Label).text)
	return values


func _check_cleared(slot: CocoonSlot, reason: String) -> void:
	_check(not is_instance_valid(slot._drag_preview_tip) and not is_instance_valid(slot._drag_preview_lease),
		"preview lease cleared after " + reason)
	var overlay := DetailTooltipPopup._instance
	_check(not is_instance_valid(overlay) or not is_instance_valid(overlay._tip)
		or not overlay._tip is TrainingPreviewTooltip or overlay._tip._school != slot.school,
		"no stale transformation overlay after " + reason)
	if is_instance_valid(overlay):
		for tip in overlay._host.get_children():
			if tip is TrainingPreviewTooltip and tip._school == slot.school:
				_check(not tip.is_visible_in_tree(), "no fading comparison left visible after " + reason)


func _shared_renderer_checks() -> void:
	failures += await CHECKS._training_dialog(host, CHECKS.make_unit([], false), WeaponSchool.Id.BOW,
		"Bow Training → Bow", "Returns after the next Battle · Becomes an Adult", [0],
		["Melee", "Scaling"], ["Ranged", "Scaling"])
	var dual := CHECKS.make_unit([WeaponSchool.Id.SWORD, WeaponSchool.Id.BOW], true)
	failures += await CHECKS._training_dialog(host, dual, WeaponSchool.Id.MACE,
		"Bow + Mace → Great Horn", "Ready immediately · Stats unchanged", [1],
		["Ranged", "Scaling"], ["Mid Range", "Scaling", "Blunt"])
	failures += await PORTRAITS.run(host)


func _slot(school: int) -> CocoonSlot:
	for slot: CocoonSlot in colony._cocoon_slots:
		if slot.school == school:
			return slot
	return null


func _start_drag(unit: RosterUnitData, source: String) -> void:
	await _move(Vector2(4, 4))
	host.force_drag({"source": source, "unit": unit}, null)
	await get_tree().process_frame


func _cancel_drag() -> void:
	get_viewport().gui_cancel_drag()
	await _settle()


func _hover(control: Control) -> void:
	await _move(control.get_global_transform_with_canvas() * (control.size * 0.5))


func _move(point: Vector2) -> void:
	get_viewport().warp_mouse(point)
	var event := InputEventMouseMotion.new()
	event.position = get_viewport().get_final_transform() * point
	event.global_position = event.position
	Input.parse_input_event(event)
	await _settle()


func _click(control: Control) -> void:
	await _hover(control)
	await _mouse_button(control, true)
	await _release(control)


func _release(control: Control) -> void:
	await _mouse_button(control, false)
	await _settle()


func _mouse_button(control: Control, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = get_viewport().get_final_transform() * (control.get_global_transform_with_canvas() * (control.size * 0.5))
	event.global_position = event.position
	Input.parse_input_event(event)
	await get_tree().process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _settle()


func _settle() -> void:
	await get_tree().create_timer(0.45).timeout


func _snapshot(label: String) -> void:
	if OS.get_cmdline_user_args().has("--visual"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/usability-cocoon-drag-%s.png" % label)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("COCOON_DRAG_PREVIEW_CHECK " + message)
