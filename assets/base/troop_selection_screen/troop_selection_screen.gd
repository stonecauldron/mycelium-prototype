class_name TroopSelectionScreen
extends BaseScreen

const SQUAD_SLOT_COUNT := 12
const _UNIT_CARD_SCENE := preload("res://assets/base/unit_card/unit_card.tscn")
const _DROP_SLOT_SCENE := preload("res://assets/base/drop_slot/drop_slot.tscn")
const _MELEE_WEAPON := preload("res://assets/weapons/basic_melee.tres")
const _SPEAR_WEAPON := preload("res://assets/weapons/basic_spear.tres")

var bench: Array[RosterUnitData] = []
var squad: Array = []

@onready var _squad_rows: VBoxContainer = %SquadRows
@onready var _bench_grid: HBoxContainer = %BenchGrid
@onready var _bench_panel: PanelContainer = %BenchPanel
@onready var _start_combat_button: Button = %StartCombatButton

var _slots: Array[DropSlot] = []


func _ready() -> void:
	_hydrate_from_troop_data()
	_build_squad_ui()
	_rebuild_bench_ui()
	_sync_all_slots()
	_bench_panel.set_drag_forwarding(Callable(), _bench_can_drop, _bench_drop)
	_set_bench_structure_mouse_ignore()
	_start_combat_button.pressed.connect(_on_start_combat_pressed)
	_refresh_start_combat_button()


func on_screen_shown() -> void:
	GameState.troop.sort_rosters()
	_rebuild_bench_ui()
	_sync_all_slots()
	_refresh_start_combat_button()


func _hydrate_from_troop_data() -> void:
	if not GameState.troop.is_seeded():
		GameState.troop.seed_if_empty(_make_default_bench())
	else:
		GameState.troop.sort_rosters()
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
	_slots.clear()

	var title := Label.new()
	title.theme_type_variation = &"SectionTitleLabel"
	title.text = "Troop (%d slots)" % SQUAD_SLOT_COUNT
	_squad_rows.add_child(title)

	var slots_row := HBoxContainer.new()
	slots_row.theme_type_variation = &"SlotRow"
	slots_row.custom_minimum_size = Vector2(0, 160)
	_squad_rows.add_child(slots_row)

	for i in SQUAD_SLOT_COUNT:
		var slot: DropSlot = _DROP_SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.unit_dropped.connect(_on_slot_unit_dropped)
		slots_row.add_child(slot)
		_slots.append(slot)


func _make_default_bench() -> Array[RosterUnitData]:
	var units: Array[RosterUnitData] = []
	units.append(_make_unit("Fern", UnitStatsData.PowerTier.AVERAGE, _MELEE_WEAPON))
	units.append(_make_unit("Gale", UnitStatsData.PowerTier.AVERAGE, _MELEE_WEAPON))
	units.append(_make_unit("Heather", UnitStatsData.PowerTier.AVERAGE, _MELEE_WEAPON))
	return units


func _make_unit(
	unit_name: String,
	tier: UnitStatsData.PowerTier,
	weapon: WeaponData
) -> RosterUnitData:
	return RosterUnitData.create(unit_name, UnitStatsData.create_for_tier(tier), weapon)


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
	GameState.troop.sort_squad()


func _sort_unit_list(units: Array) -> void:
	units.sort_custom(GameState.troop.compare_units)


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
	BattleLaunch.set_enemy_roster(_make_default_enemy_roster())
	SceneTransition.change_scene("res://assets/combat/combat_stage/combat_stage.tscn")


func _make_default_enemy_roster() -> Array[RosterUnitData]:
	var day := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	var composition := _enemy_composition_for_day(day)
	var enemy: Array[RosterUnitData] = []
	var melee_n: int = int(composition.get("melee", 0))
	var spear_n: int = int(composition.get("spear", 0))
	var tiers: Array = composition.get("tiers", [UnitStatsData.PowerTier.WEAK])
	for i in melee_n:
		var tier: UnitStatsData.PowerTier = tiers[i % tiers.size()]
		enemy.append(_make_unit("Enemy Melee %d" % (i + 1), tier, _MELEE_WEAPON))
	for i in spear_n:
		var tier: UnitStatsData.PowerTier = tiers[(melee_n + i) % tiers.size()]
		enemy.append(_make_unit("Enemy Spear %d" % (i + 1), tier, _SPEAR_WEAPON))
	return enemy


func _enemy_composition_for_day(day: int) -> Dictionary:
	match day:
		1, 2:
			return {
				"melee": 2,
				"spear": 0,
				"tiers": [UnitStatsData.PowerTier.WEAK],
			}
		3, 4:
			return {
				"melee": 2,
				"spear": 1,
				"tiers": [
					UnitStatsData.PowerTier.WEAK,
					UnitStatsData.PowerTier.WEAK,
					UnitStatsData.PowerTier.AVERAGE,
				],
			}
		5, 6:
			return {
				"melee": 3,
				"spear": 2,
				"tiers": [
					UnitStatsData.PowerTier.WEAK,
					UnitStatsData.PowerTier.AVERAGE,
				],
			}
		7, 8:
			return {
				"melee": 4,
				"spear": 2,
				"tiers": [
					UnitStatsData.PowerTier.AVERAGE,
					UnitStatsData.PowerTier.AVERAGE,
					UnitStatsData.PowerTier.STRONG,
				],
			}
		9:
			return {
				"melee": 4,
				"spear": 3,
				"tiers": [
					UnitStatsData.PowerTier.AVERAGE,
					UnitStatsData.PowerTier.STRONG,
				],
			}
		_:
			# Day 10 finale
			return {
				"melee": 5,
				"spear": 3,
				"tiers": [
					UnitStatsData.PowerTier.STRONG,
					UnitStatsData.PowerTier.STRONG,
					UnitStatsData.PowerTier.AVERAGE,
				],
			}
