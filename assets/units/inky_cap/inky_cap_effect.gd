class_name InkyCapEffect
extends StrainEffect

const SLOW_ID := &"inky_slow"
const SLOW_DURATION := 10.0
const SLOW_MULT := 0.5


func on_battle_start(unit: Node) -> void:
	var u: Unit = unit as Unit
	if u == null:
		return
	u._outgoing_damage_multiplier = 0.5


func on_hit_dealt(_attacker: Node, target: Node, _damage: int) -> void:
	var victim: Unit = target as Unit
	if victim == null:
		return
	victim.apply_status(StatusEffect.new(SLOW_ID, SLOW_DURATION, SLOW_MULT, SLOW_MULT), true)
