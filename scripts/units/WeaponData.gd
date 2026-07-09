class_name WeaponData
extends Resource

enum WeaponRange { MELEE, MID, RANGED }

const SQUAD_OFFSET := {
	WeaponRange.MELEE: 80.0,
	WeaponRange.MID: 0.0,
	WeaponRange.RANGED: -60.0,
}

@export var display_name: String = ""
@export var range_class: WeaponRange = WeaponRange.MELEE
@export var base_damage: int = 5
@export var attack_range: float = 48.0
@export var knockback_force: float = 280.0


func get_squad_offset(squad_index: int) -> float:
	var base: float = SQUAD_OFFSET.get(range_class, 0.0)
	if base == 0.0:
		return 0.0
	return base * float(squad_index + 1)
