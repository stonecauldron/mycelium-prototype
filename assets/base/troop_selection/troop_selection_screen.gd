class_name TroopSelectionScreen
extends BaseScreen

const BENCH_SLOT_COUNT := TroopData.BENCH_SLOT_COUNT
const _UNIT_CARD_SCENE := preload("res://assets/base/unit_card/unit_card.tscn")
const _DROP_SLOT_SCENE := preload("res://assets/base/drop_slot/drop_slot.tscn")
const _COCOON_SLOT_SCENE := preload("res://assets/base/pupation/cocoon_slot.tscn")
const _COMPOST_BIN_SCENE := preload("res://assets/base/composting_bin/composting_bin.tscn")
const _COMPOST_BIN_SPACING := 48.0
const _PUPATION_CONFIRM_SCENE := preload("res://assets/base/pupation/pupation_confirm_dialog.tscn")
const _COMPOST_CONFIRM_SCENE := preload("res://assets/base/pupation/compost_confirm_dialog.tscn")
const _STARTER_CHOICE_SCENE := preload("res://assets/base/troop_selection/starter_choice_dialog.tscn")
const _SEAL_CHOICE_SCENE := preload("res://assets/base/seals/seal_choice_dialog.tscn")
const _FLAG_SEALS_SCENE := preload("res://assets/base/seals/flag_seals_overlay.tscn")

var bench: Array = []
var squad: Array = []

@onready var _squad_slot_row: HBoxContainer = %SquadSlotRow
@onready var _bench_grid: HBoxContainer = %BenchGrid
@onready var _bench_panel: PanelContainer = %BenchPanel
@onready var _cocoon_row: HBoxContainer = %CocoonRow
@onready var _scout_bubble: ScoutBubble = %ScoutBubble
@onready var _flag_bearer: Node2D = %FlagBearer

var _squad_slots: Array[DropSlot] = []
var _squad_unlock_slot: DropSlot = null
var _compost_bin: CompostingBin = null
var _bench_slots: Array[DropSlot] = []
var _cocoon_slots: Array = []
var _pupation_dialog: PupationConfirmDialog = null
var _pending_pupation_unit: RosterUnitData = null
var _compost_dialog: CompostConfirmDialog = null
var _starter_dialog: StarterChoiceDialog = null
var _seal_dialog: SealChoiceDialog = null
var _flag_seals: FlagSealsOverlay = null
var _screen_active: bool = false
var _emergence: UnitEmergence = null
var _emergence_ready_frame := 0
var _compost_release: CompostRelease = null
var _compost_gain: BiomassGain = null
var _revealing_unit: RosterUnitData = null
var _revealing_cocoon: CocoonSlot = null


func _ready() -> void:
	GameState.ensure_guided_preparation()
	set_process(false)
	_hydrate_from_troop_data()
	_build_squad_ui()
	_build_bench_ui()
	_build_cocoon_ui()
	_ensure_flag_seals_overlay()
	GameState.seals_changed.connect(_refresh_flag_seals)
	_sync_all_slots()
	_bench_panel.set_drag_forwarding(Callable(), _bench_can_drop, _bench_drop)
	_set_bench_structure_mouse_ignore()
	if _scout_bubble != null:
		_scout_bubble.refresh()
	_notify_start_combat_state()
	ensure_pending_modals()


func on_screen_shown() -> void:
	_screen_active = true
	_cancel_presentations()
	_ensure_squad_ui()
	_refresh_guided_visibility()
	_sync_all_slots()
	if _scout_bubble != null:
		_scout_bubble.refresh()
	_refresh_flag_seals()
	_notify_start_combat_state()
	ensure_pending_modals()
	_queue_emergence_presentation()


func on_screen_hidden() -> void:
	_screen_active = false
	set_process(false)
	_cancel_presentations()
	get_viewport().gui_cancel_drag()
	if _scout_bubble != null:
		_scout_bubble.return_to_next_battle()
	# Camera tabs keep controls visible; release focus before they move offscreen.
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	_notify_start_combat_state()


