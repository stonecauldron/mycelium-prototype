class_name RubberCapEffect
extends MutationEffect


func on_battle_start(unit: Node, _context: BattleStartContext = null) -> void:
	var u: Unit = unit as Unit
	if u == null:
		return
	u._blunt_resist = 0.5
	u._incoming_knockback_multiplier = 2.0
