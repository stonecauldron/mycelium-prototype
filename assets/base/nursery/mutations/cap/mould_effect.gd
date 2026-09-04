class_name MouldCapEffect
extends MutationEffect

const _CHIP_ICON := preload("res://assets/base/composting_bin/composting_bin.png")


func get_stat_chip(roster: Resource) -> Dictionary:
	var data := roster as RosterUnitData
	if data == null or not is_mould(data):
		return {}
	return {
		"icon": _CHIP_ICON,
		"value": data.mould_compost_stacks,
	}


func on_ally_composted(roster: Resource, composted: Resource) -> void:
	var data := roster as RosterUnitData
	var other := composted as RosterUnitData
	if data == null or other == null or data == other:
		return
	if not is_mould(data):
		return
	data.mould_compost_stacks = maxi(data.mould_compost_stacks, 0) + 1
	_grant_stack_bonus(data)


static func _grant_stack_bonus(unit: RosterUnitData) -> void:
	if unit == null or unit.stats == null:
		return
	unit.stats.add_all(1)


static func is_mould(roster: RosterUnitData) -> bool:
	if roster == null:
		return false
	return roster.cap_mutation != null and roster.cap_mutation.effect is MouldCapEffect
