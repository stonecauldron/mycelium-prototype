extends Node

var _errors: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_paid_planting()
	_check_stock_planting()
	_check_modifiers()
	if _errors.is_empty():
		print("FIRST SPORE: ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		for error in _errors:
			push_error(error)
		get_tree().quit(1)


func _check_paid_planting() -> void:
	GameState.reset_run()
	GameState.debug_advance_day()
	var nursery := GameState.nursery
	var plot := nursery.plots[0] as NurseryPlotData
	_eq(GameState.is_nursery_unlocked(), true, "Nursery unlocked")
	for entry in nursery.plots:
		_eq(entry.is_empty(), true, "Nursery unlocks empty")
	for item in nursery.stock.slots:
		_eq(item, null, "no gift in stock")
	_eq(nursery.plant_spore(0, null), false, "null planting rejected")
	_eq(GameState.try_plant_fresh_common(1), false, "locked plot rejected")
	_eq(GameState.try_plant_fresh_common(-1), false, "invalid plot rejected")
	GameState.biomass.amount = 0
	_eq(GameState.try_plant_fresh_common(0), false, "unaffordable planting rejected")
	GameState.biomass.amount = 20
	_eq(GameState.try_plant_fresh_common(0), true, "first paid planting succeeds")
	_eq(GameState.biomass.amount, 20 - SealModifiers.fresh_plant_cost(), "normal planting cost charged")
	_eq(plot.remaining_days(), 1, "failed attempts preserve first-plant bonus")
	_eq(plot.days_grown, 0, "spore starts newly planted")
	_eq(plot.get_state(), NurseryPlotData.State.GROWING, "first grow is not ready early")
	GameState.ensure_nursery_seeded()
	GameState.begin_day()
	_eq(plot.remaining_days(), 1, "refresh preserves countdown")
	_eq(GameState.try_plant_fresh_common(0), false, "occupied plot rejected")

	var screen := preload("res://assets/base/nursery/nursery_screen.tscn").instantiate() as NurseryScreen
	add_child(screen)
	_eq(screen._tiles[0]._days_chip._value_label.text, "1", "UI shows one day remaining")
	GameState.debug_advance_day()
	screen.on_screen_shown()
	_eq(plot.can_harvest(), true, "first grow matures on next day")
	_eq(screen._tiles[0]._egg_visual.visible, true, "UI shows harvest-ready egg")
	_eq(nursery.harvest(0).size(), 1, "harvest produces one unit")
	_eq(GameState.try_plant_fresh_common(0), true, "second planting succeeds")
	_eq(plot.remaining_days(), 2, "second grow uses normal time")
	screen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	GameState.reset_run()
	GameState.debug_advance_day()
	GameState.biomass.amount = 20
	_eq(GameState.try_plant_fresh_common(0), true, "new run first planting succeeds")
	_eq(nursery.plots[0].remaining_days(), 1, "new run restores bonus")


func _check_stock_planting() -> void:
	GameState.reset_run()
	GameState.debug_advance_day()
	# Waiting to plant and choosing another unlocked plot still grant the first-plant bonus.
	GameState.debug_advance_day()
	var nursery := GameState.nursery
	_eq(nursery.unlock_next_plot(), true, "unlock alternate plot")
	var template := load("res://assets/base/nursery/common_spore.tres") as SporeData
	_eq(nursery.stock.set_at(0, template), true, "stock a Common Spore")
	_eq(nursery.plant(1, 0), true, "first planting from stock succeeds")
	var plot := nursery.plots[1] as NurseryPlotData
	_eq(plot.remaining_days(), 1, "stock planting receives bonus on alternate plot")
	_eq(nursery.stock.get_at(0), null, "stock spore consumed")
	_eq(template.days_to_mature, 2, "shared template stays unchanged")
	plot.clear()
	_eq(nursery.plant_spore(1, template), true, "replant after destroying first grow")
	_eq(plot.remaining_days(), 2, "destroying first grow does not restore bonus")
	_eq(nursery.plant_spore(0, template), true, "plant in original first plot")
	_eq(nursery.plots[0].remaining_days(), 2, "bonus is per run, not per plot")

	GameState.reset_run()
	var lineage := SporeData.new()
	lineage.lineage_name = "Test Lineage"
	lineage.days_to_mature = 1
	_eq(nursery.stock.set_at(0, lineage), true, "stock a lineage spore")
	_eq(nursery.plant(0, 0), true, "first planting can be lineage")
	_eq(nursery.plots[0].remaining_days(), 1, "one-day lineage is not shortened further")
	nursery.plots[0].clear()
	_eq(nursery.plant_spore(0, template), true, "Common follows lineage")
	_eq(nursery.plots[0].remaining_days(), 2, "lineage planting consumes the bonus")


func _check_modifiers() -> void:
	var greenhouse := load("res://assets/base/seals/greenhouse.tres") as SealData
	GameState.reset_run()
	_eq(GameState.try_add_seal(greenhouse), true, "opening Greenhouse selected")
	GameState.debug_advance_day()
	var nursery := GameState.nursery
	_eq(nursery.plant_spore(0, nursery.make_fresh_common_spore()), true, "first planting with Greenhouse")
	_eq(nursery.plots[0].remaining_days(), 0, "Greenhouse first grow is immediate")
	_eq(nursery.plots[0].can_harvest(), true, "Greenhouse first grow can be harvested")
	nursery.harvest(0)
	_eq(nursery.plant_spore(0, nursery.make_fresh_common_spore()), true, "second planting with Greenhouse")
	_eq(nursery.plots[0].remaining_days(), 1, "later Greenhouse grows take one day")

	GameState.reset_run()
	_eq(nursery.plant_spore(0, nursery.make_fresh_common_spore()), true, "first planting before Greenhouse")
	_eq(GameState.try_add_seal(greenhouse), true, "Greenhouse selected mid-grow")
	_eq(nursery.plots[0].can_harvest(), true, "mid-grow Greenhouse matures first spore")

	for fertilizer_name in ["quick_growth", "slow_and_steady"]:
		GameState.reset_run()
		var fertilizer := load("res://assets/base/nursery/fertilizers/%s.tres" % fertilizer_name) as FertilizerData
		_eq(nursery.apply_fertilizer_to_plot(0, fertilizer), true, "prepare %s" % fertilizer_name)
		_eq(nursery.plant_spore(0, nursery.make_fresh_common_spore()), true, "first planting after fertilizer")
		var expected_days := 0 if fertilizer_name == "quick_growth" else 2
		_eq(nursery.plots[0].remaining_days(), expected_days, "fertilizer applies to one-day grow")


func _eq(got: Variant, expected: Variant, label: String) -> void:
	if got != expected:
		_errors.append("%s: got %s expected %s" % [label, str(got), str(expected)])
