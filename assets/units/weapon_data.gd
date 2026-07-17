class_name WeaponData
extends Resource

enum WeaponRange { MELEE, MID, RANGED }
enum TargetingMode { SINGLE, AOE }

const SQUAD_OFFSET := {
	WeaponRange.MELEE: 48.0,
	WeaponRange.MID: 52.0,
	WeaponRange.RANGED: -60.0,
}

@export var display_name: String = ""
@export var range_class: WeaponRange = WeaponRange.MELEE
@export var targeting_mode: TargetingMode = TargetingMode.SINGLE
@export var base_damage: int = 5
@export var attack_range: float = 48.0
@export var knockback_force: float = 280.0
@export var biomass_cost: int = 5
@export var appearance_scene: PackedScene


func instantiate_appearance() -> Node2D:
	if appearance_scene == null:
		return null
	return appearance_scene.instantiate() as Node2D


func get_squad_offset(squad_index: int) -> float:
	var base: float = SQUAD_OFFSET.get(range_class, 0.0)
	if range_class == WeaponRange.MID:
		return base * (float(squad_index) - 1.5)
	if range_class == WeaponRange.MELEE:
		# Start just past the forwardmost mid home (4 mids centered: ±1.5 steps).
		var mid_forward_extent: float = SQUAD_OFFSET[WeaponRange.MID] * 1.5
		return mid_forward_extent + base * float(squad_index + 1)
	if base == 0.0:
		return 0.0
	return base * float(squad_index + 1)
