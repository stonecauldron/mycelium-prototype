class_name BankCapEffect
extends StrainEffect

const _BIOMASS_ICON := preload("res://assets/base/biomass.png")
const _BATTLE_START_DEPOSIT := 10


func get_stat_chip(roster: Resource) -> Dictionary:
	var data := roster as RosterUnitData
	if data == null:
		return {}
	return {
		"icon": _BIOMASS_ICON,
		"value": data.biomass_bank,
	}


func on_battle_start(unit: Node, _context: BattleStartContext = null) -> void:
	var u: Unit = unit as Unit
	if u == null or u.roster_data == null:
		return
	u.roster_data.biomass_bank += _BATTLE_START_DEPOSIT


func on_death(roster: Resource, context: DeathContext, _combat_unit: Node = null) -> void:
	if context != DeathContext.COMBAT and context != DeathContext.AGED_OUT:
		return
	var data := roster as RosterUnitData
	if data == null:
		return
	data.last_death_biomass_yield = 0
	var payout := data.biomass_bank
	data.biomass_bank = 0
	if payout > 0:
		data.last_death_biomass_yield = payout
		GameState.biomass.add(payout)
