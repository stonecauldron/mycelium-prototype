class_name NurseryPlotData
extends Resource

enum State { EMPTY, GROWING, READY }

const FUNGICIDE_NEXT_SPORE_BONUS := 4
## Remaining Time not yet snapshotted; remaining_days() uses Growth Time − days grown.
const REMAINING_UNSET := -1
## Plots hold Body and/or Cap mutations up to SealModifiers.max_mutation_slots().

@export var planted_spore: SporeData
@export var days_grown: int = 0
## Days left until READY. −1 = unset (empty or legacy plots that only set days_grown).
@export var remaining_time: int = REMAINING_UNSET
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
	return check_fertilizer_application().allowed


func check_fertilizer_application(fertilizer: FertilizerData = null) -> ActionDecision:
	var state := get_state()
	if fertilizer != null and fertilizer.behavior == FertilizerData.Behavior.FUNGICIDE:
		if state != State.GROWING and state != State.READY:
			return ActionDecision.reject(ActionReasons.PLOT_STATE_REJECTS_FERTILIZER)
		return ActionDecision.accept()
	if fertilizer != null and fertilizer.behavior == FertilizerData.Behavior.NORMIFIER:
		return check_normifier_application()
	if state != State.EMPTY and state != State.GROWING:
		return ActionDecision.reject(ActionReasons.PLOT_STATE_REJECTS_FERTILIZER)
	if fertilizer_stack_count() >= SealModifiers.max_fertilizer_stacks():
		return ActionDecision.reject(ActionReasons.FERTILIZER_CAPACITY_FULL)
	return ActionDecision.accept()


## Fertilizers that occupy Plot stack slots. Fungicide Extra nutrition does not.
func stack_fertilizers() -> Array[FertilizerData]:
	var stacked: Array[FertilizerData] = []
	for fert in applied_fertilizers:
		if fert != null and fert.behavior != FertilizerData.Behavior.FUNGICIDE:
			stacked.append(fert)
	return stacked


func fertilizer_stack_count() -> int:
	return stack_fertilizers().size()


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


## Mutations apply on empty or growing plots when both capacity and its typed slot are free.
func can_apply_mutation(mutation: MutationData = null) -> bool:
	return check_mutation_application(mutation).allowed


func check_mutation_application(mutation: MutationData = null) -> ActionDecision:
	var state := get_state()
	if state != State.EMPTY and state != State.GROWING:
		return ActionDecision.reject(ActionReasons.PLOT_STATE_REJECTS_MUTATION)
	var max_slots := SealModifiers.max_mutation_slots()
	if mutation == null:
		if mutation_count() >= max_slots:
			return ActionDecision.reject(ActionReasons.MUTATION_CAPACITY_FULL)
		return ActionDecision.accept()
	if mutation.is_body():
		if body_mutation != null or mutation_count() >= max_slots:
			return ActionDecision.reject(ActionReasons.MUTATION_CAPACITY_FULL)
		return ActionDecision.accept()
	if mutation.is_cap():
		if cap_mutation != null or mutation_count() >= max_slots:
			return ActionDecision.reject(ActionReasons.MUTATION_CAPACITY_FULL)
		return ActionDecision.accept()
	return ActionDecision.reject(ActionReasons.INVALID_MUTATION)


## Overgrowth removed: harvest always yields Child units.
func will_harvest_as_imago() -> bool:
	return false


## Authored wait after Greenhouse — not Plot Fertilizers (those adjust Remaining Time).
func growth_time() -> int:
	if planted_spore == null:
		return 0
	return planted_spore.days_to_mature_effective()


func days_to_mature_effective() -> int:
	return growth_time()


func remaining_days() -> int:
	if planted_spore == null:
		return 0
	if remaining_time >= 0:
		return remaining_time
	return maxi(growth_time() - days_grown, 0)


func get_state() -> State:
	if planted_spore == null:
		return State.EMPTY
	if remaining_days() <= 0:
		return State.READY
	return State.GROWING


func has_fertilizers() -> bool:
	return fertilizer_stack_count() > 0


