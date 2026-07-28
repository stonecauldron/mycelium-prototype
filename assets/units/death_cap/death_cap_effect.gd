class_name DeathCapEffect
extends StrainEffect


func on_kill(killer: Node, _victim: Node) -> void:
	var unit := killer as Unit
	if unit == null or unit.roster_data == null:
		return
	var stats := unit.roster_data.stats
	if stats == null:
		return
	stats.strength = clampi(stats.strength + 1, 1, 99)
	stats.dex = clampi(stats.dex + 1, 1, 99)
	stats.con = clampi(stats.con + 1, 1, 99)
	stats.spd = clampi(stats.spd + 1, 1, 99)
	# Keep the living combat unit in sync with the permanent roster buff.
	if unit.stats != null:
		unit.stats.strength = clampi(unit.stats.strength + 1, 1, 99)
		unit.stats.dex = clampi(unit.stats.dex + 1, 1, 99)
		unit.stats.con = clampi(unit.stats.con + 1, 1, 99)
		unit.stats.spd = clampi(unit.stats.spd + 1, 1, 99)
