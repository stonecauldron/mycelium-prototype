extends RefCounted

const TRAINING_SCENE := preload("res://assets/base/pupation/pupation_confirm_dialog.tscn")
const COMPOST_SCENE := preload("res://assets/base/pupation/compost_confirm_dialog.tscn")
const SCOUT_SCENE := preload("res://assets/base/troop_selection/scout_bubble/scout_bubble.tscn")
const SEAL_SCENE := preload("res://assets/base/seals/seal_choice_dialog.tscn")


## Keep the live Biomass resource so the existing HUD subscriptions are exercised.
static func run(base: Node) -> int:
	var host := base.get_node("HudLayer/HudRoot") as Control
	var chip := base.get_node("%BiomassChip") as Control
	var saved_troop := GameState.troop
	var saved_pupation := GameState.pupation
	var saved_nursery := GameState.nursery
	var saved_seals := GameState.seals
	var saved_balance := GameState.biomass.amount
	var saved_day := GameState.current_day
	var saved_pending := GameState.pending_seal_choice
	var saved_rerolls := GameState.scout_rerolls_today
	var saved_formation := GameState.upcoming_enemy_formation.duplicate()
	GameState.troop = TroopData.new()
	GameState.pupation = PupationData.new()
	GameState.nursery = NurseryData.new()
	GameState.seals = SealsCollection.new()
	GameState.current_day = 1
	GameState.pending_seal_choice = false
	GameState.scout_rerolls_today = 0
	GameState.upcoming_enemy_formation.clear()
	GameState.biomass.amount = 20
	var adult := _make_unit(true)
	var child := _make_unit(false)
	GameState.troop.squad[0] = adult
	GameState.troop.squad[1] = child
	GameState.troop.squad[2] = _make_unit(true)
	base._refresh_hud()
	await _move(host, Vector2(4, 4))
	var failures := _check_current(chip, "initial balance")
	failures += await _lifecycle_checks(host, chip)
	failures += await _training_checks(host, chip, adult, child)
	failures += await _compost_checks(host, chip, adult, child)
	failures += await _reroll_checks(host, chip)
	failures += await _battle_checks(base, host, chip)
	await _move(host, Vector2(4, 4))
	GameState.troop = saved_troop
	GameState.pupation = saved_pupation
	GameState.nursery = saved_nursery
	GameState.seals = saved_seals
	GameState.current_day = saved_day
	GameState.pending_seal_choice = saved_pending
	GameState.scout_rerolls_today = saved_rerolls
	GameState.upcoming_enemy_formation.assign(saved_formation)
	GameState.biomass.amount = saved_balance
	var scout: ScoutBubble = base._scout_bubble()
	if scout != null:
		scout.refresh()
	base._refresh_hud()
	base.set_start_combat_enabled(base.get_node("%ColonyScreen").can_start_combat())
	await _settle(host)
	failures += _check_current(chip, "restored balance")
	print("BIOMASS_CHECKS failures=", failures)
	return failures


