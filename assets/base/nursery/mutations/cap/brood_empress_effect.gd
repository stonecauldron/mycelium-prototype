class_name BroodEmpressEffect
extends MutationEffect

const _CHILD_CHIP_ICON := preload("res://assets/base/nursery/mutations/cap/magicap.png")


func on_battle_start(unit: Node, _context: BattleStartContext = null) -> void:
	var u: Unit = unit as Unit
	if u == null or u.stats == null or u.roster_data == null:
		return
	var juveniles := count_troop_juveniles(u.roster_data)
	if juveniles <= 0:
		return
	u.stats.add_all(juveniles)


func get_stat_chip(roster: Resource) -> Dictionary:
	var data := roster as RosterUnitData
	if data == null:
		return {}
	return {
		"icon": _CHILD_CHIP_ICON,
		"value": count_troop_juveniles(data),
	}


## Living Child units on squad + bench (excludes self). Cocooned units are out of troop.
static func count_troop_juveniles(self_roster: RosterUnitData) -> int:
	var troop := GameState.troop
	if troop == null:
		return 0
	var count := 0
	for entry in troop.squad:
		var data := entry as RosterUnitData
		if data == null or data == self_roster:
			continue
		if data.life_stage_id == RosterUnitData.STAGE_JUVENILE:
			count += 1
	for entry in troop.bench:
		var data := entry as RosterUnitData
		if data == null or data == self_roster:
			continue
		if data.life_stage_id == RosterUnitData.STAGE_JUVENILE:
			count += 1
	return count


static func is_brood_empress(roster: RosterUnitData) -> bool:
	if roster == null:
		return false
	return roster.cap_mutation != null and roster.cap_mutation.effect is BroodEmpressEffect


## Hub preview stats with child bonus applied (does not mutate roster permanently).
static func hub_preview_stats(roster: RosterUnitData) -> UnitStatsData:
	if roster == null or roster.stats == null:
		return null
	var bonus := count_troop_juveniles(roster) if is_brood_empress(roster) else 0
	if bonus <= 0:
		return roster.stats
	var preview := roster.stats.duplicate(true) as UnitStatsData
	preview.add_all(bonus)
	return preview


static func hub_effective_attack(roster: RosterUnitData) -> int:
	if roster == null:
		return 0
	var preview := hub_preview_stats(roster)
	if preview == null or preview == roster.stats:
		return SealModifiers.effective_attack_damage(roster)
	var saved := roster.stats
	roster.stats = preview
	var result := SealModifiers.effective_attack_damage(roster)
	roster.stats = saved
	return result


static func hub_effective_max_hp(roster: RosterUnitData) -> int:
	if roster == null:
		return 0
	var preview := hub_preview_stats(roster)
	if preview == null or preview == roster.stats:
		return SealModifiers.effective_max_hp(roster)
	var saved := roster.stats
	roster.stats = preview
	var result := SealModifiers.effective_max_hp(roster)
	roster.stats = saved
	return result
