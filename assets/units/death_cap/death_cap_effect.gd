class_name DeathCapEffect
extends StrainEffect


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
		roster_stats.strength = clampi(roster_stats.strength + 2, 1, 99)
		roster_stats.dex = clampi(roster_stats.dex + 2, 1, 99)
		roster_stats.con = clampi(roster_stats.con + 2, 1, 99)
		roster_stats.spd = clampi(roster_stats.spd + 2, 1, 99)
	if unit.stats != null:
		unit.stats.strength = clampi(unit.stats.strength + 2, 1, 99)
		unit.stats.dex = clampi(unit.stats.dex + 2, 1, 99)
		unit.stats.con = clampi(unit.stats.con + 2, 1, 99)
		unit.stats.spd = clampi(unit.stats.spd + 2, 1, 99)
