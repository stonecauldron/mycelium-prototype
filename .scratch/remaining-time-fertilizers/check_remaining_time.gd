extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://assets/base/plot_tile/plot_tile.gd")
	load("res://assets/base/spore_detail_card/spore_detail_card.gd")
	load("res://assets/base/nursery/nursery_data.gd")
	var errs: Array[String] = []
	var spore := load("res://assets/base/nursery/common_spore.tres") as SporeData
	var quick := load("res://assets/base/nursery/fertilizers/quick_growth.tres") as FertilizerData
	var slow := load("res://assets/base/nursery/fertilizers/slow_and_steady.tres") as FertilizerData
	var stress := load("res://assets/base/nursery/fertilizers/stress_induced_growth.tres") as FertilizerData
	var brute := load("res://assets/base/nursery/fertilizers/brute_force.tres") as FertilizerData
	var spreader := load("res://assets/base/seals/fertilizer_spreader.tres") as SealData
	var greenhouse := load("res://assets/base/seals/greenhouse.tres") as SealData
	if (
		spore == null or quick == null or slow == null or stress == null
		or brute == null or spreader == null or greenhouse == null
	):
		errs.append("failed to load resources")
		_finish(errs)
		return

	GameState.seals.reset()
	GameState.seals.add(spreader)

	var fresh := NurseryPlotData.new()
	fresh.planted_spore = spore.duplicate(true) as SporeData
	fresh.begin_planted_grow()
	_eq(errs, fresh.remaining_days(), 2, "fresh plant remaining")
	_eq(errs, fresh.get_state(), NurseryPlotData.State.GROWING, "fresh plant GROWING")

	var empty_quick := NurseryPlotData.new()
	if not empty_quick.apply_fertilizer(quick):
		errs.append("Quick Growth on empty dirt should apply")
	empty_quick.planted_spore = spore.duplicate(true) as SporeData
	empty_quick.begin_planted_grow()
	_eq(errs, empty_quick.remaining_days(), 1, "empty Quick Growth then plant")
	_eq(errs, empty_quick.get_state(), NurseryPlotData.State.GROWING, "empty Quick Growth still growing")

	var mid_quick := NurseryPlotData.new()
	mid_quick.planted_spore = spore.duplicate(true) as SporeData
	mid_quick.begin_planted_grow()
	mid_quick.tick_day()
	_eq(errs, mid_quick.remaining_days(), 1, "after 1 day remaining")
	if not mid_quick.apply_fertilizer(quick):
		errs.append("Quick Growth mid-grow should apply")
	_eq(errs, mid_quick.remaining_days(), 0, "Quick Growth spends last remaining day")
	_eq(errs, mid_quick.get_state(), NurseryPlotData.State.READY, "Quick Growth last day is READY")
	if mid_quick.can_apply_fertilizer():
		errs.append("READY plot should reject further Fertilizers")

	var plant_slow := NurseryPlotData.new()
	plant_slow.planted_spore = spore.duplicate(true) as SporeData
	plant_slow.begin_planted_grow()
	if not plant_slow.apply_fertilizer(slow):
		errs.append("Slow and Steady at plant should apply")
	_eq(errs, plant_slow.remaining_days(), 4, "Slow and Steady at plant doubles remaining")

	var late_slow := NurseryPlotData.new()
	late_slow.planted_spore = spore.duplicate(true) as SporeData
	late_slow.begin_planted_grow()
	late_slow.tick_day()
	if not late_slow.apply_fertilizer(slow):
		errs.append("Slow and Steady mid-grow should apply")
	_eq(errs, late_slow.remaining_days(), 2, "late Slow and Steady doubles remaining (not total)")

	var quick_then_slow := NurseryPlotData.new()
	if not quick_then_slow.apply_fertilizer(quick):
		errs.append("order: Quick Growth on empty")
	if not quick_then_slow.apply_fertilizer(slow):
		errs.append("order: Slow and Steady on empty")
	quick_then_slow.planted_spore = spore.duplicate(true) as SporeData
	quick_then_slow.begin_planted_grow()
	_eq(errs, quick_then_slow.remaining_days(), 2, "Quick then Slow at plant")

	var slow_then_quick := NurseryPlotData.new()
	if not slow_then_quick.apply_fertilizer(slow):
		errs.append("order: Slow and Steady on empty")
	if not slow_then_quick.apply_fertilizer(quick):
		errs.append("order: Quick Growth on empty")
	slow_then_quick.planted_spore = spore.duplicate(true) as SporeData
	slow_then_quick.begin_planted_grow()
	_eq(errs, slow_then_quick.remaining_days(), 3, "Slow then Quick at plant")

	var two_slow := NurseryPlotData.new()
	if not two_slow.apply_fertilizer(slow):
		errs.append("first Slow and Steady on empty")
	if not two_slow.apply_fertilizer(slow):
		errs.append("second Slow and Steady on empty")
	two_slow.planted_spore = spore.duplicate(true) as SporeData
	two_slow.begin_planted_grow()
	_eq(errs, two_slow.remaining_days(), 8, "two Slow and Steadies stack")

	var slow_then_stress := NurseryPlotData.new()
	slow_then_stress.planted_spore = spore.duplicate(true) as SporeData
	slow_then_stress.begin_planted_grow()
	if not slow_then_stress.apply_fertilizer(slow):
		errs.append("Slow and Steady before Stress Induced")
	if not slow_then_stress.apply_fertilizer(stress):
		errs.append("Stress Induced after Slow and Steady")
	_eq(errs, slow_then_stress.remaining_days(), 0, "Stress Induced zeros remaining")
	_eq(errs, slow_then_stress.get_state(), NurseryPlotData.State.READY, "Stress Induced READY no matter what")

	var double_quick := NurseryPlotData.new()
	if not double_quick.apply_fertilizer(quick):
		errs.append("first Quick Growth on empty")
	if not double_quick.apply_fertilizer(quick):
		errs.append("second Quick Growth on empty")
	double_quick.planted_spore = spore.duplicate(true) as SporeData
	double_quick.begin_planted_grow()
	_eq(errs, double_quick.remaining_days(), 0, "two Quick Growths waste leftover")
	_eq(errs, double_quick.get_state(), NurseryPlotData.State.READY, "two Quick Growths READY at plant")

	if brute != null and double_quick.get_state() == NurseryPlotData.State.READY:
		if double_quick.apply_fertilizer(brute):
			errs.append("stat Fertilizer should not apply on READY")

	GameState.seals.reset()
	GameState.nursery.reset()
	if not GameState.nursery.plant_spore(0, GameState.nursery.make_fresh_common_spore()):
		errs.append("GameState plant failed")
	var growing := GameState.nursery.plots[0] as NurseryPlotData
	_eq(errs, growing.remaining_days(), 2, "GameState fresh remaining")
	if not GameState.try_add_seal(greenhouse):
		errs.append("Greenhouse seal should add")
	_eq(errs, growing.remaining_days(), 1, "Greenhouse cuts remaining on in-progress grow")
	_eq(errs, growing.growth_time(), 1, "Greenhouse cuts Growth Time")

	GameState.seals.reset()
	GameState.nursery.reset()
	GameState.seals.add(spreader)
	if not GameState.nursery.plant_spore(0, GameState.nursery.make_fresh_common_spore()):
		errs.append("GameState plant for Slow+Greenhouse failed")
	var slow_plot := GameState.nursery.plots[0] as NurseryPlotData
	if not slow_plot.apply_fertilizer(slow):
		errs.append("Slow and Steady on GameState plot")
	_eq(errs, slow_plot.remaining_days(), 4, "Slow and Steady before Greenhouse")
	if not GameState.try_add_seal(greenhouse):
		errs.append("Greenhouse after Slow and Steady should add")
	_eq(errs, slow_plot.remaining_days(), 3, "Greenhouse is not multiplied by Slow and Steady")

	_finish(errs)


func _eq(errs: Array[String], got: Variant, expected: Variant, label: String) -> void:
	if got != expected:
		errs.append("%s: got %s expected %s" % [label, str(got), str(expected)])


func _finish(errs: Array[String]) -> void:
	if errs.is_empty():
		print("ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("ERRORS:")
		for e in errs:
			print(" - ", e)
		get_tree().quit(1)
