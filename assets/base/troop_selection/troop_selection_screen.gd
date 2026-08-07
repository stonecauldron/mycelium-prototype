class_name TroopSelectionScreen
extends BaseScreen

const SQUAD_SLOT_COUNT := TroopData.SQUAD_SLOT_COUNT
const BENCH_SLOT_COUNT := TroopData.BENCH_SLOT_COUNT
const _UNIT_CARD_SCENE := preload("res://assets/base/unit_card/unit_card.tscn")
const _DROP_SLOT_SCENE := preload("res://assets/base/drop_slot/drop_slot.tscn")
const _COCOON_SLOT_SCENE := preload("res://assets/base/pupation/cocoon_slot.tscn")
const _PUPATION_CONFIRM_SCENE := preload("res://assets/base/pupation/pupation_confirm_dialog.tscn")
const _STARTER_CHOICE_SCENE := preload("res://assets/base/troop_selection/starter_choice_dialog.tscn")
const _SEAL_CHOICE_SCENE := preload("res://assets/base/seals/seal_choice_dialog.tscn")
const _FLAG_SEALS_SCENE := preload("res://assets/base/seals/flag_seals_overlay.tscn")

var bench: Array = []
var squad: Array = []

@onready var _squad_rows: VBoxContainer = %SquadRows
@onready var _bench_grid: HBoxContainer = %BenchGrid
@onready var _bench_panel: PanelContainer = %BenchPanel
@onready var _cocoon_row: HBoxContainer = %CocoonRow
@onready var _scout_bubble: ScoutBubble = %ScoutBubble

var _squad_slots: Array[DropSlot] = []
var _bench_slots: Array[DropSlot] = []
var _cocoon_slots: Array = []
var _pupation_dialog: PupationConfirmDialog = null
var _starter_dialog: StarterChoiceDialog = null
var _seal_dialog: SealChoiceDialog = null
var _flag_seals: FlagSealsOverlay = null


func _ready() -> void:
	_hydrate_from_troop_data()
	_build_squad_ui()
	_build_bench_ui()
	_build_cocoon_ui()
	_ensure_flag_seals_overlay()
	_sync_all_slots()
	_bench_panel.set_drag_forwarding(Callable(), _bench_can_drop, _bench_drop)
	_set_bench_structure_mouse_ignore()
	if _scout_bubble != null:
		_scout_bubble.refresh()
	_notify_start_combat_state()
	ensure_pending_modals()


func on_screen_shown() -> void:
	_sync_all_slots()
	if _scout_bubble != null:
		_scout_bubble.refresh()
	_refresh_flag_seals()
	_notify_start_combat_state()
	ensure_pending_modals()


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


func _build_squad_ui() -> void:
	for child in _squad_rows.get_children():
		child.queue_free()
	_squad_slots.clear()

	var title := Label.new()
	title.theme_type_variation = &"SectionTitleLabel"
	title.text = "Troop"
	_squad_rows.add_child(title)

	var slots_row := HBoxContainer.new()
	slots_row.theme_type_variation = &"SlotRow"
	slots_row.custom_minimum_size = Vector2(0, 200)
	_squad_rows.add_child(slots_row)

	for i in SQUAD_SLOT_COUNT:
		var slot: DropSlot = _DROP_SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.unit_dropped.connect(_on_unit_dropped.bind("squad"))
		slots_row.add_child(slot)
		_squad_slots.append(slot)


func _build_bench_ui() -> void:
	for child in _bench_grid.get_children():
		child.queue_free()
	_bench_slots.clear()
	for i in BENCH_SLOT_COUNT:
		var slot: DropSlot = _DROP_SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.unit_dropped.connect(_on_unit_dropped.bind("bench"))
		_bench_grid.add_child(slot)
		_bench_slots.append(slot)


func _build_cocoon_ui() -> void:
	if _cocoon_row == null:
		return
	for child in _cocoon_row.get_children():
		child.queue_free()
	_cocoon_slots.clear()
	for school in WeaponSchool.COUNT:
		var slot := _COCOON_SLOT_SCENE.instantiate() as CocoonSlot
		if slot == null:
			continue
		slot.school = school
		slot.unit_dropped_on_cocoon.connect(_on_cocoon_drop)
		_cocoon_row.add_child(slot)
		_cocoon_slots.append(slot)


func _ensure_starter_choice() -> void:
	if GameState.pending_seal_choice:
		return
	if GameState.troop.is_seeded():
		return
	if _seal_dialog != null and is_instance_valid(_seal_dialog):
		return
	if _starter_dialog != null and is_instance_valid(_starter_dialog):
		return
	var dialog: StarterChoiceDialog = _STARTER_CHOICE_SCENE.instantiate()
	_starter_dialog = dialog
	dialog.package_chosen.connect(_on_starter_package_chosen)
	dialog.tree_exited.connect(_on_starter_dialog_closed)
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
	var units := StarterPackages.build_units(package_id)
	GameState.troop.seed_if_empty(units)
	bench = GameState.troop.bench
	squad = GameState.troop.squad
	_sync_all_slots()
	_notify_start_combat_state()


func _on_starter_dialog_closed() -> void:
	_starter_dialog = null
	if not GameState.troop.is_seeded():
		# Recreate if closed without a choice (should not happen for blocking dialog).
		call_deferred("_ensure_starter_choice")


