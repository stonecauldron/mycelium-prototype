class_name BankCapEffect
extends StrainEffect

const _BIOMASS_ICON := preload("res://assets/base/biomass.png")


func get_stat_chip(roster: Resource) -> Dictionary:
	var data := roster as RosterUnitData
	if data == null:
		return {}
	return {
		"icon": _BIOMASS_ICON,
		"value": data.biomass_bank,
	}


func on_combat_biomass_awarded(unit: Node, amount: int, _victim: Node) -> void:
	var u := unit as Unit
	if u == null or u.roster_data == null or amount <= 0:
		return
	u.roster_data.biomass_bank += int(round(float(amount) * 0.2))


func on_death(roster: Resource, context: DeathContext, _combat_unit: Node = null) -> void:
	if context != DeathContext.COMBAT and context != DeathContext.AGED_OUT:
		return
	var data := roster as RosterUnitData
	if data == null:
		return
	data.last_death_biomass_yield = 0
	var payout := int(round(float(data.biomass_bank) * 1.5))
	data.biomass_bank = 0
	if payout > 0:
		data.last_death_biomass_yield = payout
		GameState.biomass.add(payout)
