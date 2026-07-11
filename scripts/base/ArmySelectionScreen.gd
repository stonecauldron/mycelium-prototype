class_name ArmySelectionScreen
extends BaseScreen

const SQUAD_SLOT_COUNT := 12
const _UNIT_CARD_SCENE := preload("res://scenes/base/UnitCard.tscn")
const _DROP_SLOT_SCENE := preload("res://scenes/base/DropSlot.tscn")
const _MELEE_WEAPON := preload("res://data/weapons/basic_melee.tres")
const _SPEAR_WEAPON := preload("res://data/weapons/basic_spear.tres")

var bench: Array[RosterUnitData] = []
var squad: Array = []

@onready var _squad_rows: VBoxContainer = %SquadRows
@onready var _bench_grid: HBoxContainer = %BenchGrid
@onready var _bench_panel: PanelContainer = %BenchPanel
@onready var _start_combat_button: Button = %StartCombatButton

var _slots: Array[DropSlot] = []


func _ready() -> void:
	_init_squad_model()
	_build_squad_ui()
	_populate_hardcoded_bench()
	_rebuild_bench_ui()
	_bench_panel.set_drag_forwarding(Callable(), _bench_can_drop, _bench_drop)
	_set_bench_structure_mouse_ignore()
	_start_combat_button.pressed.connect(_on_start_combat_pressed)
	_refresh_start_combat_button()


func on_screen_shown() -> void:
	_refresh_start_combat_button()


func _set_bench_structure_mouse_ignore() -> void:
	for path in ["BenchMargin", "BenchMargin/BenchVBox", "BenchMargin/BenchVBox/BenchTitle", "BenchMargin/BenchVBox/BenchGrid"]:
		var node := _bench_panel.get_node_or_null(path) as Control
		if node:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bench_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _init_squad_model() -> void:
	squad.clear()
	squad.resize(SQUAD_SLOT_COUNT)
	squad.fill(null)


func _build_squad_ui() -> void:
	for child in _squad_rows.get_children():
		child.queue_free()
	_slots.clear()

	var title := Label.new()
	title.text = "Army (%d slots)" % SQUAD_SLOT_COUNT
	title.add_theme_font_size_override("font_size", 20)
	_squad_rows.add_child(title)

	var slots_row := HBoxContainer.new()
	slots_row.custom_minimum_size = Vector2(0, 160)
	slots_row.add_theme_constant_override("separation", 8)
	_squad_rows.add_child(slots_row)

	for i in SQUAD_SLOT_COUNT:
		var slot: DropSlot = _DROP_SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.unit_dropped.connect(_on_slot_unit_dropped)
		slots_row.add_child(slot)
		_slots.append(slot)


func _populate_hardcoded_bench() -> void:
	bench.clear()
	bench.append(_make_unit("Ash", UnitStats.PowerTier.AVERAGE, _MELEE_WEAPON))
	bench.append(_make_unit("Bramble", UnitStats.PowerTier.AVERAGE, _MELEE_WEAPON))
	bench.append(_make_unit("Cinder", UnitStats.PowerTier.STRONG, _MELEE_WEAPON))
	bench.append(_make_unit("Drift", UnitStats.PowerTier.WEAK, _MELEE_WEAPON))
	bench.append(_make_unit("Ember", UnitStats.PowerTier.AVERAGE, _MELEE_WEAPON))
	bench.append(_make_unit("Fern", UnitStats.PowerTier.AVERAGE, _SPEAR_WEAPON))
	bench.append(_make_unit("Gale", UnitStats.PowerTier.STRONG, _SPEAR_WEAPON))
	bench.append(_make_unit("Heather", UnitStats.PowerTier.AVERAGE, _SPEAR_WEAPON))
	bench.append(_make_unit("Ivy", UnitStats.PowerTier.WEAK, _SPEAR_WEAPON))
	bench.append(_make_unit("Juniper", UnitStats.PowerTier.AVERAGE, _SPEAR_WEAPON))


func _make_unit(
	unit_name: String,
	tier: UnitStats.PowerTier,
	weapon: WeaponData
) -> RosterUnitData:
	return RosterUnitData.create(unit_name, UnitStats.create_for_tier(tier), weapon)


func _rebuild_bench_ui() -> void:
	_sort_unit_list(bench)
	for child in _bench_grid.get_children():
		child.queue_free()
	for unit in bench:
		var card: UnitCard = _UNIT_CARD_SCENE.instantiate()
		card.setup(unit, "bench", null)
		card.clicked.connect(_on_unit_card_clicked)
		_bench_grid.add_child(card)