func refresh_after_undo() -> void:
	var was_active := _screen_active
	# Delayed Evolution predates this Base visit and survives unrelated Undo.
	for i in range(GameState.pending_cocoon_emergences.size() - 1, -1, -1):
		if not GameState.is_cocoon_emergence_current(GameState.pending_cocoon_emergences[i]):
			GameState.pending_cocoon_emergences.remove_at(i)
	_cancel_presentations()
	_cancel_cocoon_drag_preview()
	# Remove stale confirmations before rebuilding; their exit callbacks must not
	# close or reopen a replacement chooser on the next frame.
	var dialogs := [_pupation_dialog, _compost_dialog, _starter_dialog, _seal_dialog]
	var closed_callbacks := [
		_on_pupation_dialog_closed, _on_compost_dialog_closed,
		_on_starter_dialog_closed, _on_seal_dialog_closed,
	]
	for i in dialogs.size():
		var dialog := dialogs[i] as Control
		if not is_instance_valid(dialog):
			continue
		var closed: Callable = closed_callbacks[i].bind(dialog)
		if dialog.tree_exited.is_connected(closed):
			dialog.tree_exited.disconnect(closed)
		if dialog.visibility_changed.is_connected(_notify_start_combat_state):
			dialog.visibility_changed.disconnect(_notify_start_combat_state)
		dialog.hide()
		dialog.queue_free()
	_pupation_dialog = null
	_compost_dialog = null
	_starter_dialog = null
	_seal_dialog = null
	_pending_pupation_unit = null
	_hydrate_from_troop_data()
	on_screen_shown()
	_screen_active = was_active
	set_process(was_active and not GameState.pending_cocoon_emergences.is_empty())
	_notify_start_combat_state()


## Seal then starter picks — safe to call from base even when another tab is active.
func ensure_pending_modals() -> void:
	_ensure_seal_choice()
	_ensure_starter_choice()


func _hydrate_from_troop_data() -> void:
	bench = GameState.troop.bench
	squad = GameState.troop.squad


func _set_bench_structure_mouse_ignore() -> void:
	# Panel spans full width and overlaps the scout bubble; it must not eat hovers.
	_bench_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path in ["BenchMargin", "BenchMargin/BenchVBox", "BenchMargin/BenchVBox/BenchTitle", "BenchMargin/BenchVBox/BenchGrid"]:
		var node := _bench_panel.get_node_or_null(path) as Control
		if node:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bench_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ensure_squad_ui() -> void:
	var has_purchase_slot := _squad_unlock_slot != null and is_instance_valid(_squad_unlock_slot)
	# Nine positions + a purchase control and ten positions have the same count.
	# Compare their roles, so the final purchase is replaced by a fighting slot.
	if (
		_squad_slots.size() != GameState.troop.unlocked_squad_count
		or has_purchase_slot != (GameState.troop.can_unlock_squad_slot() and GameState.is_feature_available(&"squad_slots"))
		or is_instance_valid(_compost_bin) != GameState.is_feature_available(&"compost")
	):
		_build_squad_ui()
		return
	refresh_unlock_affordability()


func refresh_unlock_affordability() -> void:
	if _squad_unlock_slot == null or not is_instance_valid(_squad_unlock_slot):
		return
	if not _squad_unlock_slot.is_unlockable:
		return
	var cost := GameState.troop.next_squad_unlock_cost()
	if cost < 0:
		return
	_squad_unlock_slot.setup_unlockable(cost)


func _build_squad_ui() -> void:
	for child in _squad_slot_row.get_children():
		_squad_slot_row.remove_child(child)
		child.queue_free()
	_squad_slots.clear()
	_squad_unlock_slot = null
	_compost_bin = null

	var troop := GameState.troop
	for i in troop.unlocked_squad_count:
		var slot: DropSlot = _DROP_SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.floor_tint = drop_slot_tint
		slot.unit_dropped.connect(_on_unit_dropped.bind("squad"))
		_squad_slot_row.add_child(slot)
		_squad_slots.append(slot)
	if troop.can_unlock_squad_slot() and GameState.is_feature_available(&"squad_slots"):
		var unlock_slot: DropSlot = _DROP_SLOT_SCENE.instantiate()
		unlock_slot.slot_index = troop.unlocked_squad_count
		unlock_slot.floor_tint = drop_slot_tint
		unlock_slot.unlock_pressed.connect(_on_squad_unlock_pressed)
		_squad_slot_row.add_child(unlock_slot)
		unlock_slot.setup_unlockable(troop.next_squad_unlock_cost())
		_squad_unlock_slot = unlock_slot
	if not GameState.is_feature_available(&"compost"):
		return
	# Leave room for the unlock button, which extends beyond its squad slot.
	var compost_spacing := Control.new()
	compost_spacing.name = "CompostSpacing"
	compost_spacing.custom_minimum_size.x = _COMPOST_BIN_SPACING
	compost_spacing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_squad_slot_row.add_child(compost_spacing)
	# Composting is a separate control, never a fighting or purchase slot.
	_compost_bin = _COMPOST_BIN_SCENE.instantiate() as CompostingBin
	_compost_bin.unit_dropped_on_bin.connect(_on_compost_drop)
	_compost_bin.mouse_entered.connect(GuidedRunHints.record_compost_hover)
	_squad_slot_row.add_child(_compost_bin)