static func _lifecycle_checks(host: Control, chip: Control) -> int:
	var blocker := Control.new()
	blocker.z_index = 199
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(blocker)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var compact: BiomassChip = preload("res://assets/ui/biomass_chip/biomass_chip.tscn").instantiate()
	compact.position = Vector2(1100, 200)
	compact.size = Vector2(176, 96)
	blocker.add_child(compact)
	await _settle(host)
	var compact_resting_size := (compact.get_node("Paper") as Control).size
	var compact_resting_position := (compact.get_node("Paper") as Control).position
	var action := Control.new()
	action.position = Vector2(800, 250)
	action.size = Vector2(200, 64)
	blocker.add_child(action)
	var child := Button.new()
	child.text = "Preview fixture"
	action.add_child(child)
	child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var state := {"delta": -4}
	BiomassPreview.bind(action, func() -> Variant: return state["delta"])
	var balance := GameState.biomass.amount
	var resting_size := (chip.get_node("Paper") as Control).size
	var resting_position := (chip.get_node("Paper") as Control).position
	await _hover(child)
	var failures := _check(host.get_viewport().gui_get_hovered_control() == child,
		"hovered descendant exercises metadata ancestor lookup")
	failures += _check_preview(chip, -4, "ancestor cost")
	failures += _check(GameState.biomass.amount == balance, "hover never spends Biomass")
	BiomassPreview.bind(action, func() -> Variant: return state["delta"], "On victory")
	await _settle(host)
	failures += _check_preview(chip, -4, "context changes under pointer", "On victory")
	GameState.biomass.amount = 3
	await _settle(host)
	failures += _check_warning(chip, "conditional unaffordable action")
	failures += _check((compact.get_node("Paper") as Control).size.y > compact_resting_size.y,
		"compact warning exercises paper minimum-height growth")
	GameState.biomass.amount = 4
	await _settle(host)
	failures += _check_preview(chip, -4, "exact cost leaves zero and restores context", "On victory")
	state["delta"] = 4
	await _settle(host)
	failures += _check_preview(chip, 4, "gain after warning restores signed amount", "On victory")
	state["delta"] = -4
	GameState.biomass.amount = balance
	BiomassPreview.bind(action, func() -> Variant: return state["delta"])
	await _settle(host)
	failures += _check_preview(chip, -4, "context removal retains preview size")
	state["delta"] = 0
	await _settle(host)
	failures += _check_preview(chip, 0, "zero action stays neutral")
	state["delta"] = -4
	await _hover(child)
	action.hide()
	await _settle(host)
	failures += _check_current(chip, "hidden action clears preview")
	action.show()
	await _hover(child)
	action.queue_free()
	await _settle(host)
	failures += _check_current(chip, "freed action clears preview")
	var compact_restored := (compact.get_node("Paper") as Control).size
	print("BIOMASS_COMPACT_PAPER resting=", compact_resting_size, " restored=", compact_restored,
		" position=", compact_resting_position, " -> ", (compact.get_node("Paper") as Control).position)
	failures += _check(compact_restored.is_equal_approx(compact_resting_size)
		and (compact.get_node("Paper") as Control).position.is_equal_approx(compact_resting_position),
		"compact paper shrinks after warning content disappears")
	blocker.queue_free()
	await _move(host, Vector2(4, 4))
	var restored_size := (chip.get_node("Paper") as Control).size
	print("BIOMASS_PAPER_SIZE resting=", resting_size, " restored=", restored_size,
		" position=", resting_position, " -> ", (chip.get_node("Paper") as Control).position)
	failures += _check(restored_size.is_equal_approx(resting_size)
		and (chip.get_node("Paper") as Control).position.is_equal_approx(resting_position), "warning removal restores actual paper size")
	await _snapshot(host, "normal-after-warning")
	return failures


static func _training_checks(
	host: Control, chip: Control, adult: RosterUnitData, child: RosterUnitData
) -> int:
	var dialog: PupationConfirmDialog = TRAINING_SCENE.instantiate()
	dialog.setup(adult, WeaponSchool.Id.SWORD)
	host.add_child(dialog)
	await _settle(host)
	var button := dialog.get_node("%ConfirmButton") as Button
	await _hover(button)
	var failures := _check_preview(chip, -WeaponSchool.COCOON_COST, "Adult Training")
	GameState.biomass.add(5)
	await _settle(host)
	failures += _check_preview(chip, -WeaponSchool.COCOON_COST, "balance updates while hovered")
	GameState.biomass.amount = 1
	await _settle(host)
	failures += _check(button.disabled, "unaffordable Training is disabled")
	failures += _check_warning(chip, "disabled Training warning")
	await _snapshot(host, "not-enough")
	GameState.biomass.amount = WeaponSchool.COCOON_COST
	await _settle(host)
	failures += _check(not button.disabled, "Training enables at exact cost without pointer movement")
	failures += _check_preview(chip, -WeaponSchool.COCOON_COST, "exact Training cost projects zero")
	await _snapshot(host, "exact-cost")
	GameState.biomass.amount = WeaponSchool.COCOON_COST - 1
	await _settle(host)
	failures += _check_warning(chip, "warning returns when balance drops under pointer")
	GameState.biomass.amount = 20
	dialog.setup(child, WeaponSchool.Id.BOW)
	await _hover(button)
	failures += _check_preview(chip, -WeaponSchool.COCOON_COST, "Child Evolution")
	await _move(host, Vector2(4, 4))
	failures += _check_current(chip, "hover exit restores current amount")
	await _snapshot(host, "normal-after-hover")
	dialog.queue_free()
	await _settle(host)
	return failures


