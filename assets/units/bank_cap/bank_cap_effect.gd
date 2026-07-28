class_name BankCapEffect
extends StrainEffect


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
	var payout := int(round(float(data.biomass_bank) * 1.5))
	data.biomass_bank = 0
	if payout > 0:
		GameState.biomass.add(payout)
