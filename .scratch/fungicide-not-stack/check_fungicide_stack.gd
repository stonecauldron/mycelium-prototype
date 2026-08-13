extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	# Compile UI scripts that consume stack_fertilizers / extra nutrition.
	load("res://assets/base/plot_tile/plot_tile.gd")
	load("res://assets/base/unit_detail_card/unit_detail_card_content.gd")
	load("res://assets/base/spore_detail_card/spore_detail_card.gd")
	load("res://assets/base/nursery/nursery_data.gd")
	var errs: Array[String] = []
	var spore := load("res://assets/base/nursery/common_spore.tres") as SporeData
	var brute := load("res://assets/base/nursery/fertilizers/brute_force.tres") as FertilizerData
	var fungicide := load("res://assets/base/nursery/fertilizers/fungicide.tres") as FertilizerData
	if spore == null or brute == null or fungicide == null:
		errs.append("failed to load resources")
		_finish(errs)
		return

	var plot := NurseryPlotData.new()
	plot.planted_spore = spore
	plot.days_grown = 0
	if plot.get_state() != NurseryPlotData.State.GROWING:
		errs.append("expected GROWING after plant")

	if not plot.apply_fertilizer(brute):
		errs.append("first fertilizer should apply")
	if plot.can_apply_fertilizer():
		errs.append("stack should be full after one fertilizer")
	if not plot.apply_fertilizer(fungicide):
		errs.append("fungicide should apply on a full stack")
	if plot.get_state() != NurseryPlotData.State.EMPTY:
		errs.append("fungicide should kill the grow")
	if plot.pending_stat_bonus != NurseryPlotData.FUNGICIDE_NEXT_SPORE_BONUS:
		errs.append(
			"expected +%d extra nutrition, got %d"
			% [NurseryPlotData.FUNGICIDE_NEXT_SPORE_BONUS, plot.pending_stat_bonus]
		)
	if plot.fertilizer_stack_count() != 0:
		errs.append("fungicide should not occupy the stack")
	if not plot.applied_fertilizers.is_empty():
		errs.append("killed grow fertilizers should be dropped")
	if not plot.can_apply_fertilizer():
		errs.append("empty plot after fungicide should accept fertilizer")
	if not plot.apply_fertilizer(brute):
		errs.append("fertilizer on empty dirt after fungicide should apply")
	if plot.fertilizer_stack_count() != 1:
		errs.append("stack should be 1 after post-kill fertilizer")
	if plot.pending_stat_bonus != NurseryPlotData.FUNGICIDE_NEXT_SPORE_BONUS:
		errs.append("extra nutrition should survive dirt fertilizer")

	var plot2 := NurseryPlotData.new()
	plot2.planted_spore = spore
	if not plot2.apply_fertilizer(fungicide):
		errs.append("first sequential fungicide failed")
	plot2.planted_spore = spore
	if not plot2.apply_fertilizer(fungicide):
		errs.append("second sequential fungicide failed")
	var stacked_bonus := NurseryPlotData.FUNGICIDE_NEXT_SPORE_BONUS * 2
	if plot2.pending_stat_bonus != stacked_bonus:
		errs.append("sequential kills should stack +4, got %d" % plot2.pending_stat_bonus)
	if not plot2.can_apply_fertilizer():
		errs.append("sequential fungicide should leave stack free")

	var plot3 := NurseryPlotData.new()
	plot3.planted_spore = spore
	plot3.applied_fertilizers.append(fungicide)
	if not plot3.can_apply_fertilizer():
		errs.append("legacy fungicide marker should not fill the stack")
	if not plot3.apply_fertilizer(brute):
		errs.append("legacy marker should be discarded on apply")
	if plot3.fertilizer_stack_count() != 1:
		errs.append("legacy marker leftover after apply")
	for fert in plot3.applied_fertilizers:
		if fert != null and fert.behavior == FertilizerData.Behavior.FUNGICIDE:
			errs.append("applied_fertilizers still holds a fungicide marker")

	_finish(errs)


func _finish(errs: Array[String]) -> void:
	if errs.is_empty():
		print("ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("ERRORS:")
		for e in errs:
			print(" - ", e)
		get_tree().quit(1)
