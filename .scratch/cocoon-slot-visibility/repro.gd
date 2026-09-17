extends Node

var _failures: int = 0
var _screen: TroopSelectionScreen
var _last_mouse := Vector2.ZERO

func _ready() -> void:
	get_tree().create_timer(20.0).timeout.connect(func() -> void: get_tree().quit(2))
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		_failures += 1

func _settle() -> void:
	await get_tree().create_timer(0.1).timeout

func _card_for(unit: RosterUnitData) -> UnitCard:
	for node in _screen.find_children("*", "UnitCard", true, false):
		var card := node as UnitCard
		if card.unit_data == unit:
			return card
	return null

func _move_mouse(point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = point - _last_mouse
	_last_mouse = point
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_viewport().push_input(motion, true)
	await _settle()

func _button(point: Vector2, pressed: bool) -> void:
	var button := InputEventMouseButton.new()
	button.position = point
	button.global_position = point
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_viewport().push_input(button, true)
	await _settle()

func _drop_in_cocoon(unit: RosterUnitData, cocoon: CocoonSlot) -> void:
	var card := _card_for(unit)
	var start := card.get_global_transform_with_canvas() * (card.size * 0.5)
	var end := cocoon.get_global_transform_with_canvas() * (cocoon.size * 0.5)
	await _move_mouse(start, false)
	await _button(start, true)
	await _move_mouse(start + Vector2(30, 0), true)
	_check(get_viewport().gui_is_dragging(), "Real unit-card drag starts")
	await _move_mouse(end, true)
	await _button(end, false)
	_check(_screen._pupation_dialog != null, "Cocoon drop opens training confirmation")
	var slot_card := _card_for(unit)
	_check(slot_card == null or not slot_card.is_visible_in_tree(), "Unit is absent from War Chamber slots during confirmation")

func _run() -> void:
	GameState.reset_run()
	GameState.pending_seal_choice = false
	GameState.troop.seed_if_empty(StarterPackages.build_units(StarterPackages.PACKAGE_IDS[0]))
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://assets/base/base.tscn")
	await get_tree().scene_changed
	_screen = get_tree().current_scene.get_node("%ColonyScreen")
	await get_tree().create_timer(0.5).timeout
	get_tree().current_scene._camera.force_update_scroll()
	var child := _screen.get_training_hint_unit()
	var cocoon: CocoonSlot = _screen._cocoon_slots[0]
	await _drop_in_cocoon(child, cocoon)
	if _screen._pupation_dialog == null:
		get_tree().quit(1)
		return
	_check(GameState.troop.squad.has(child), "Unconfirmed training does not mutate roster")
	_screen._pupation_dialog._on_cancel_pressed()
	await _settle()
	_check(_card_for(child) != null and _card_for(child).is_visible_in_tree(), "Cancelling restores the unit to its original slot")
	_screen._on_unit_card_clicked(_card_for(child))
	await _settle()
	_check(_card_for(child).source == "bench", "Repeat from a bench slot")
	await _drop_in_cocoon(child, cocoon)
	_screen._pupation_dialog._on_confirm_pressed()
	await _settle()
	_check(GameState.pupation.get_occupant(cocoon.school) == child, "Confirmation places unit in cocoon")
	_check(_card_for(child) == null, "Cocooned unit remains absent from all troop slots")
	GameState.emerge_pupations()
	_screen._sync_all_slots()
	await _settle()
	_check(_card_for(child) != null and _card_for(child).is_visible_in_tree(), "Training completion returns the unit to the troop")
	print("COCOON SLOT CHECK: ", _failures, " failures")
	get_tree().quit(1 if _failures else 0)
