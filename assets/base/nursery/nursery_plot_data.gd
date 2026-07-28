class_name NurseryPlotData
extends Resource

enum State { EMPTY, GROWING, READY }

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


func _apply_fungicide(_fertilizer: FertilizerData) -> bool:
	# Any planted spore (just planted, growing, or READY). Empty plots rejected.
	if planted_spore == null:
		return false
	pending_stat_bonus += _fungicide_active_growth_bonus()
	planted_spore = null
	days_grown = 0
	applied_fertilizers.clear()
	return true


## +1 all-stats per active growth day. Just-planted (0 days) still grants 1.
## READY / overgrown plants are capped at days spent before becoming harvestable.
func _fungicide_active_growth_bonus() -> int:
	var active_cap := days_to_mature_effective()
	if get_state() == State.READY:
		return maxi(mini(days_grown, active_cap), 1)
	# GROWING: all days so far count; freshly planted still gets 1.
	return maxi(days_grown, 1)


func total_growth_bonus() -> int:
	var total := 0
	for fert in applied_fertilizers:
		if fert != null:
			total += fert.growth_bonus
	return total


func fertilizer_tooltip() -> String:
	var lines: PackedStringArray = []
	if pending_stat_bonus > 0:
		lines.append("Fungicide residue (+%d all)" % pending_stat_bonus)
	for fert in applied_fertilizers:
		if fert == null:
			continue
		lines.append("%s (%s)" % [fert.display_name, fert.subtitle_text()])
	return "\n".join(lines)


func clear() -> void:
	planted_spore = null
	days_grown = 0
	applied_fertilizers.clear()
	# pending_stat_bonus is consumed explicitly at harvest, not here.


func consume_pending_stat_bonus() -> int:
	var bonus := pending_stat_bonus
	pending_stat_bonus = 0
	return bonus