func has_behavior(behavior: FertilizerData.Behavior) -> bool:
	for fert in applied_fertilizers:
		if fert != null and fert.behavior == behavior:
			return true
	return false


func apply_fertilizer(fertilizer: FertilizerData) -> bool:
	if fertilizer == null:
		return false
	if fertilizer.behavior == FertilizerData.Behavior.FUNGICIDE:
		return _apply_fungicide(fertilizer)
	if fertilizer.behavior == FertilizerData.Behavior.NORMIFIER:
		return _apply_normifier(fertilizer)
	if not can_apply_fertilizer():
		return false
	_discard_fungicide_markers()
	applied_fertilizers.append(fertilizer)
	if planted_spore != null:
		_apply_duration_to_remaining(fertilizer)
	return true


## Assigns mutation to a free Body/Cap slot without replacing an applied mutation.
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
	return check_normifier_application().allowed


func check_normifier_application() -> ActionDecision:
	var state := get_state()
	if state != State.GROWING and state != State.READY:
		return ActionDecision.reject(ActionReasons.PLOT_STATE_REJECTS_FERTILIZER)
	if planted_spore == null or not has_any_mutation():
		return ActionDecision.reject(ActionReasons.NORMIFIER_REQUIRES_MUTATION)
	if fertilizer_stack_count() >= SealModifiers.max_fertilizer_stacks():
		return ActionDecision.reject(ActionReasons.FERTILIZER_CAPACITY_FULL)
	return ActionDecision.accept()


func _apply_normifier(fertilizer: FertilizerData) -> bool:
	if not can_apply_normifier():
		return false
	body_mutation = null
	cap_mutation = null
	planted_spore.body_mutation = null
	planted_spore.cap_mutation = null
	_discard_fungicide_markers()
	applied_fertilizers.append(fertilizer)
	return true


func _apply_fungicide(fertilizer: FertilizerData) -> bool:
	if not check_fertilizer_application(fertilizer).allowed:
		return false
	pending_stat_bonus += FUNGICIDE_NEXT_SPORE_BONUS
	planted_spore = null
	days_grown = 0
	remaining_time = REMAINING_UNSET
	body_mutation = null
	cap_mutation = null
	# Drop fertilizers that died with the plant. Extra nutrition is pending_stat_bonus only.
	applied_fertilizers.clear()
	return true


func _discard_fungicide_markers() -> void:
	var stacked := stack_fertilizers()
	if stacked.size() == applied_fertilizers.size():
		return
	applied_fertilizers.clear()
	applied_fertilizers.append_array(stacked)


## Snapshot Remaining Time from Growth Time, then replay stacked duration Fertilizers in order.
func begin_planted_grow() -> void:
	days_grown = 0
	remaining_time = growth_time()
	for fert in applied_fertilizers:
		_apply_duration_to_remaining(fert)


func tick_day() -> void:
	if planted_spore == null:
		return
	if remaining_time < 0:
		remaining_time = remaining_days()
	if remaining_time > 0:
		remaining_time -= 1
	days_grown += 1


func apply_greenhouse_remaining_cut(days: int) -> void:
	if planted_spore == null or days <= 0:
		return
	if remaining_days() <= 0:
		return
	remaining_time = maxi(remaining_days() - days, 0)


func _apply_duration_to_remaining(fertilizer: FertilizerData) -> void:
	if planted_spore == null or fertilizer == null:
		return
	if fertilizer.force_ready:
		remaining_time = 0
		return
	if fertilizer.behavior == FertilizerData.Behavior.SLOW_STEADY:
		remaining_time = remaining_days() * 2
		return
	if fertilizer.growth_bonus != 0:
		remaining_time = maxi(remaining_days() - fertilizer.growth_bonus, 0)


func fertilizer_tooltip() -> String:
	var lines: PackedStringArray = []
	if planted_spore != null:
		lines.append(planted_spore.display_name)
	lines.append_array(mutation_tooltip_lines())
	var residue := fungicide_residue_text()
	if not residue.is_empty():
		lines.append(residue)
	for fert in stack_fertilizers():
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
	remaining_time = REMAINING_UNSET
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
