class_name ScoutBubble
extends Control

const _SCOUT_ENTRY_SCENE := preload(
	"res://assets/base/troop_selection/scout_bubble/scout_enemy_entry.tscn"
)

@onready var _scout_title: Label = %ScoutTitle
@onready var _scout_row: HBoxContainer = %ScoutRow
@onready var _scout_strain_row: HBoxContainer = %ScoutStrainRow
@onready var _scout_reward_label: Label = %ScoutRewardLabel
@onready var _scout_reroll_button: Button = %ScoutRerollButton
@onready var _scout_reroll_cost_label: Label = %ScoutRerollCostLabel

var _previewing: bool = false


func _ready() -> void:
	if _scout_reroll_button != null:
		_scout_reroll_button.pressed.connect(_on_scout_reroll_pressed)
	if _scout_strain_row != null:
		_scout_strain_row.visible = false
	refresh()


func refresh() -> void:
	_previewing = false
	GameState.ensure_upcoming_enemy_formation()
	var day := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	var specs := GameState.upcoming_enemy_formation
	var title := _title_for_day(day)
	show_specs(specs, title)
	_refresh_reroll_affordability()


func preview_elite_for_day(day: int) -> void:
	var elite_day := clampi(day, 1, GameState.WIN_DAYS)
	if not GameState.is_elite_day(elite_day):
		return
	_previewing = true
	var specs := EnemyComposer.specs_for_day(elite_day)
	show_specs(specs, "Elite Battle: Day %d" % elite_day)
	_refresh_reroll_affordability()


func clear_preview() -> void:
	if not _previewing:
		return
	refresh()


func show_specs(specs: Array[EnemyUnitSpec], title: String) -> void:
	if _scout_row == null:
		return
	for child in _scout_row.get_children():
		child.queue_free()
	if _scout_strain_row != null:
		for child in _scout_strain_row.get_children():
			child.queue_free()
	if _scout_title != null:
		_scout_title.text = title
	var type_counts: Dictionary = {}
	for spec in specs:
		if spec.unit_data == null:
			continue
		var key := spec.unit_data.resource_path
		if key.is_empty():
			key = str(spec.unit_data.id)
		if not type_counts.has(key):
			type_counts[key] = {"count": 0, "unit_data": spec.unit_data}
		type_counts[key]["count"] = int(type_counts[key]["count"]) + 1
	var reward := 0
	for spec in specs:
		if spec.unit_data == null:
			continue
		reward += spec.unit_data.biomass_reward
	for key in type_counts.keys():
		var entry: Dictionary = type_counts[key]
		var count: int = entry["count"]
		if count <= 0:
			continue
		var unit_data: EnemyUnitData = entry["unit_data"]
		var entry_card: ScoutEnemyEntry = _SCOUT_ENTRY_SCENE.instantiate()
		_scout_row.add_child(entry_card)
		entry_card.setup(count, unit_data)
	if _scout_reward_label != null:
		_scout_reward_label.text = "+%d" % reward


func _title_for_day(day: int) -> String:
	if GameState.is_elite_day(day):
		return "Elite Battle: Day %d" % day
	return "Next Battle: Day %d" % day


func _reroll_allowed() -> bool:
	if _previewing:
		return false
	var day := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	return not GameState.is_elite_day(day)


func _refresh_reroll_affordability() -> void:
	if _scout_reroll_button == null:
		return
	if _scout_reroll_cost_label != null:
		_scout_reroll_cost_label.text = "%d" % BiomassData.SCOUT_REROLL_COST
	var allowed := _reroll_allowed()
	_scout_reroll_button.visible = allowed
	if not allowed:
		_scout_reroll_button.disabled = true
		return
	var can_reroll := GameState.biomass.can_afford(BiomassData.SCOUT_REROLL_COST)
	_scout_reroll_button.disabled = not can_reroll
	_scout_reroll_button.modulate = Color.WHITE if can_reroll else Color(1, 1, 1, 0.45)


func _on_scout_reroll_pressed() -> void:
	if not _reroll_allowed():
		_refresh_reroll_affordability()
		return
	if not GameState.biomass.try_spend(BiomassData.SCOUT_REROLL_COST):
		_refresh_reroll_affordability()
		return
	var day := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	GameState.ensure_upcoming_enemy_formation()
	GameState.upcoming_enemy_formation = EnemyComposer.reroll_for_day(
		day,
		GameState.upcoming_enemy_formation
	)
	refresh()
	_refresh_base_hud()


func _refresh_base_hud() -> void:
	var base := get_tree().current_scene
	if base != null and base.has_method("_refresh_hud"):
		base._refresh_hud()