func _ensure_flag_seals_overlay() -> void:
	if _flag_seals != null and is_instance_valid(_flag_seals):
		return
	var flag := get_node_or_null("LowerLaneLayer/FlagBearer/Shroom/Flag") as Node2D
	if flag == null:
		return
	_flag_seals = _FLAG_SEALS_SCENE.instantiate() as FlagSealsOverlay
	flag.add_child(_flag_seals)
	_refresh_flag_seals()


func _refresh_flag_seals() -> void:
	if _flag_seals != null and is_instance_valid(_flag_seals):
		_flag_seals.refresh()


func _ensure_seal_choice() -> void:
	if not GameState.pending_seal_choice:
		return
	if _starter_dialog != null and is_instance_valid(_starter_dialog):
		return
	if _seal_dialog != null and is_instance_valid(_seal_dialog):
		return
	var offers := SealCatalog.roll_offers(3, GameState.seals)
	if offers.is_empty():
		GameState.clear_pending_seal_choice()
		call_deferred("_ensure_starter_choice")
		return
	var dialog: SealChoiceDialog = _SEAL_CHOICE_SCENE.instantiate()
	dialog.setup(offers)
	_seal_dialog = dialog
	dialog.seal_chosen.connect(_on_seal_chosen)
	dialog.tree_exited.connect(_on_seal_dialog_closed)
	var hud := _hud_root()
	if hud != null:
		dialog.z_index = 100
		hud.add_child(dialog)
	else:
		add_child(dialog)


func _on_seal_chosen(seal: SealData) -> void:
	_seal_dialog = null
	GameState.try_add_seal(seal)
	GameState.clear_pending_seal_choice()
	_refresh_flag_seals()
	_sync_all_slots()
	_notify_start_combat_state()
	_refresh_base_hud()
	call_deferred("_ensure_starter_choice")


func _on_seal_dialog_closed() -> void:
	_seal_dialog = null
	if GameState.pending_seal_choice:
		call_deferred("_ensure_seal_choice")
	else:
		call_deferred("_ensure_starter_choice")


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
		var dest := _first_empty(squad)
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
	var from_row := _row(from_source)
	var to_row := _row(to_source)
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
	to_row[to_index] = unit
	from_row[from_index] = displaced
	_sync_all_slots()


func _bench_can_drop(_at_position: Vector2, data: Variant) -> bool:
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


func _sync_all_slots() -> void:
	bench = GameState.troop.bench
	squad = GameState.troop.squad
	for slot in _squad_slots:
		_sync_slot_card(slot, "squad")
	for slot in _bench_slots:
		_sync_slot_card(slot, "bench")
	for slot in _cocoon_slots:
		slot.sync_from_state()
	_notify_start_combat_state()


func _on_cocoon_drop(slot: CocoonSlot, drag_data: Dictionary) -> void:
	var unit := drag_data.get("unit") as RosterUnitData
	if unit == null or slot == null:
		return
	if _pupation_dialog != null and is_instance_valid(_pupation_dialog):
		return
	if not GameState.can_cocoon_for_pupation(unit, slot.school):
		return
	_open_pupation_confirm(unit, slot.school)


func _open_pupation_confirm(unit: RosterUnitData, school: int) -> void:
	var dialog: PupationConfirmDialog = _PUPATION_CONFIRM_SCENE.instantiate()
	_pupation_dialog = dialog
	dialog.confirmed.connect(_on_pupation_confirmed)
	dialog.tree_exited.connect(_on_pupation_dialog_closed)
	add_child(dialog)
	dialog.setup(unit, school)


func _on_pupation_confirmed(unit: RosterUnitData, school: int) -> void:
	_pupation_dialog = null
	if GameState.try_cocoon_for_pupation(unit, school):
		_sync_all_slots()
		_refresh_base_hud()


func _on_pupation_dialog_closed() -> void:
	_pupation_dialog = null


func _refresh_base_hud() -> void:
	var base := get_tree().current_scene
	if base != null and base.has_method("_refresh_hud"):
		base._refresh_hud()


func _sync_slot_card(slot: DropSlot, source: String) -> void:
	var row := _row(source)
	var unit: RosterUnitData = row[slot.slot_index] if slot.slot_index < row.size() else null
	slot.clear_card()
	if unit == null:
		return
	var card: UnitCard = _UNIT_CARD_SCENE.instantiate()
	card.setup(unit, source, slot)
	card.clicked.connect(_on_unit_card_clicked)
	slot.set_card(card)


func can_start_combat() -> bool:
	if GameState.pending_seal_choice:
		return false
	return _squad_unit_count() > 0


func start_combat() -> void:
	if not can_start_combat():
		return
	BattleLaunch.set_enemy_roster(_make_default_enemy_roster())
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


func _make_default_enemy_roster() -> Array[RosterUnitData]:
	GameState.ensure_upcoming_enemy_formation()
	var enemy: Array[RosterUnitData] = []
	for spec in GameState.upcoming_enemy_formation:
		if spec.unit_data == null:
			continue
		var stats := spec.unit_data.make_stats()
		var display_name := spec.unit_data.display_name
		if display_name.is_empty():
			display_name = UnitNames.pick()
		enemy.append(
			RosterUnitData.create_enemy(display_name, stats, spec.unit_data)
		)
	return enemy
