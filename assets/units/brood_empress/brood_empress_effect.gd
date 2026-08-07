class_name BroodEmpressEffect
extends StrainEffect


func on_battle_start(unit: Node, _context: BattleStartContext = null) -> void:
	var u: Unit = unit as Unit
	if u == null or u.stats == null or u.roster_data == null:
		return
	var juveniles := _count_troop_juveniles(u.roster_data)
	if juveniles <= 0:
		return
	u.stats.strength = clampi(u.stats.strength + juveniles, 1, 99)
	u.stats.dex = clampi(u.stats.dex + juveniles, 1, 99)
	u.stats.con = clampi(u.stats.con + juveniles, 1, 99)
	u.stats.spd = clampi(u.stats.spd + juveniles, 1, 99)


func _count_troop_juveniles(self_roster: RosterUnitData) -> int:
	var troop := GameState.troop
	if troop == null:
		return 0
	var count := 0
	for entry in troop.squad:
		var data := entry as RosterUnitData
		if data == null or data == self_roster:
			continue
		if data.life_stage_id == UnitStrain.STAGE_JUVENILE:
			count += 1
	for entry in troop.bench:
		var data := entry as RosterUnitData
		if data == null or data == self_roster:
			continue
		if data.life_stage_id == UnitStrain.STAGE_JUVENILE:
			count += 1
	return count