func _on_unit_card_clicked(card: UnitCard) -> void:
	var unit := card.unit_data as RosterUnitData
	if unit == null:
		return

	if card.source == "bench":
		if not _add_unit_to_squad(unit):
			return
		bench.erase(unit)
		_sort_squad()
		_sync_all_slots()
		_rebuild_bench_ui()
		return

	if card.source == "squad":
		_remove_unit_from_squad(unit)
		if not bench.has(unit):
			bench.append(unit)
		_sort_squad()
		_sync_all_slots()
		_rebuild_bench_ui()


func _add_unit_to_squad(unit: RosterUnitData) -> bool:
	for i in squad.size():
		if squad[i] == null:
			squad[i] = unit
			return true
	return false


func _remove_unit_from_squad(unit: RosterUnitData) -> void:
	for i in squad.size():
		if squad[i] == unit:
			squad[i] = null
			return


func _on_slot_unit_dropped(slot: DropSlot, drag_data: Dictionary) -> void:
	var unit: RosterUnitData = drag_data.get("unit") as RosterUnitData
	if unit == null:
		return

	var source: String = str(drag_data.get("source", "bench"))
	var source_slot: DropSlot = drag_data.get("slot") as DropSlot

	if source == "squad" and source_slot == slot:
		return

	var displaced: RosterUnitData = squad[slot.slot_index]

	if source == "bench":
		bench.erase(unit)
		squad[slot.slot_index] = unit
		if displaced != null:
			bench.append(displaced)
		_sort_squad()
		_sync_all_slots()
		_rebuild_bench_ui()
		return

	if source == "squad" and source_slot != null:
		squad[source_slot.slot_index] = displaced
		squad[slot.slot_index] = unit
		_sort_squad()
		_sync_all_slots()


func _bench_can_drop(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return str(data.get("source", "")) == "squad"


func _bench_drop(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	if str(data.get("source", "")) != "squad":
		return
	var unit: RosterUnitData = data.get("unit") as RosterUnitData
	var source_slot: DropSlot = data.get("slot") as DropSlot
	if unit == null or source_slot == null:
		return
	squad[source_slot.slot_index] = null
	if not bench.has(unit):
		bench.append(unit)
	_sort_squad()
	_sync_all_slots()
	_rebuild_bench_ui()


func _sort_squad() -> void:
	var occupied: Array = []
	for entry in squad:
		if entry != null:
			occupied.append(entry)

	_sort_unit_list(occupied)

	squad.clear()
	squad.append_array(occupied)
	while squad.size() < SQUAD_SLOT_COUNT:
		squad.append(null)


func _sort_unit_list(units: Array) -> void:
	units.sort_custom(_compare_units)


func _compare_units(a: RosterUnitData, b: RosterUnitData) -> bool:
	var range_a := int(a.get_range_class())
	var range_b := int(b.get_range_class())
	if range_a != range_b:
		return range_a > range_b

	var spd_a := a.stats.spd if a.stats != null else 0
	var spd_b := b.stats.spd if b.stats != null else 0
	if spd_a != spd_b:
		return spd_a > spd_b

	return a.display_name.naturalnocasecmp_to(b.display_name) < 0


func _sync_all_slots() -> void:
	for slot in _slots:
		_sync_slot_card(slot)
	_refresh_start_combat_button()


func _sync_slot_card(slot: DropSlot) -> void:
	var unit: RosterUnitData = squad[slot.slot_index]
	slot.clear_card()
	if unit == null:
		return
	var card: UnitCard = _UNIT_CARD_SCENE.instantiate()
	card.setup(unit, "squad", slot)
	card.clicked.connect(_on_unit_card_clicked)
	slot.set_card(card)


func _refresh_start_combat_button() -> void:
	_start_combat_button.disabled = _squad_unit_count() == 0


func _squad_unit_count() -> int:
	var count := 0
	for entry in squad:
		if entry != null:
			count += 1
	return count


func _on_start_combat_pressed() -> void:
	if _squad_unit_count() == 0:
		return
	BattleLaunch.set_rosters(squad, _make_default_enemy_roster())
	get_tree().change_scene_to_file("res://scenes/CombatStage.tscn")


func _make_default_enemy_roster() -> Array[RosterUnitData]:
	var enemy: Array[RosterUnitData] = []
	for i in 4:
		enemy.append(_make_unit("Enemy Melee %d" % (i + 1), UnitStats.PowerTier.AVERAGE, _MELEE_WEAPON))
	for i in 4:
		enemy.append(_make_unit("Enemy Spear %d" % (i + 1), UnitStats.PowerTier.AVERAGE, _SPEAR_WEAPON))
	return enemy
