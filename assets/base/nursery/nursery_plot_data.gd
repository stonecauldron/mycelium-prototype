class_name NurseryPlotData
extends Resource

enum State { EMPTY, GROWING, READY }

@export var planted_spore: SporeData
@export var days_grown: int = 0
@export var applied_fertilizers: Array[FertilizerData] = []


func is_empty() -> bool:
	return planted_spore == null


func can_harvest() -> bool:
	return get_state() == State.READY


func can_apply_fertilizer() -> bool:
	var state := get_state()
	return state == State.EMPTY or state == State.GROWING


func will_harvest_as_imago() -> bool:
	if planted_spore == null:
		return false
	return planted_spore.grants_imago_at(days_grown)


func get_state() -> State:
	if planted_spore == null:
		return State.EMPTY
	if days_grown >= planted_spore.days_to_mature:
		return State.READY
	return State.GROWING


func has_fertilizers() -> bool:
	return not applied_fertilizers.is_empty()


func apply_fertilizer(fertilizer: FertilizerData) -> bool:
	if fertilizer == null or not can_apply_fertilizer():
		return false
	applied_fertilizers.append(fertilizer)
	if planted_spore != null and fertilizer.growth_bonus != 0:
		days_grown += fertilizer.growth_bonus
	return true


func total_growth_bonus() -> int:
	var total := 0
	for fert in applied_fertilizers:
		if fert != null:
			total += fert.growth_bonus
	return total


func fertilizer_tooltip() -> String:
	if applied_fertilizers.is_empty():
		return ""
	var lines: PackedStringArray = []
	for fert in applied_fertilizers:
		if fert == null:
			continue
		lines.append("%s (%s)" % [fert.display_name, fert.subtitle_text()])
	return "\n".join(lines)


func clear() -> void:
	planted_spore = null
	days_grown = 0
	applied_fertilizers.clear()
