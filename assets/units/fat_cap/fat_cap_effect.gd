class_name FatCapEffect
extends StrainEffect


func on_battle_start(unit: Node) -> void:
	var u := unit as Unit
	if u == null:
		return
	u._incoming_knockback_multiplier = 0.5
