class_name StatusEffect
extends RefCounted

var id: StringName = &""
var remaining: float = 0.0
var move_mult: float = 1.0
var attack_rate_mult: float = 1.0


func _init(
	effect_id: StringName = &"",
	duration: float = 0.0,
	move_multiplier: float = 1.0,
	attack_rate_multiplier: float = 1.0
) -> void:
	id = effect_id
	remaining = duration
	move_mult = move_multiplier
	attack_rate_mult = attack_rate_multiplier