func _build_bench_ui() -> void:
	for child in _bench_grid.get_children():
		child.queue_free()
	_bench_slots.clear()
	for i in BENCH_SLOT_COUNT:
		var slot: DropSlot = _DROP_SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.floor_tint = drop_slot_tint
		slot.unit_dropped.connect(_on_unit_dropped.bind("bench"))
		_bench_grid.add_child(slot)
		_bench_slots.append(slot)


func _build_cocoon_ui() -> void:
	if _cocoon_row == null:
		return
	for child in _cocoon_row.get_children():
		child.queue_free()
	_cocoon_slots.clear()
	for school in WeaponSchool.DISPLAY_ORDER:
		var slot := _COCOON_SLOT_SCENE.instantiate() as CocoonSlot
		if slot == null:
			continue
		slot.school = school
		slot.unit_dropped_on_cocoon.connect(_on_cocoon_drop)
		if school == WeaponSchool.Id.SHIELD:
			slot.mouse_entered.connect(GuidedRunHints.record_shield_hover)
		elif school == WeaponSchool.Id.SPEAR:
			slot.mouse_entered.connect(GuidedRunHints.record_spear_hover)
		# Keep each background socket reserved when a guided school is hidden.
		var socket := MarginContainer.new()
		socket.custom_minimum_size = slot.custom_minimum_size
		socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cocoon_row.add_child(socket)
		socket.add_child(slot)
		_cocoon_slots.append(slot)
	_refresh_guided_visibility()


func _refresh_guided_visibility() -> void:
	var has_school := false
	for slot: CocoonSlot in _cocoon_slots:
		slot.visible = GameState.is_school_available(slot.school)
		has_school = has_school or slot.visible
	%CocoonPanel.visible = has_school
	_bench_panel.visible = GameState.is_feature_available(&"bench")


func _ensure_starter_choice() -> void:
	# Dialog teardown can defer this until after Base has left the scene tree.
	if not is_inside_tree():
		return
	if GameState.is_guided_run or GameState.troop.is_seeded():
		return
	if GameState.pending_seal_choice:
		return
	if _seal_dialog != null and is_instance_valid(_seal_dialog):
		return
	if _starter_dialog != null and is_instance_valid(_starter_dialog):
		return
	_cancel_cocoon_drag_preview()
	_cancel_presentations()
	var dialog: StarterChoiceDialog = _STARTER_CHOICE_SCENE.instantiate()
	_starter_dialog = dialog
	dialog.package_chosen.connect(_on_starter_package_chosen)
	dialog.tree_exited.connect(_on_starter_dialog_closed.bind(dialog))
	# Parent into HudRoot so the modal stacks above the biomass chip / top bar.
	var hud := _hud_root()
	if hud != null:
		dialog.z_index = 100
		hud.add_child(dialog)
	else:
		add_child(dialog)


func _hud_root() -> Control:
	var base := get_tree().current_scene
	if base == null:
		return null
	return base.get_node_or_null("HudLayer/HudRoot") as Control


func _on_starter_package_chosen(package_id: StringName) -> void:
	_starter_dialog = null
	var snapshot := GameState.base_undo.capture("Choose Starter")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:starter:%s" % [GameState.run_seed, package_id])
	var units := StarterPackages.build_units(package_id, rng)
	GameState.troop.seed_if_empty(units)
	GameState.base_undo.record(snapshot)
	Audio.play_ui_cue(Sfx.Cue.SEAL)
	bench = GameState.troop.bench
	squad = GameState.troop.squad
	_sync_all_slots()
	_notify_start_combat_state()
	Analytics.maybe_start_day()


func _on_starter_dialog_closed(dialog: StarterChoiceDialog) -> void:
	if _starter_dialog != null and _starter_dialog != dialog:
		return
	_starter_dialog = null
	# Recreate if closed without a choice (should not happen for blocking dialog).
	call_deferred("ensure_pending_modals")


func _ensure_flag_seals_overlay() -> void:
	if _flag_seals != null and is_instance_valid(_flag_seals):
		return
	if _flag_bearer == null:
		return
	var flag := _flag_bearer.get_node_or_null("Shroom/Flag") as Node2D
	if flag == null:
		return
	_flag_seals = _FLAG_SEALS_SCENE.instantiate() as FlagSealsOverlay
	flag.add_child(_flag_seals)
	_refresh_flag_seals()


