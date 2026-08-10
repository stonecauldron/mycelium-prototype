class_name MutationData
extends Resource

enum Slot { BODY, CAP }

const BIOMASS_COST := BiomassData.MUTATION_COST

@export var display_name: String = "Mutation"
@export_multiline var short_description: String = ""
@export var slot: Slot = Slot.BODY
@export var biomass_cost: int = BiomassData.MUTATION_COST
@export var tint: Color = Color.WHITE
@export var effect: StrainEffect
@export var strength_delta: int = 0
@export var dex_delta: int = 0
@export var con_delta: int = 0
@export var spd_delta: int = 0


func is_body() -> bool:
	return slot == Slot.BODY


func is_cap() -> bool:
	return slot == Slot.CAP


func slot_label() -> String:
	return "Body" if is_body() else "Cap"


func subtitle_text() -> String:
	var authored := short_description.strip_edges()
	if not authored.is_empty():
		return authored
	return "no effect"


func apply_hatch_stats(stats: UnitStatsData) -> void:
	if stats == null:
		return
	stats.strength = clampi(stats.strength + strength_delta, 1, 99)
	stats.dex = clampi(stats.dex + dex_delta, 1, 99)
	stats.con = clampi(stats.con + con_delta, 1, 99)
	stats.spd = clampi(stats.spd + spd_delta, 1, 99)


func call_effect(method: StringName, args: Array = []) -> void:
	if effect == null or not effect.has_method(method):
		return
	effect.callv(method, args)


func get_stat_chip(roster: Resource) -> Dictionary:
	if effect == null:
		return {}
	return effect.get_stat_chip(roster)
