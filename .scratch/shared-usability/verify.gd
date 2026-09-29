extends Node

var failures: int = 0
var base: Node
var colony: TroopSelectionScreen
var visual: bool = false


func _ready() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + message)
	else:
		print("PASS: " + message)


func settle() -> void:
	await get_tree().create_timer(0.2).timeout


func capture(label: String) -> void:
	await settle()
	if visual:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/usability-" + label + ".png")


func click(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	print("CLICK target=", control.name, " point=", point, " hovered=", get_viewport().gui_get_hovered_control())
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		get_viewport().push_input(event, true)
	await settle()


func _run() -> void:
	Analytics.ga = null
	GameState.reset_run()
	GameState.current_day = 2
	GameState.troop.seed_if_empty(StarterPackages.build_units(&"great_sword_spear"))
	GameState.biomass.add(100)
	var tree := get_tree()
	tree.current_scene = null
	tree.change_scene_to_file("res://assets/base/base.tscn")
	await tree.scene_changed
	base = tree.current_scene
	colony = base.get_node("%ColonyScreen")
	await settle()
	var action := base.get_node("%StartCombatButton") as Button
	var dialog: SealChoiceDialog = colony._seal_dialog
	check(is_instance_valid(dialog), "pending Seal opens on arrival")
	check(action.text == "Hide" and not action.disabled, "primary action is enabled Hide")
	await capture("seal-visible")
	var selected: SealData = dialog._offers[0]
	dialog._on_card_pressed(selected)
	var offers_before: Array[SealData] = dialog._offers.duplicate()
	await click(action)
	check(not dialog.visible and action.text == "Select Seal", "mouse reaches Hide above overlay")
	colony.ensure_pending_modals()
	base._refresh_hud()
	check(not dialog.visible, "HUD and modal refresh keep hidden chooser hidden")
	base._select_tab(base.TabId.NURSERY, true)
	var camera_position: Vector2 = base.get_node("%BaseCamera").position
	await click(action)
	check(dialog.visible and dialog._selected == selected and dialog._offers == offers_before, "same selected offers reopen from Nursery")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await settle()
	check(not dialog.visible and not get_tree().paused, "Escape hides chooser without opening pause menu")
	check(base.get_node("%BaseCamera").position == camera_position, "hide retains Nursery camera position")
	var nursery := GameState.nursery
	check(nursery.plant_spore(0, nursery.make_fresh_common_spore()), "plant while Seal pending")
	check(nursery.ready_plot_count() == 0, "growing Plot is not ready")
	check(nursery.apply_fertilizer_to_plot(0, load("res://assets/base/nursery/fertilizers/quick_growth.tres")), "Quick Growth applies while Seal pending")
	var nursery_button: Button = base._tab_buttons[base.TabId.NURSERY]
	var badge := nursery_button.get_node("ReadyBadge") as Label
	check(nursery.ready_plot_count() == 1 and badge.visible and badge.text == "1", "readiness badge updates immediately after fertilizer")
	check(nursery_button.text == "1  Nursery", "readiness leaves tab text unchanged")
	base.get_node("%NurseryScreen")._refresh()
	await capture("nursery-ready")
	var harvested := nursery.harvest(0)
	check(not harvested.is_empty() and not badge.visible, "harvest clears readiness badge")
	nursery.plant_spore(0, nursery.make_fresh_common_spore())
	nursery.apply_greenhouse_remaining_cut(99)
	check(badge.visible and badge.text == "1", "Greenhouse updates readiness badge immediately")
	nursery.apply_fertilizer_to_plot(0, load("res://assets/base/nursery/fertilizers/fungicide.tres"))
	check(not badge.visible, "removing grow clears readiness badge")
	var saved_squad: Array = GameState.troop.squad.duplicate()
	GameState.troop.squad.fill(null)
	colony._notify_start_combat_state()
	check(not action.disabled, "Select Seal works with empty Squad")
	colony.start_combat()
	check(get_tree().current_scene == base and not SceneTransition.is_transitioning(), "direct combat entry blocked while pending")
	await click(action)
	dialog._on_reroll_pressed()
	selected = dialog._offers[0]
	dialog._on_card_pressed(selected)
	offers_before = dialog._offers.duplicate()
	var cost_before: int = dialog._current_seal_reroll_cost()
	await click(action)
	base._select_tab(base.TabId.COLONY, true)
	await click(action)
	check(dialog._rerolls_this_pick == 1 and dialog._current_seal_reroll_cost() == cost_before and dialog._offers == offers_before and dialog._selected == selected, "paid reroll count/cost, offers and highlight persist")
	dialog._on_confirm_pressed()
	await settle()
	check(not GameState.pending_seal_choice and action.text == "Start Battle" and action.disabled, "confirmation restores normal empty-Squad eligibility")
	check(get_tree().current_scene == base and not SceneTransition.is_transitioning(), "confirmation never launches Battle")
	GameState.troop.squad.assign(saved_squad)
	colony.on_screen_shown()
	check(not action.disabled, "normal populated Squad can start Battle")
	await capture("formation")
	var track := colony.get_node("HeaderBlock/CombatProgressTrack") as CombatProgressTrack
	var seal_day := track.get_node("Node3") as Control
	var seal_point := seal_day.get_global_transform_with_canvas() * Vector2(22, -20)
	var seal_motion := InputEventMouseMotion.new()
	seal_motion.position = seal_point
	get_viewport().push_input(seal_motion, true)
	await settle()
	check(get_viewport().gui_get_hovered_control() == seal_day, "Seal artwork itself owns the timing tooltip hover")
	await capture("seal-tooltip")
	seal_day.grab_focus()
	await settle()
	check(seal_day.has_node("FocusTooltipLease") and "Before Battle 3" in seal_day.accessibility_name, "focused Day provides timing tooltip and accessible name")
	seal_day.release_focus()
	for day in range(1, 11):
		GameState.current_day = day - 1
		GameState.pending_seal_choice = false
		GameState.maybe_queue_seal_choice()
		check(GameState.is_seal_choice_day(day) == (day in [1, 3, 6, 9]), "Seal receiving schedule Day %d" % day)
		check(GameState.pending_seal_choice == (day in [3, 6, 9]), "post-Battle reward schedule Day %d" % day)
		track.refresh()
		for node in track._node_controls:
			var node_day := int(str(node.name).trim_prefix("Node"))
			check(node.has_node("SealIcon") == (node_day in [1, 3, 6, 9]), "icon schedule Day %d" % node_day)
	GameState.pending_seal_choice = false
	GameState.current_day = 8
	base._refresh_hud()
	await capture("track-late")
	GameState.troop.unlock_all_squad_slots()
	colony.on_screen_shown()
	await capture("formation-full")
	var biomass_checks = load("res://.scratch/shared-usability/biomass_checks.gd")
	if biomass_checks != null:
		failures += await biomass_checks.run(base)
	var biomass_nursery_checks = load("res://.scratch/shared-usability/biomass_nursery_checks.gd")
	if biomass_nursery_checks != null:
		failures += await biomass_nursery_checks.run(base)
	var preview_checks = load("res://.scratch/shared-usability/preview_checks.gd")
	if preview_checks != null:
		failures += await preview_checks.run(base.get_node("HudLayer/HudRoot"))
	# A fresh Run retains its existing blocking starter selection and opening Seal.
	GameState.reset_run()
	tree.change_scene_to_file("res://assets/base/base.tscn")
	await tree.scene_changed
	base = tree.current_scene
	colony = base.get_node("%ColonyScreen")
	await settle()
	check(is_instance_valid(colony._starter_dialog) and not is_instance_valid(colony._seal_dialog), "opening starter flow preserved")
	var starter := colony._starter_dialog
	starter._on_card_pressed(&"great_sword_spear")
	starter._on_confirm_pressed()
	await settle()
	dialog = colony._seal_dialog
	check(is_instance_valid(dialog) and dialog.visible and not dialog._allow_reroll, "opening Seal remains required without reroll")
	action = base.get_node("%StartCombatButton") as Button
	await click(action)
	check(not dialog.visible and GameState.pending_seal_choice, "opening choice can be hidden without resolving reward")
	await click(action)
	dialog._on_card_pressed(dialog._offers[0])
	dialog._on_confirm_pressed()
	await settle()
	check(not GameState.pending_seal_choice and action.text == "Start Battle", "opening Seal confirmation restores Battle action")
	print("VERIFICATION COMPLETE: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)