func _refresh_flag_seals() -> void:
	if _flag_bearer != null:
		_flag_bearer.visible = GameState.should_show_player_flag_bearer()
	if _flag_seals != null and is_instance_valid(_flag_seals):
		_flag_seals.refresh()


func _ensure_seal_choice() -> void:
	# Dialog teardown can defer this until after Base has left the scene tree.
	if not is_inside_tree():
		return
	if not GameState.pending_seal_choice:
		return
	if _starter_dialog != null and is_instance_valid(_starter_dialog):
		return
	if _seal_dialog != null and is_instance_valid(_seal_dialog):
		return
	var offers := GameState.ensure_seal_choice_offers()
	if offers.is_empty():
		GameState.clear_pending_seal_choice()
		_sync_all_slots()
		return
	_cancel_cocoon_drag_preview()
	_cancel_presentations()
	var dialog: SealChoiceDialog = _SEAL_CHOICE_SCENE.instantiate()
	dialog.setup(offers, GameState.can_reroll_seals(), GameState.seal_rerolls_this_pick)
	_seal_dialog = dialog
	dialog.seal_chosen.connect(_on_seal_chosen)
	dialog.tree_exited.connect(_on_seal_dialog_closed.bind(dialog))
	dialog.visibility_changed.connect(_notify_start_combat_state)
	var hud := _hud_root()
	if hud != null:
		dialog.base_action_button = hud.get_node("%StartCombatButton") as Button
		dialog.z_index = 100
		hud.add_child(dialog)
	else:
		add_child(dialog)
	_notify_start_combat_state()


func is_seal_choice_visible() -> bool:
	return is_instance_valid(_seal_dialog) and _seal_dialog.is_visible_in_tree()


func hide_seal_choice() -> void:
	if is_seal_choice_visible():
		_seal_dialog.hide()
		_queue_emergence_presentation()


func toggle_seal_choice() -> void:
	if not GameState.pending_seal_choice:
		return
	if not is_instance_valid(_seal_dialog):
		_ensure_seal_choice()
	elif _seal_dialog.visible:
		hide_seal_choice()
	else:
		_cancel_cocoon_drag_preview()
		_cancel_presentations()
		_seal_dialog.reopen()


func _on_seal_chosen(seal: SealData) -> void:
	_seal_dialog = null
	var snapshot := GameState.base_undo.capture("Choose Seal")
	if GameState.try_add_seal(seal):
		Audio.play_ui_cue(Sfx.Cue.SEAL)
	GameState.clear_pending_seal_choice()
	GameState.base_undo.record(snapshot)
	_refresh_flag_seals()
	_sync_all_slots()
	_notify_start_combat_state()
	_refresh_base_hud()


func _on_seal_dialog_closed(dialog: SealChoiceDialog) -> void:
	if _seal_dialog == dialog:
		_seal_dialog = null
	call_deferred("ensure_pending_modals")
	_queue_emergence_presentation()


func _row(source: String) -> Array:
	return bench if source == "bench" else squad


func _first_empty(row: Array) -> int:
	for i in row.size():
		if row[i] == null:
			return i
	return -1


func _on_unit_card_clicked(card: UnitCard) -> void:
	var unit := card.unit_data as RosterUnitData
	if unit == null:
		return

	if card.source == "bench":
		var dest := GameState.troop.first_empty_unlocked_squad()
		if dest < 0:
			return
		_move_unit(unit, "bench", card.slot.slot_index if card.slot else -1, "squad", dest)
		return

	if card.source == "squad":
		var dest := _first_empty(bench)
		if dest < 0:
			return
		_move_unit(unit, "squad", card.slot.slot_index if card.slot else -1, "bench", dest)


func _on_unit_dropped(slot: DropSlot, drag_data: Dictionary, dest_source: String) -> void:
	if slot == null or slot.is_unlockable:
		return
	var unit: RosterUnitData = drag_data.get("unit") as RosterUnitData
	if unit == null:
		return
	var source := str(drag_data.get("source", "bench"))
	var source_slot: DropSlot = drag_data.get("slot") as DropSlot
	if source_slot == null:
		return
	if source == dest_source and source_slot == slot:
		return
	_move_unit(unit, source, source_slot.slot_index, dest_source, slot.slot_index)


