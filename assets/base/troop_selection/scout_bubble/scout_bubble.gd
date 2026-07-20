class_name ScoutBubble
extends Control

const _MELEE_WEAPON := preload("res://assets/weapons/basic_melee/basic_melee.tres")
const _SPEAR_WEAPON := preload("res://assets/weapons/basic_spear/basic_spear.tres")
const _BOW_WEAPON := preload("res://assets/weapons/basic_bow/basic_bow.tres")
const _SCOUT_ENTRY_SCENE := preload(
	"res://assets/base/troop_selection/scout_bubble/scout_weapon_entry.tscn"
)

@onready var _scout_row: HBoxContainer = %ScoutRow
@onready var _scout_reward_label: Label = %ScoutRewardLabel
@onready var _scout_reroll_button: Button = %ScoutRerollButton
@onready var _scout_reroll_cost_label: Label = %ScoutRerollCostLabel


func _ready() -> void:
	if _scout_reroll_button != null:
		_scout_reroll_button.pressed.connect(_on_scout_reroll_pressed)
	refresh()


func refresh() -> void:
	if _scout_row == null:
		return
	for child in _scout_row.get_children():
		child.queue_free()
	GameState.ensure_upcoming_enemy_formation()
	var specs := GameState.upcoming_enemy_formation
	var counts := {
		EnemyUnitSpec.UnitType.MELEE: 0,
		EnemyUnitSpec.UnitType.SPEAR: 0,
		EnemyUnitSpec.UnitType.BOW: 0,
	}
	for spec in specs:
		counts[spec.type] = int(counts[spec.type]) + 1
	var entries: Array = [
		{"count": counts[EnemyUnitSpec.UnitType.MELEE], "weapon": _MELEE_WEAPON},
		{"count": counts[EnemyUnitSpec.UnitType.SPEAR], "weapon": _SPEAR_WEAPON},
		{"count": counts[EnemyUnitSpec.UnitType.BOW], "weapon": _BOW_WEAPON},
	]
	var reward := 0
	for spec in specs:
		reward += BiomassData.reward_for_kill(spec.is_imago)
	for entry in entries:
		var count: int = entry["count"]
		if count <= 0:
			continue
		var weapon: WeaponData = entry["weapon"]
		var entry_card: ScoutWeaponEntry = _SCOUT_ENTRY_SCENE.instantiate()
		_scout_row.add_child(entry_card)
		entry_card.setup(count, weapon)
	if _scout_reward_label != null:
		_scout_reward_label.text = "+%d" % reward
	_refresh_reroll_affordability()


func _refresh_reroll_affordability() -> void:
	if _scout_reroll_button == null:
		return
	if _scout_reroll_cost_label != null:
		_scout_reroll_cost_label.text = "%d" % BiomassData.SCOUT_REROLL_COST
	var can_reroll := GameState.biomass.can_afford(BiomassData.SCOUT_REROLL_COST)
	_scout_reroll_button.disabled = not can_reroll
	_scout_reroll_button.modulate = Color.WHITE if can_reroll else Color(1, 1, 1, 0.45)


func _on_scout_reroll_pressed() -> void:
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