static func _compost_checks(
	host: Control, chip: Control, adult: RosterUnitData, child: RosterUnitData
) -> int:
	adult.cap_mutation = load("res://assets/base/nursery/mutations/cap/bank.tres") as MutationData
	adult.biomass_bank = 7
	var dialog: CompostConfirmDialog = COMPOST_SCENE.instantiate()
	dialog.setup(adult)
	dialog.confirmed.connect(func(unit: RosterUnitData) -> void: GameState.try_compost_unit(unit))
	host.add_child(dialog)
	await _settle(host)
	var button := dialog.get_node("%ConfirmButton") as Button
	await _hover(button)
	var grant := BiomassData.reward_for_compost(true) + adult.biomass_bank
	var failures := _check_preview(chip, grant, "Adult Compost includes Bank")
	failures += _check(GameState.biomass.amount == 20 and adult.biomass_bank == 7,
		"Compost hover leaves balance and candidate unchanged")
	await _snapshot(host, "gain")
	dialog.setup(child)
	await _hover(button)
	failures += _check_preview(chip, BiomassData.reward_for_compost(false), "Child Compost uses Child reward")
	dialog.setup(adult)
	await _click(button)
	failures += _check(GameState.biomass.amount == 20 + grant,
		"actual Compost grants the previewed stage reward and Bank")
	failures += _check_current(chip, "confirmed Compost clears preview")
	return failures


static func _reroll_checks(host: Control, chip: Control) -> int:
	GameState.biomass.amount = 40
	var scout: ScoutBubble = SCOUT_SCENE.instantiate()
	host.add_child(scout)
	scout.position = Vector2(450, 240)
	scout.z_index = 100
	await _settle(host)
	var scout_button := scout.get_node("%ScoutRerollButton") as Button
	await _hover(scout_button)
	var scout_cost := GameState.current_scout_reroll_cost()
	var failures := _check_preview(chip, -scout_cost, "Scout reroll")
	await _click(scout_button)
	failures += _check(GameState.biomass.amount == 40 - scout_cost, "Scout click spends displayed cost")
	failures += _check_preview(chip, -GameState.current_scout_reroll_cost(), "Scout cost escalates under pointer")
	GameState.current_day = 4
	scout.refresh()
	await _settle(host)
	failures += _check_current(chip, "elite Scout hides reroll preview")
	scout.queue_free()
	await _move(host, Vector2(4, 4))
	GameState.current_day = 1
	var seals: SealChoiceDialog = SEAL_SCENE.instantiate()
	seals.setup(SealCatalog.roll_offers(3, GameState.seals), true)
	host.add_child(seals)
	await _settle(host)
	var seal_button := seals.get_node("%RerollButton") as Button
	await _hover(seal_button)
	var seal_cost := seals._current_seal_reroll_cost()
	var balance := GameState.biomass.amount
	failures += _check_preview(chip, -seal_cost, "Seal reroll")
	await _click(seal_button)
	failures += _check(GameState.biomass.amount == balance - seal_cost, "Seal click spends displayed cost")
	failures += _check_preview(chip, -seals._current_seal_reroll_cost(), "Seal cost escalates under pointer")
	seals.setup(seals._offers, false)
	seals._refresh_reroll_affordability()
	await _settle(host)
	failures += _check_current(chip, "opening Seal has no reroll preview")
	seals.queue_free()
	await _move(host, Vector2(4, 4))
	return failures


static func _battle_checks(base: Node, host: Control, chip: Control) -> int:
	var button := base.get_node("%StartCombatButton") as Button
	GameState.pending_seal_choice = false
	base.set_start_combat_enabled(true)
	GameState.ensure_upcoming_enemy_formation()
	var scout: ScoutBubble = base._scout_bubble()
	if scout != null:
		scout.refresh()
	await _hover(button)
	var reward := EnemyComposer.battle_reward_for(
		GameState.get_upcoming_day(), GameState.upcoming_enemy_formation)
	var failures := _check_preview(chip, reward, "Battle reward", "On victory")
	await _snapshot(host, "conditional")
	GameState.pending_seal_choice = true
	base.set_start_combat_enabled(false)
	await _settle(host)
	failures += _check_current(chip, "pending Seal suppresses Battle reward under pointer")
	GameState.pending_seal_choice = false
	return failures


