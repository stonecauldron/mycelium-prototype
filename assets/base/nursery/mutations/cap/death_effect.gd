class_name DeathCapEffect
extends MutationEffect


func on_battle_start(unit: Node, context: BattleStartContext = null) -> void:
	var u: Unit = unit as Unit
	if u == null or context == null:
		return
	var adjacent := context.adjacent_squad_allies(u)
	for ally in adjacent:
		context.queue_kill(ally, u)
		_grant_sacrifice_bonus(u)


func _grant_sacrifice_bonus(unit: Unit) -> void:
	if unit == null or unit.roster_data == null:
		return
	var roster_stats := unit.roster_data.stats
	if roster_stats != null:
		roster_stats.add_all(2)
	if unit.stats != null:
		unit.stats.add_all(2)
