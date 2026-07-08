class_name WeaponData
extends Resource

enum WeaponRange { MELEE, MID, RANGED }

const SQUAD_OFFSET := {
	WeaponRange.MELEE: 80.0,
	WeaponRange.MID: 40.0,
	WeaponRange.RANGED: -60.0,
}

@export var display_name: String = ""
@export var range_class: WeaponRange = WeaponRange.MELEE
@export var base_damage: int = 5
@export var attack_range: float = 48.0


func get_squad_offset() -> float:
	return SQUAD_OFFSET.get(range_class, 0.0)
