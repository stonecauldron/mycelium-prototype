class_name EnemyUnitData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var short_description: String = ""
@export var icon: Texture2D
@export var appearance_scene: PackedScene
@export var combat: CombatProfile
## Visual-only held weapon art for mount / scout portraits (combat uses `combat`).
@export var held_weapon: WeaponData
## First day this type can appear in procedural armies (1-based).
@export_range(1, 99, 1) var min_day: int = 1
## Relative weight when picking types for army mix.
@export_range(0.0, 100.0, 0.1) var composition_weight: float = 1.0
## Optional combat hooks (on_death, on_hit_taken, …). Null for plain enemies.
@export var effect: StrainEffect


func instantiate_appearance() -> UnitAppearance:
	if appearance_scene == null:
		return null
	return appearance_scene.instantiate() as UnitAppearance


func get_combat_profile() -> CombatProfile:
	if combat != null:
		return combat
	return CombatProfile.new()


func call_effect(method_name: StringName, args: Array = []) -> void:
	if effect == null or not effect.has_method(method_name):
		return
	effect.callv(method_name, args)
