class_name NurseryPlotData
extends Resource

enum State { EMPTY, GROWING, READY }

const FUNGICIDE_NEXT_SPORE_BONUS := 2

@export var planted_spore: SporeData
@export var days_grown: int = 0
@export var applied_fertilizers: Array[FertilizerData] = []
## Flat +all-stats carried from Fungicide kills; consumed on next harvest.
@export var pending_stat_bonus: int = 0


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
	return planted_spore.grants_imago_at(days_grown, days_to_mature_effective())


func days_to_mature_effective() -> int:
	if planted_spore == null:
		return 1
	var base_days := maxi(planted_spore.days_to_mature, 0)
	if has_behavior(FertilizerData.Behavior.SLOW_STEADY):
		return maxi(base_days * 2, 0)
	return base_days


func get_state() -> State:
	if planted_spore == null:
		return State.EMPTY
	if days_grown >= days_to_mature_effective():
		return State.READY
	return State.GROWING


func has_fertilizers() -> bool:
	return not applied_fertilizers.is_empty()


func has_behavior(behavior: FertilizerData.Behavior) -> bool:
	for fert in applied_fertilizers:
		if fert != null and fert.behavior == behavior:
			return true
	return false


func behavior_count(behavior: FertilizerData.Behavior) -> int:
	var count := 0
	for fert in applied_fertilizers:
		if fert != null and fert.behavior == behavior:
			count += 1
	return count


func apply_fertilizer(fertilizer: FertilizerData) -> bool:
	if fertilizer == null:
		return false
	if fertilizer.behavior == FertilizerData.Behavior.FUNGICIDE:
		return _apply_fungicide(fertilizer)
	if not can_apply_fertilizer():
		return false
	applied_fertilizers.append(fertilizer)
	if planted_spore != null and fertilizer.growth_bonus != 0:
		days_grown += fertilizer.growth_bonus
	return true


func _apply_fungicide(fertilizer: FertilizerData) -> bool:
	# Growing or READY spores. Empty plots rejected.
	var state := get_state()
	if state != State.GROWING and state != State.READY:
		return false
	pending_stat_bonus += FUNGICIDE_NEXT_SPORE_BONUS
	planted_spore = null
	days_grown = 0
	# Drop fertilizers that died with the plant; keep prior Fungicide markers for chips.
	var kept: Array[FertilizerData] = []
	for fert in applied_fertilizers:
		if fert != null and fert.behavior == FertilizerData.Behavior.FUNGICIDE:
			kept.append(fert)
	applied_fertilizers.clear()
	applied_fertilizers.append_array(kept)
	applied_fertilizers.append(fertilizer)
	return true


func total_growth_bonus() -> int:
	var total := 0
	for fert in applied_fertilizers:
		if fert != null:
			total += fert.growth_bonus
	return total


func fertilizer_tooltip() -> String:
	var lines: PackedStringArray = []
	if planted_spore != null:
		var strain := planted_spore.resolved_strain()
		if strain != null:
			var strain_line := strain.display_name
			var desc := strain.short_description.strip_edges()
			if not desc.is_empty():
				strain_line = "%s — %s" % [strain.display_name, desc]
			lines.append(strain_line)
	var residue := fungicide_residue_text()
	if not residue.is_empty():
		lines.append(residue)
	for fert in applied_fertilizers:
		if fert == null:
			continue
		# Fungicide markers are summarized by the residue line above.
		if fert.behavior == FertilizerData.Behavior.FUNGICIDE:
			continue
		lines.append("%s (%s)" % [fert.display_name, fert.subtitle_text()])
	return "\n".join(lines)


func clear() -> void:
	planted_spore = null
	days_grown = 0
	applied_fertilizers.clear()
	# pending_stat_bonus is consumed explicitly at harvest, not here.


func fungicide_residue_text() -> String:
	if pending_stat_bonus <= 0:
		return ""
	return "Extra nutrition. +%d all stats" % pending_stat_bonus


func consume_pending_stat_bonus() -> int:
	var bonus := pending_stat_bonus
	pending_stat_bonus = 0
	return bonus
