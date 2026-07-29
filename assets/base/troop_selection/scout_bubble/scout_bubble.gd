class_name ScoutBubble
extends Control

const _SCOUT_ENTRY_SCENE := preload(
	"res://assets/base/troop_selection/scout_bubble/scout_weapon_entry.tscn"
)
const _SCOUT_STRAIN_ENTRY_SCENE := preload(
	"res://assets/base/troop_selection/scout_bubble/scout_strain_entry.tscn"
)

@onready var _scout_row: HBoxContainer = %ScoutRow
@onready var _scout_strain_row: HBoxContainer = %ScoutStrainRow
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
	if _scout_strain_row != null:
		for child in _scout_strain_row.get_children():
			child.queue_free()
	GameState.ensure_upcoming_enemy_formation()
	var specs := GameState.upcoming_enemy_formation
	var weapon_counts: Dictionary = {}
	var strain_counts: Dictionary = {}
	for spec in specs:
		if spec.weapon != null:
			var weapon_key := spec.weapon.resource_path
			if weapon_key.is_empty():
				weapon_key = str(spec.weapon.get_instance_id())
			if not weapon_counts.has(weapon_key):
				weapon_counts[weapon_key] = {"count": 0, "weapon": spec.weapon}
			weapon_counts[weapon_key]["count"] = int(weapon_counts[weapon_key]["count"]) + 1
		if spec.strain != null:
			var key := spec.strain.resource_path
			if key.is_empty():
				key = spec.strain.display_name
			if not strain_counts.has(key):
				strain_counts[key] = {"count": 0, "strain": spec.strain}
			strain_counts[key]["count"] = int(strain_counts[key]["count"]) + 1
	var reward := 0
	for spec in specs:
		reward += BiomassData.reward_for_kill(spec.is_imago)
	for weapon_key in weapon_counts.keys():
		var entry: Dictionary = weapon_counts[weapon_key]
		var count: int = entry["count"]
		if count <= 0:
			continue
		var weapon: WeaponData = entry["weapon"]
		var entry_card: ScoutWeaponEntry = _SCOUT_ENTRY_SCENE.instantiate()
		_scout_row.add_child(entry_card)
		entry_card.setup(count, weapon)
	if _scout_strain_row != null:
		for key in strain_counts.keys():
			var strain_entry: Dictionary = strain_counts[key]
			var strain_count: int = strain_entry["count"]
			if strain_count <= 0:
				continue
			var strain: UnitStrain = strain_entry["strain"]
			var strain_card: ScoutStrainEntry = _SCOUT_STRAIN_ENTRY_SCENE.instantiate()
			_scout_strain_row.add_child(strain_card)
			strain_card.setup(strain_count, strain)
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