func _move_unit(
	unit: RosterUnitData,
	from_source: String,
	from_index: int,
	to_source: String,
	to_index: int
) -> void:
	if is_instance_valid(_compost_release):
		return
	if (from_source == "bench" or to_source == "bench") and not _is_bench_available():
		return
	var from_row := _row(from_source)
	var to_row := _row(to_source)
	if to_source == "squad" and not GameState.troop.is_squad_slot_unlocked(to_index):
		return
	if from_index < 0 or from_index >= from_row.size():
		return
	if to_index < 0 or to_index >= to_row.size():
		return
	if from_row[from_index] != unit:
		# Click path may pass index from card.slot; fall back to search.
		from_index = from_row.find(unit)
		if from_index < 0:
			return
	var displaced: RosterUnitData = to_row[to_index]
	if unit == _revealing_unit or displaced == _revealing_unit:
		_cancel_emergence()
	var snapshot := GameState.base_undo.capture("Move Unit")
	to_row[to_index] = unit
	from_row[from_index] = displaced
	GameState.base_undo.record(snapshot)
	Audio.play_ui_cue(Sfx.Cue.MOVE)
	_sync_all_slots()


func _is_bench_available() -> bool:
	return GameState.is_feature_available(&"bench") and _bench_panel.is_visible_in_tree()


func _bench_can_drop(_at_position: Vector2, data: Variant) -> bool:
	if is_instance_valid(_compost_release) or not _is_bench_available():
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return str(data.get("source", "")) == "squad" and _first_empty(bench) >= 0


