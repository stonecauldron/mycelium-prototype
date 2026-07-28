class_name ChadCapEffect
extends StrainEffect


func on_day(roster: Resource) -> void:
	var data := roster as RosterUnitData
	if data == null or data.stats == null:
		return
	var stats := data.stats
	stats.strength = maxi(stats.strength - 2, 1)
	stats.dex = maxi(stats.dex - 2, 1)
	stats.con = maxi(stats.con - 2, 1)
	stats.spd = maxi(stats.spd - 2, 1)
