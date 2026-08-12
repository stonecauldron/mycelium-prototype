class_name NurseryPlotData
extends Resource

enum State { EMPTY, GROWING, READY }

const FUNGICIDE_NEXT_SPORE_BONUS := 2
## Plots hold Body and/or Cap mutations up to SealModifiers.max_mutation_slots().

@export var planted_spore: SporeData
@export var days_grown: int = 0
@export var applied_fertilizers: Array[FertilizerData] = []
## Body mutation awaiting harvest (empty allowed).
@export var body_mutation: MutationData
## Cap mutation awaiting harvest (empty allowed).
@export var cap_mutation: MutationData
## Flat +all-stats carried from Fungicide kills; consumed on next harvest.
@export var pending_stat_bonus: int = 0


func is_empty() -> bool:
	return planted_spore == null


func can_harvest() -> bool:
	return get_state() == State.READY


func can_apply_fertilizer() -> bool:
	var state := get_state()
	if state != State.EMPTY and state != State.GROWING:
		return false
	return applied_fertilizers.size() < SealModifiers.max_fertilizer_stacks()


func mutation_count() -> int:
	var count := 0
	if body_mutation != null:
		count += 1
	if cap_mutation != null:
		count += 1
	return count


## The single filled mutation when capacity is 1, or null when empty.
func filled_mutation() -> MutationData:
	if body_mutation != null:
		return body_mutation
	return cap_mutation


## Mutations apply on empty or planted plots. At capacity, only same-slot replace is allowed.
func can_apply_mutation(mutation: MutationData = null) -> bool:
	var max_slots := SealModifiers.max_mutation_slots()
	if mutation == null:
		return mutation_count() < max_slots
	if mutation.is_body():
		if body_mutation != null:
			return true
		return mutation_count() < max_slots
	if mutation.is_cap():
		if cap_mutation != null:
			return true
		return mutation_count() < max_slots
	return false


## Overgrowth removed: harvest always yields Child units.
func will_harvest_as_imago() -> bool:
	return false


func days_to_mature_effective() -> int:
	if planted_spore == null:
		return 1
	var base_days := planted_spore.days_to_mature_effective()
	if has_behavior(FertilizerData.Behavior.SLOW_STEADY):
		base_days *= 2
	if has_behavior(FertilizerData.Behavior.SLOW_METABOLISM):
		base_days *= 2
	if has_behavior(FertilizerData.Behavior.FAST_METABOLISM):
		base_days = int(base_days / 2.0)
	return maxi(base_days, 0)


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


func has_force_ready() -> bool:
	for fert in applied_fertilizers:
		if fert != null and fert.force_ready:
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
	if fertilizer.behavior == FertilizerData.Behavior.NORMIFIER:
		return _apply_normifier(fertilizer)
	if not can_apply_fertilizer():
		return false
	applied_fertilizers.append(fertilizer)
	if planted_spore != null and fertilizer.growth_bonus != 0:
		days_grown += fertilizer.growth_bonus
	_snap_force_ready_if_needed()
	return true


## Assigns mutation to its Body/Cap slot. Same-kind replace consumes the previous.
func apply_mutation(mutation: MutationData) -> bool:
	if mutation == null or not can_apply_mutation(mutation):
		return false
	if mutation.is_body():
		body_mutation = mutation
		return true
	if mutation.is_cap():
		cap_mutation = mutation
		return true
	return false


func has_any_mutation() -> bool:
	if body_mutation != null or cap_mutation != null:
		return true
	if planted_spore == null:
		return false
	return planted_spore.body_mutation != null or planted_spore.cap_mutation != null


func can_apply_normifier() -> bool:
	var state := get_state()
	if state != State.GROWING and state != State.READY:
		return false
	if planted_spore == null or not has_any_mutation():
		return false
	return applied_fertilizers.size() < SealModifiers.max_fertilizer_stacks()


func _apply_normifier(fertilizer: FertilizerData) -> bool:
	if not can_apply_normifier():
		return false
	body_mutation = null
	cap_mutation = null
	planted_spore.body_mutation = null
	planted_spore.cap_mutation = null
	applied_fertilizers.append(fertilizer)
	return true


func _apply_fungicide(fertilizer: FertilizerData) -> bool:
	# Growing or READY spores. Empty plots rejected.
	var state := get_state()
	if state != State.GROWING and state != State.READY:
		return false
	pending_stat_bonus += FUNGICIDE_NEXT_SPORE_BONUS
	planted_spore = null
	days_grown = 0
	body_mutation = null
	cap_mutation = null
	# Drop fertilizers that died with the plant; keep prior Fungicide markers for chips.
	var kept: Array[FertilizerData] = []
	for fert in applied_fertilizers:
		if fert != null and fert.behavior == FertilizerData.Behavior.FUNGICIDE:
			kept.append(fert)
	# Cap still applies: fungicide markers + new fungicide must fit max stacks.
	var max_stacks := SealModifiers.max_fertilizer_stacks()
	while kept.size() >= max_stacks and not kept.is_empty():
		kept.pop_front()
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


func snap_after_plant() -> void:
	_snap_force_ready_if_needed()


func _snap_force_ready_if_needed() -> void:
	if planted_spore == null or not has_force_ready():
		return
	days_grown = maxi(days_grown, days_to_mature_effective())


func fertilizer_tooltip() -> String:
	var lines: PackedStringArray = []
	if planted_spore != null:
		lines.append(planted_spore.display_name)
	lines.append_array(mutation_tooltip_lines())
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


func mutation_tooltip_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	if body_mutation != null:
		lines.append(body_mutation.effect_line())
	if cap_mutation != null:
		lines.append(cap_mutation.effect_line())
	return lines


func clear() -> void:
	planted_spore = null
	days_grown = 0
	applied_fertilizers.clear()
	body_mutation = null
	cap_mutation = null
	# pending_stat_bonus is consumed explicitly at harvest, not here.


func fungicide_residue_text() -> String:
	if pending_stat_bonus <= 0:
		return ""
	return "Extra nutrition. +%d all stats" % pending_stat_bonus


func consume_pending_stat_bonus() -> int:
	var bonus := pending_stat_bonus
	pending_stat_bonus = 0
	return bonus
