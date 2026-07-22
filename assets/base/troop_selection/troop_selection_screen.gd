class_name TroopSelectionScreen
extends BaseScreen

const SQUAD_SLOT_COUNT := TroopData.SQUAD_SLOT_COUNT
const BENCH_SLOT_COUNT := TroopData.BENCH_SLOT_COUNT
const _UNIT_CARD_SCENE := preload("res://assets/base/unit_card/unit_card.tscn")
const _DROP_SLOT_SCENE := preload("res://assets/base/drop_slot/drop_slot.tscn")
const _MELEE_WEAPON := preload("res://assets/weapons/basic_melee/basic_melee.tres")
const _SPEAR_WEAPON := preload("res://assets/weapons/basic_spear/basic_spear.tres")
const _BOW_WEAPON := preload("res://assets/weapons/basic_bow/basic_bow.tres")

var bench: Array = []
var squad: Array = []

@onready var _squad_rows: VBoxContainer = %SquadRows
@onready var _bench_grid: HBoxContainer = %BenchGrid
@onready var _bench_panel: PanelContainer = %BenchPanel
@onready var _scout_bubble: ScoutBubble = %ScoutBubble

var _squad_slots: Array[DropSlot] = []
var _bench_slots: Array[DropSlot] = []


func _ready() -> void:
	_hydrate_from_troop_data()
	_build_squad_ui()
	_build_bench_ui()
	_sync_all_slots()
	_bench_panel.set_drag_forwarding(Callable(), _bench_can_drop, _bench_drop)
	_set_bench_structure_mouse_ignore()
	if _scout_bubble != null:
		_scout_bubble.refresh()
	_notify_start_combat_state()


func on_screen_shown() -> void:
	_sync_all_slots()
	if _scout_bubble != null:
		_scout_bubble.refresh()
	_notify_start_combat_state()


func _hydrate_from_troop_data() -> void:
	if not GameState.troop.is_seeded():
		GameState.troop.seed_if_empty(_make_default_starters())
	bench = GameState.troop.bench
	squad = GameState.troop.squad


func _set_bench_structure_mouse_ignore() -> void:
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
	title.text = "Troop (%d slots)" % SQUAD_SLOT_COUNT
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


func _make_default_starters() -> Array[RosterUnitData]:
	var names := UnitNames.pick_unique(3)
	var weapons: Array[WeaponData] = [_BOW_WEAPON, _SPEAR_WEAPON, _MELEE_WEAPON]
	var units: Array[RosterUnitData] = []
	for i in names.size():
		units.append(_make_unit(names[i], UnitStatsData.PowerTier.COMMON, weapons[i]))
	return units


func _make_unit(
	unit_name: String,
	tier: UnitStatsData.PowerTier,
	weapon: WeaponData
) -> RosterUnitData:
	return RosterUnitData.create(unit_name, UnitStatsData.create_for_tier(tier), weapon, null, tier)


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
	for slot in _squad_slots:
		_sync_slot_card(slot, "squad")
	for slot in _bench_slots:
		_sync_slot_card(slot, "bench")
	_notify_start_combat_state()


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
		var unit := _make_unit(UnitNames.pick(), spec.tier, _weapon_for_enemy_type(spec.type))
		if spec.is_imago:
			unit.promote_to_imago()
		enemy.append(unit)
	return enemy


func _weapon_for_enemy_type(unit_type: EnemyUnitSpec.UnitType) -> WeaponData:
	match unit_type:
		EnemyUnitSpec.UnitType.SPEAR:
			return _SPEAR_WEAPON
		EnemyUnitSpec.UnitType.BOW:
			return _BOW_WEAPON
		_:
			return _MELEE_WEAPON