static func _check_warning(chip: Control, label: String) -> int:
	var amount := chip.get_node("%BiomassAmount") as Label
	var warning := chip.get_node("%BiomassDelta") as Label
	var context := chip.get_node("%PreviewContext") as Label
	var failures := _check(amount.text == BiomassDisplay.number(GameState.biomass.amount), label + ": actual balance remains")
	failures += _check(amount.get_theme_color("font_color") == StatDisplay.change_color(-1, true), label + ": red actual balance")
	failures += _check(warning.is_visible_in_tree() and warning.text == "Not enough\nbiomass", label + ": warning replaces negative total")
	failures += _check(warning.get_theme_color("font_color") == StatDisplay.LOSS_COLOR
		and warning.get_theme_constant("outline_size") == 0, label + ": red words without number outline")
	failures += _check(not context.visible and context.text.is_empty(), label + ": conditional context hidden")
	failures += _check((chip.get_node("Paper") as Control).scale.distance_to(Vector2.ONE * 1.18) < 0.01, label + ": counter stays enlarged")
	return failures


static func _check_preview(chip: Control, delta: int, label: String, context: String = "") -> int:
	if delta < 0 and GameState.biomass.amount + delta < 0:
		return _check_warning(chip, label)
	var amount := chip.get_node("%BiomassAmount") as Label
	var change := chip.get_node("%BiomassDelta") as Label
	var reason := chip.get_node("%PreviewContext") as Label
	var failures := _check(amount.text == BiomassDisplay.number(GameState.biomass.amount + delta),
		label + ": projected total")
	failures += _check(change.is_visible_in_tree() == (delta != 0)
		and (delta == 0 or change.text == BiomassDisplay.number(delta, true)), label + ": signed delta")
	failures += _check(reason.is_visible_in_tree() == (not context.is_empty())
		and (context.is_empty() or reason.text == context), label + ": conditional context")
	failures += _check(amount.get_theme_color("font_color") == StatDisplay.change_color(delta, true),
		label + ": total color")
	failures += _check(change.get_theme_constant("outline_size") == 3, label + ": signed number outline restored")
	if delta != 0:
		failures += _check(change.get_theme_color("font_color") == StatDisplay.change_color(delta),
			label + ": delta color")
		failures += _check((chip.get_node("Paper") as Control).scale.distance_to(Vector2.ONE * 1.18) < 0.01,
			label + ": enlarged counter")
	return failures


static func _check_current(chip: Control, label: String) -> int:
	var failures := _check((chip.get_node("%BiomassAmount") as Label).text
		== BiomassDisplay.number(GameState.biomass.amount), label + ": actual balance")
	failures += _check(not (chip.get_node("%BiomassDelta") as Label).is_visible_in_tree()
		and not (chip.get_node("%PreviewContext") as Label).is_visible_in_tree(), label + ": no stale preview")
	failures += _check((chip.get_node("Paper") as Control).scale.distance_to(Vector2.ONE) < 0.01,
		label + ": normal size")
	return failures


static func _hover(control: Control) -> void:
	await _move(control, control.get_global_transform_with_canvas() * (control.size * 0.5))


static func _move(host: Control, point: Vector2) -> void:
	host.get_viewport().warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = host.get_viewport().get_final_transform() * point
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await _settle(host)


static func _click(button: Button) -> void:
	await _hover(button)
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	var tree := button.get_tree()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_viewport().get_final_transform() * point
		event.global_position = event.position
		Input.parse_input_event(event)
	await tree.create_timer(0.2).timeout


static func _settle(host: Control) -> void:
	await host.get_tree().create_timer(0.2).timeout


static func _snapshot(host: Control, label: String) -> void:
	if not OS.get_cmdline_user_args().has("--visual"):
		return
	await RenderingServer.frame_post_draw
	var image := host.get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png("/tmp/usability-biomass-%s.png" % label)


static func _make_unit(adult: bool) -> RosterUnitData:
	var unit := RosterUnitData.new()
	unit.display_name = "Hover Fern"
	unit.lineage_name = "Hover Fern"
	unit.stats = UnitStatsData.new()
	unit.is_imago = adult
	unit.life_stage_id = RosterUnitData.STAGE_IMAGO if adult else RosterUnitData.STAGE_JUVENILE
	if adult:
		unit.weapon_trainings = [WeaponSchool.Id.SWORD]
	unit.sync_weapon_from_trainings()
	return unit


static func _check(condition: bool, label: String) -> int:
	if condition:
		return 0
	push_error("BIOMASS_CHECK failed: " + label)
	return 1
