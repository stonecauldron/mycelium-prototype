class_name NurseryPlotData
extends Resource

enum State { EMPTY, GROWING, READY }

@export var planted_spore: SporeData
@export var days_grown: int = 0


func is_empty() -> bool:
	return planted_spore == null


func can_harvest() -> bool:
	return get_state() == State.READY


func get_state() -> State:
	if planted_spore == null:
		return State.EMPTY
	if days_grown >= planted_spore.days_to_mature:
		return State.READY
	return State.GROWING


func clear() -> void:
	planted_spore = null
	days_grown = 0
