class_name ScoutBubble
extends Control

signal elite_focus_changed(day: int)

const _SCOUT_ENTRY_SCENE := preload(
	"res://assets/base/troop_selection/scout_bubble/scout_enemy_entry.tscn"
)

@onready var _scout_title: Label = %ScoutTitle
@onready var _scout_row: HBoxContainer = %ScoutRow
@onready var _scout_reward_label: Label = %ScoutRewardLabel
@onready var _scout_reroll_button: Button = %ScoutRerollButton
@onready var _scout_reroll_cost_label: Label = %ScoutRerollCostLabel
@onready var _next_battle_button: Button = %NextBattleButton

var _previewing: bool = false
var _focused_elite_day: int = 0
## Day used for Battle-reward preview (upcoming day, or elite day while previewing).
var _reward_day: int = 1


func _ready() -> void:
	GameState.biomass.changed.connect(_refresh_reroll_affordability)
	if _scout_reroll_button != null:
		_scout_reroll_button.pressed.connect(_on_scout_reroll_pressed)
		BiomassPreview.bind(_scout_reroll_button, _biomass_preview_delta)
	_next_battle_button.pressed.connect(return_to_next_battle)
	refresh()


func refresh() -> void:
	var had_focus := _focused_elite_day != 0
	_focused_elite_day = 0
	_previewing = false
	GameState.ensure_upcoming_enemy_formation()
	var day := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	var specs := GameState.upcoming_enemy_formation
	show_specs(specs, _title_for_day(day, false), day)
	_refresh_reroll_affordability()
	if had_focus:
		elite_focus_changed.emit(0)


func preview_elite_for_day(day: int) -> void:
	if _focused_elite_day != 0:
		return
	var elite_day := clampi(day, 1, GameState.WIN_DAYS)
	if not GameState.is_elite_day(elite_day):
		return
	var upcoming := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	if elite_day <= upcoming:
		return_to_next_battle()
		return
	_show_elite_preview(elite_day)


func pin_elite_for_day(day: int) -> void:
	var elite_day := clampi(day, 1, GameState.WIN_DAYS)
	if not GameState.is_elite_day(elite_day):
		return
	var upcoming := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	if elite_day <= upcoming:
		return_to_next_battle()
		return
	var changed := _focused_elite_day != elite_day
	_focused_elite_day = elite_day
	_show_elite_preview(elite_day)
	if changed:
		elite_focus_changed.emit(elite_day)


func focused_elite_day() -> int:
	return _focused_elite_day


func return_to_next_battle() -> void:
	if _previewing or _focused_elite_day != 0:
		refresh()


func _show_elite_preview(day: int) -> void:
	# Pinning an already visible hover preview keeps its enemy tooltip targets alive.
	if not _previewing or _reward_day != day:
		_previewing = true
		var specs := EnemyComposer.specs_for_day(day)
		show_specs(specs, _title_for_day(day, true), day)
	_refresh_reroll_affordability()


func clear_preview() -> void:
	if not _previewing or _focused_elite_day != 0:
		return
	refresh()


func show_specs(specs: Array[EnemyUnitSpec], title: String, day: int = -1) -> void:
	if _scout_row == null:
		return
	_reward_day = day if day > 0 else clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	for child in _scout_row.get_children():
		_scout_row.remove_child(child)
		child.queue_free()
	if _scout_title != null:
		_scout_title.text = title
	var type_counts: Dictionary = {}
	# Type rows face the player: Melee → Mid → Ranged (reverse of Home order).
	for i in range(specs.size() - 1, -1, -1):
		var spec: EnemyUnitSpec = specs[i]
		if spec.unit_data == null:
			continue
		var key := spec.unit_data.resource_path
		if key.is_empty():
			key = str(spec.unit_data.id)
		if not type_counts.has(key):
			type_counts[key] = {"count": 0, "unit_data": spec.unit_data}
		type_counts[key]["count"] = int(type_counts[key]["count"]) + 1
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
		_scout_reward_label.text = BiomassDisplay.number(EnemyComposer.battle_reward_for(_reward_day, specs), true)


func _title_for_day(day: int, include_day: bool) -> String:
	var base := "Elite Battle" if GameState.is_elite_day(day) else "Next Battle"
	if include_day:
		return "%s: Day %d" % [base, day]
	return base


func _reroll_allowed() -> bool:
	if _previewing:
		return false
	var day := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	return not GameState.is_elite_day(day)


func _biomass_preview_delta() -> Variant:
	if not _reroll_allowed():
		return null
	return -GameState.current_scout_reroll_cost()


func _refresh_reroll_affordability() -> void:
	var upcoming := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	_next_battle_button.visible = _focused_elite_day > upcoming
	if _scout_reroll_button == null:
		return
	var cost := GameState.current_scout_reroll_cost()
	if _scout_reroll_cost_label != null:
		_scout_reroll_cost_label.text = "%d" % cost
	var allowed := _reroll_allowed()
	_scout_reroll_button.visible = allowed
	if not allowed:
		_scout_reroll_button.disabled = true
		return
	var can_reroll := GameState.biomass.can_afford(cost)
	_scout_reroll_button.disabled = not can_reroll
	_scout_reroll_button.modulate = Color.WHITE if can_reroll else Color(1, 1, 1, 0.45)


func _on_scout_reroll_pressed() -> void:
	if not _reroll_allowed():
		_refresh_reroll_affordability()
		return
	var cost := GameState.current_scout_reroll_cost()
	if not GameState.biomass.try_spend(cost):
		_refresh_reroll_affordability()
		return
	Analytics.biomass_sink("Scout", "Reroll", cost)
	Audio.play_ui_cue(Sfx.Cue.REROLL)
	GameState.advance_scout_reroll_cost()
	var day := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	GameState.ensure_upcoming_enemy_formation()
	GameState.upcoming_enemy_formation = EnemyComposer.reroll_for_day(
		day,
		GameState.upcoming_enemy_formation
	)
	GameState.base_undo.clear()
	refresh()
	_refresh_base_hud()


func _refresh_base_hud() -> void:
	var base := get_tree().current_scene
	if base != null and base.has_method("_refresh_hud"):
		base._refresh_hud()