func _bench_drop(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var unit: RosterUnitData = data.get("unit") as RosterUnitData
	var source_slot: DropSlot = data.get("slot") as DropSlot
	var dest := _first_empty(bench)
	if unit == null or source_slot == null or dest < 0:
		return
	_move_unit(unit, "squad", source_slot.slot_index, "bench", dest)


func _on_squad_unlock_pressed(_slot: DropSlot) -> void:
	if not GameState.is_feature_available(&"squad_slots"):
		return
	if is_instance_valid(_compost_release):
		return
	var snapshot := GameState.base_undo.capture("Unlock Squad Slot")
	if GameState.try_unlock_squad_slot():
		GameState.base_undo.record(snapshot)
		_cancel_emergence()
		Audio.play_ui_cue(Sfx.Cue.UNLOCK)
		_build_squad_ui()
		_sync_all_slots()
		_refresh_base_hud()


func _sync_all_slots() -> void:
	if not is_inside_tree():
		return
	bench = GameState.troop.bench
	squad = GameState.troop.squad
	for slot in _squad_slots:
		slot.accepts_drops = not is_instance_valid(_compost_release)
		_sync_slot_card(slot, "squad")
	for slot in _bench_slots:
		slot.accepts_drops = _is_bench_available() and not is_instance_valid(_compost_release)
		_sync_slot_card(slot, "bench")
	for slot in _cocoon_slots:
		slot.sync_from_state()
	if _compost_bin != null:
		_compost_bin.sync_from_state()
	_notify_start_combat_state()


func _has_active_reveal() -> bool:
	# Serialize presentation effects; Cocoon emergence does not gate gameplay.
	return is_instance_valid(_emergence) or is_instance_valid(_compost_release)


func _has_open_cocoon_dialog() -> bool:
	if is_instance_valid(_compost_release):
		return true
	if _pupation_dialog != null and is_instance_valid(_pupation_dialog):
		return true
	if _compost_dialog != null and is_instance_valid(_compost_dialog):
		return true
	return false


func _on_cocoon_drop(slot: CocoonSlot, drag_data: Dictionary) -> void:
	var unit := drag_data.get("unit") as RosterUnitData
	if unit == null or slot == null:
		return
	if _has_open_cocoon_dialog():
		return
	if not GameState.can_cocoon_for_pupation(unit, slot.school):
		return
	_open_pupation_confirm(unit, slot.school)


func _on_compost_drop(slot: CompostingBin, drag_data: Dictionary) -> void:
	var unit := drag_data.get("unit") as RosterUnitData
	if unit == null or slot == null:
		return
	if _has_open_cocoon_dialog():
		return
	if not GameState.can_compost_unit(unit):
		return
	_open_compost_confirm(unit)


func _open_pupation_confirm(unit: RosterUnitData, school: int) -> void:
	if not GameState.is_school_available(school):
		return
	if is_instance_valid(_compost_release):
		return
	# Reusing this Unit or Cocoon takes priority over its cosmetic flight.
	if (
		unit == _revealing_unit
		or (is_instance_valid(_revealing_cocoon) and _revealing_cocoon.school == school)
	):
		_cancel_emergence()
	_cancel_cocoon_drag_preview()
	var dialog: PupationConfirmDialog = _PUPATION_CONFIRM_SCENE.instantiate()
	_pupation_dialog = dialog
	_pending_pupation_unit = unit
	dialog.confirmed.connect(_on_pupation_confirmed)
	dialog.tree_exited.connect(_on_pupation_dialog_closed.bind(dialog))
	var hud := _hud_root()
	if hud != null:
		hud.add_child(dialog)
	else:
		add_child(dialog)
	dialog.setup(unit, school)
	_sync_all_slots()
	Audio.play_ui_cue(Sfx.Cue.UI_OPEN)


func _open_compost_confirm(unit: RosterUnitData) -> void:
	if not GameState.is_feature_available(&"compost"):
		return
	if is_instance_valid(_compost_release):
		return
	_cancel_cocoon_drag_preview()
	var dialog: CompostConfirmDialog = _COMPOST_CONFIRM_SCENE.instantiate()
	_compost_dialog = dialog
	dialog.confirmed.connect(_on_compost_confirmed)
	dialog.tree_exited.connect(_on_compost_dialog_closed.bind(dialog))
	var hud := _hud_root()
	if hud != null:
		hud.add_child(dialog)
	else:
		add_child(dialog)
	dialog.setup(unit)
	Audio.play_ui_cue(Sfx.Cue.UI_OPEN)


func _cancel_cocoon_drag_preview() -> void:
	for slot: CocoonSlot in _cocoon_slots:
		if slot._drag_preview_unit != null:
			get_viewport().gui_cancel_drag()
			return


func _queue_emergence_presentation() -> void:
	if not _screen_active or GameState.pending_cocoon_emergences.is_empty():
		return
	# Let freshly rebuilt destination cards settle before capturing their poses.
	# Base also installs its camera tween after on_screen_shown returns.
	_emergence_ready_frame = Engine.get_process_frames() + 2
	set_process(true)


func _process(_delta: float) -> void:
	_try_play_next_emergence()


func _try_play_next_emergence() -> void:
	if not is_inside_tree() or not _screen_active or get_tree().paused:
		return
	if _has_active_reveal() or Engine.get_process_frames() < _emergence_ready_frame:
		return
	if GameState.pending_cocoon_emergences.is_empty():
		set_process(false)
		_notify_start_combat_state()
		return
	if (
		not GameState.troop.is_seeded()
		or is_instance_valid(_starter_dialog) or is_seal_choice_visible()
		or _has_open_cocoon_dialog() or get_viewport().gui_is_dragging()
		or SceneTransition.is_transitioning()
	):
		return
	var base := get_tree().current_scene
	if base != null and base.has_method("is_tab_transitioning") and base.is_tab_transitioning():
		return
	while not GameState.pending_cocoon_emergences.is_empty():
		var entry: Dictionary = GameState.pending_cocoon_emergences.pop_front()
		if not GameState.is_cocoon_emergence_current(entry):
			continue
		var unit := entry.get("unit") as RosterUnitData
		var cocoon: CocoonSlot = null
		for slot: CocoonSlot in _cocoon_slots:
			if slot.school == int(entry.get("school", -1)):
				cocoon = slot
				break
		if cocoon == null:
			continue
		var card := _find_unit_card(unit)
		if card == null:
			continue
		var destinations: Array[Transform2D] = [card.portrait_canvas_transform()]
		_cancel_cocoon_drag_preview()
		_revealing_unit = unit
		_revealing_cocoon = cocoon
		var shell := cocoon.begin_emergence()
		var host := _hud_root()
		var units: Array[RosterUnitData] = [unit]
		_emergence = UnitEmergence.play(host if host != null else self, units, shell, UnitEmergence.Kind.COCOON, destinations)
		_emergence.finished.connect(_on_emergence_ended.bind(_emergence.get_instance_id()))
		_emergence.cancelled.connect(_on_emergence_ended.bind(_emergence.get_instance_id()))
		card.set_emergence_hidden(true)
		set_process(false)
		return
	set_process(false)
	_notify_start_combat_state()


func _on_emergence_ended(instance_id: int) -> void:
	if not is_instance_valid(_emergence) or _emergence.get_instance_id() != instance_id:
		return
	var phase := 0.0
	if not _emergence._actors.is_empty():
		phase = _emergence._actors[0].animation_player.current_animation_position
	_emergence = null
	_restore_emergence_sources(phase)
	_queue_emergence_presentation()


func _restore_emergence_sources(phase: float = -1.0) -> void:
	var unit := _revealing_unit
	_revealing_unit = null
	if is_instance_valid(_revealing_cocoon):
		_revealing_cocoon.end_emergence()
	_revealing_cocoon = null
	# Presentation completion must not rebuild the Troop or restart idle animations.
	var card := _find_unit_card(unit)
	if card == null:
		return
	card.set_emergence_hidden(false)
	if phase >= 0.0 and card._portrait_instance is UnitAppearance:
		var actor := card._portrait_instance as UnitAppearance
		actor.animation_player.seek(phase, true)


func _find_unit_card(unit: RosterUnitData) -> UnitCard:
	if unit == null:
		return null
	for slots in [_squad_slots, _bench_slots]:
		for slot: DropSlot in slots:
			for child in slot.get_node("%CardHost").get_children():
				if child is UnitCard and (child as UnitCard).unit_data == unit:
					return child as UnitCard
	return null


func _cancel_emergence() -> void:
	if not is_instance_valid(_emergence):
		return
	var effect := _emergence
	# cancel emits synchronously; detach first so its callback cannot drain a queue.
	_emergence = null
	effect.cancel()
	_restore_emergence_sources()
	_queue_emergence_presentation()


func _cancel_presentations() -> void:
	_cancel_emergence()
	_cancel_compost_release()
	_cancel_compost_gain()


func _cancel_compost_gain() -> void:
	if is_instance_valid(_compost_gain):
		_compost_gain.cancel()
	_compost_gain = null


func _on_compost_release_ended(instance_id: int) -> void:
	if not is_instance_valid(_compost_release) or _compost_release.get_instance_id() != instance_id:
		return
	_compost_release = null
	if is_instance_valid(_compost_bin):
		_compost_bin.end_release()
	_sync_all_slots()
	_queue_emergence_presentation()


func _cancel_compost_release() -> void:
	if not is_instance_valid(_compost_release):
		return
	var effect := _compost_release
	_compost_release = null
	effect.cancel()
	if is_instance_valid(_compost_bin):
		_compost_bin.end_release()
	_sync_all_slots()


func _exit_tree() -> void:
	_screen_active = false
	_cancel_compost_gain()
	if is_instance_valid(_emergence):
		var effect := _emergence
		_emergence = null
		effect.cancel()
	if is_instance_valid(_compost_release):
		var effect := _compost_release
		_compost_release = null
		effect.cancel()


func _on_pupation_confirmed(unit: RosterUnitData, school: int) -> void:
	if is_instance_valid(_compost_release):
		return
	_pupation_dialog = null
	_pending_pupation_unit = null
	var completes_now := unit.effective_cocoon_days() <= 0
	var snapshot := GameState.base_undo.capture("Train" if unit.is_adult_stage() else "Evolve")
	if GameState.try_cocoon_for_pupation(unit, school):
		GameState.base_undo.record(snapshot)
		# A reused Cocoon must not later show its previous occupant emerging.
		for i in range(GameState.pending_cocoon_emergences.size() - 1, -1, -1):
			if int(GameState.pending_cocoon_emergences[i].get("school", -1)) == school:
				GameState.pending_cocoon_emergences.remove_at(i)
		if completes_now:
			GameState.queue_cocoon_emergence(unit, school)
			_queue_emergence_presentation()
		else:
			Audio.play_ui_cue(Sfx.Cue.TRAIN)
	_sync_all_slots()
	_refresh_base_hud()


func _on_compost_confirmed(unit: RosterUnitData) -> void:
	if is_instance_valid(_compost_release):
		return
	_compost_dialog = null
	var snapshot := GameState.base_undo.capture("Compost")
	var previous_stock: Array = GameState.nursery.stock.slots.duplicate()
	var previous_biomass := GameState.biomass.amount
	if GameState.try_compost_unit(unit):
		GameState.base_undo.record(snapshot)
		_cancel_emergence()
		var released_spores: Array[SporeData] = []
		for item in GameState.nursery.stock.slots:
			if item is SporeData and not previous_stock.has(item):
				released_spores.append(item as SporeData)
		if is_instance_valid(_compost_bin):
			var bin_snapshot := _compost_bin.begin_release()
			var host := _hud_root()
			_compost_release = CompostRelease.play(host if host != null else self, bin_snapshot, released_spores)
			var instance_id := _compost_release.get_instance_id()
			_compost_release.finished.connect(_on_compost_release_ended.bind(instance_id))
			_compost_release.cancelled.connect(_on_compost_release_ended.bind(instance_id))
			_cancel_compost_gain()
			var base := get_tree().current_scene
			var counter := base.get_node_or_null("%BiomassChip") as BiomassChip
			var gained := GameState.biomass.amount - previous_biomass
			if counter != null and gained > 0:
				_compost_gain = BiomassGain.play(
					host if host != null else self, _compost_release.biomass_source_canvas_rect(),
					gained, counter, false, CompostRelease.ANTICIPATION_SECONDS
				)
		else:
			Audio.play_ui_cue(Sfx.Cue.COMPOST)
		_sync_all_slots()
		_refresh_base_hud()


func _on_pupation_dialog_closed(dialog: PupationConfirmDialog) -> void:
	if _pupation_dialog != dialog:
		_queue_emergence_presentation()
		return
	_pupation_dialog = null
	if _pending_pupation_unit != null:
		_pending_pupation_unit = null
		call_deferred("_sync_all_slots")
	_queue_emergence_presentation()


func _on_compost_dialog_closed(dialog: CompostConfirmDialog) -> void:
	if _compost_dialog == dialog:
		_compost_dialog = null
	_queue_emergence_presentation()


func _refresh_base_hud() -> void:
	var base := get_tree().current_scene
	if base != null and base.has_method("_refresh_hud"):
		base._refresh_hud()


func _sync_slot_card(slot: DropSlot, source: String) -> void:
	var row := _row(source)
	var unit: RosterUnitData = row[slot.slot_index] if slot.slot_index < row.size() else null
	slot.clear_card()
	# Keep the source slot empty during the training preview, including after drag-end.
	if unit == null or unit == _pending_pupation_unit:
		return
	var card: UnitCard = _UNIT_CARD_SCENE.instantiate()
	card.setup(unit, source, slot)
	card.clicked.connect(_on_unit_card_clicked)
	slot.set_card(card)
	card.set_training_hint_visible(unit == get_training_hint_unit())
	if unit == _revealing_unit:
		card.set_emergence_hidden(true)
		return
	# Keep the destination laid out without flashing the result before its launch.
	for entry in GameState.pending_cocoon_emergences:
		if entry.get("unit") == unit and GameState.is_cocoon_emergence_current(entry):
			card.set_emergence_hidden(true)
			break


func get_training_hint_unit() -> RosterUnitData:
	if GameState.is_guided_run:
		return null
	if not GameState.show_start_combat_hint or GameState.current_day != 0:
		return null
	if GameState.pending_seal_choice:
		return null
	# Once the starter Child enters a cocoon, guide the player to the first battle.
	for row in [GameState.troop.squad, GameState.troop.bench]:
		for entry in row:
			var unit := entry as RosterUnitData
			if unit != null and not unit.is_adult_stage():
				return unit
	return null


func can_start_combat() -> bool:
	if GameState.pending_seal_choice or is_instance_valid(_compost_release):
		return false
	return _squad_unit_count() > 0


func start_combat() -> void:
	if not can_start_combat():
		return
	_cancel_presentations()
	GameState.pending_cocoon_emergences.clear()
	GameState.base_undo.end_visit()
	var enemy_roster := GameState.make_upcoming_enemy_roster()
	GameState.capture_guided_battle_checkpoint(enemy_roster)
	BattleLaunch.set_enemy_roster(enemy_roster)
	SceneTransition.change_scene("res://assets/combat/combat_stage/combat_stage.tscn")


func _notify_start_combat_state() -> void:
	var base := get_tree().current_scene
	if base != null and base.has_method("set_start_combat_enabled"):
		base.set_start_combat_enabled(can_start_combat())


func _squad_unit_count() -> int:
	var count := 0
	for entry in squad:
		if entry != null:
			count += 1
	return count


## Resolve an optional arrow to live visuals without changing preparation state.
func get_guided_hint_target(hint: Dictionary) -> Control:
	var target: Control
	match StringName(hint.get("target", &"")):
		&"unit":
			target = _find_unit_card(hint.get("unit") as RosterUnitData)
		&"school":
			var school := int(hint.get("school", -1))
			for slot: CocoonSlot in _cocoon_slots:
				if slot.school == school:
					target = slot.get_node_or_null("%CocoonImage") as Control
					break
		&"formation":
			if not _squad_slots.is_empty():
				target = _squad_slots[0].get_node_or_null("%CardHost") as Control
		&"squad_slot":
			if is_instance_valid(_squad_unlock_slot):
				target = _squad_unlock_slot.get_node_or_null("%UnlockButton") as Control
		&"compost":
			if is_instance_valid(_compost_bin):
				target = _compost_bin.get_node_or_null("%BinImage") as Control
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return null
	if not target.is_visible_in_tree() or target.modulate.a <= 0.0:
		return null
	return target


func is_guided_hint_blocked() -> bool:
	return (
		_has_active_reveal()
		or _has_open_cocoon_dialog()
		or is_seal_choice_visible()
		or (is_instance_valid(_starter_dialog) and _starter_dialog.is_visible_in_tree())
	)
