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
	_consume_first_plant_bonus(errs)
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
	_consume_first_plant_bonus(errs)
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

	await _check_quick_growth_ui_refresh(errs)
	await _check_greenhouse_ui_refresh(errs)
	_finish(errs)


func _check_quick_growth_ui_refresh(errs: Array[String]) -> void:
	GameState.reset_run()
	_consume_first_plant_bonus(errs)
	GameState.activate_debug_cheats()
	var nursery := GameState.nursery
	nursery.unlocked_plot_count = NurseryData.MAX_PLOT_COUNT
	var quick := load("res://assets/base/nursery/fertilizers/quick_growth.tres") as FertilizerData
	var slow := load("res://assets/base/nursery/fertilizers/slow_and_steady.tres") as FertilizerData
	for i in 2:
		_eq(errs, nursery.plant_spore(i, nursery.make_fresh_common_spore()), true, "UI: plant %d" % i)
	_eq(errs, nursery.apply_fertilizer_to_plot(1, slow), true, "UI: apply Slow and Steady")
	_eq(errs, nursery.apply_fertilizer_to_plot(2, quick), true, "UI: prepare Quick Growth")
	_eq(errs, nursery.plant_spore(2, nursery.make_fresh_common_spore()), true, "UI: plant prepared plot")
	var screen := preload("res://assets/base/nursery/nursery_screen.tscn").instantiate() as NurseryScreen
	add_child(screen)
	_eq(errs, screen._tiles[0]._plot_visual.texture, PlotTile._TEX_GROWTH0, "fresh grow starts small")
	_eq(errs, screen._tiles[2]._plot_visual.texture, PlotTile._TEX_GROWTH1, "prepared Quick Growth starts larger")
	_eq(errs, nursery.add_fertilizer(quick), true, "UI: stock Quick Growth")
	screen._on_plot_item_dropped(screen._tiles[0], {
		"type": "fertilizer", "stock_index": nursery.stock.slots.find(quick), "fertilizer": quick,
	})
	_eq(errs, screen._tiles[0]._days_chip._value_label.text, "1", "Quick Growth immediately updates countdown")
	_eq(errs, screen._tiles[0]._plot_visual.texture, PlotTile._TEX_GROWTH1, "Quick Growth immediately enlarges grow")
	_eq(errs, nursery.plots[0].days_grown, 0, "Quick Growth does not advance elapsed days")
	_eq(errs, nursery.plots[0].growth_time(), 2, "Quick Growth does not change Growth Time")
	_eq(errs, screen._tiles[1]._plot_visual.texture, PlotTile._TEX_GROWTH0, "Slow and Steady starts small")
	nursery.plots[0].tick_day()
	nursery.plots[1].tick_day()
	screen.on_screen_shown()
	_eq(errs, screen._tiles[0]._egg_visual.visible, true, "Quick Growth harvest shows mature egg")
	_eq(errs, screen._tiles[1]._plot_visual.texture, PlotTile._TEX_GROWTH0, "Slow and Steady stays small with three days left")
	nursery.plots[1].tick_day()
	screen.on_screen_shown()
	_eq(errs, screen._tiles[1]._plot_visual.texture, PlotTile._TEX_GROWTH0, "Slow and Steady stays small with two days left")
	nursery.plots[1].tick_day()
	screen.on_screen_shown()
	_eq(errs, screen._tiles[1]._plot_visual.texture, PlotTile._TEX_GROWTH1, "Slow and Steady grows larger with one day left")
	screen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _check_greenhouse_ui_refresh(errs: Array[String]) -> void:
	GameState.reset_run()
	_consume_first_plant_bonus(errs)
	GameState.pending_seal_choice = false
	GameState.troop.seed_if_empty(StarterPackages.build_units(StarterPackages.PACKAGE_IDS[0]))
	GameState.current_day = 2
	GameState.prefer_nursery_tab = true
	var nursery := GameState.nursery
	nursery.unlocked_plot_count = NurseryData.MAX_PLOT_COUNT
	for i in 3:
		if not nursery.plant_spore(i, nursery.make_fresh_common_spore()):
			errs.append("Greenhouse UI: plant %d failed" % i)
	nursery.plots[1].tick_day()
	var slow := load("res://assets/base/nursery/fertilizers/slow_and_steady.tres") as FertilizerData
	if not nursery.plots[2].apply_fertilizer(slow):
		errs.append("Greenhouse UI: Slow and Steady failed")
	var base := preload("res://assets/base/base.tscn").instantiate()
	get_tree().root.add_child(base)
	get_tree().current_scene = base
	var screen := base.get_node("%NurseryScreen") as NurseryScreen
	var colony := base.get_node("%ColonyScreen") as TroopSelectionScreen
	_eq(errs, screen._tiles[0]._days_chip._value_label.text, "2", "UI before seal: fresh grow")
	_eq(errs, screen._tiles[1]._days_chip._value_label.text, "1", "UI before seal: last day")
	_eq(errs, screen._tiles[2]._days_chip._value_label.text, "4", "UI before seal: Slow and Steady")
	GameState.pending_seal_choice = true
	colony.ensure_pending_modals()
	var greenhouse := load("res://assets/base/seals/greenhouse.tres") as SealData
	var dialog := colony._seal_dialog
	dialog._offers = [greenhouse]
	dialog._build_cards()
	dialog._on_card_pressed(greenhouse)
	dialog._on_confirm_pressed()
	_eq(errs, nursery.plots[0].remaining_days(), 1, "seal selection reduces stored Remaining Time")
	_eq(errs, screen._tiles[0]._days_chip._value_label.text, "1", "seal selection immediately refreshes countdown")
	_eq(errs, screen._tiles[0]._plot_visual.texture, PlotTile._TEX_GROWTH1, "Greenhouse shows larger grow with one day left")
	_eq(errs, nursery.plots[1].can_harvest(), true, "seal selection matures last-day grow")
	_eq(errs, screen._tiles[1]._days_chip.icon, PlotTile._HARVEST_ICON, "seal selection immediately shows harvest icon")
	_eq(errs, screen._tiles[1]._days_chip._value_label.visible, false, "seal selection hides completed countdown")
	_eq(errs, screen._tiles[2]._days_chip._value_label.text, "3", "seal selection refreshes fertilized countdown")
	_eq(errs, screen._tiles[3]._days_chip.visible, false, "empty plot keeps countdown hidden")
	_eq(errs, GameState.try_add_seal(greenhouse), false, "duplicate Greenhouse rejected")
	_eq(errs, nursery.plots[0].remaining_days(), 1, "duplicate Greenhouse does not cut again")
	base.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


## These checks cover normal grows; the first-plant bonus has its own harness.
func _consume_first_plant_bonus(errs: Array[String]) -> void:
	var nursery := GameState.nursery
	_eq(errs, nursery.plant_spore(0, nursery.make_fresh_common_spore()), true, "consume first planting")
	nursery.plots[0].clear()


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
