extends Node

const _DURATION_CASES := [
	["quick_growth", 1, 0],
	["slow_and_steady", 4, 2],
	["stress_induced_growth", 0, 0],
]

var _failures: int = 0


func _ready() -> void:
	Analytics.ga = null
	GameState.is_guided_run = false
	GameState.seals = SealsCollection.new()
	for entry in _DURATION_CASES:
		var fertilizer := load("res://assets/base/nursery/fertilizers/%s.tres" % entry[0]) as FertilizerData
		_check_duration(fertilizer, int(entry[1]), int(entry[2]))
		for ready_kind in 3:
			_check_ready_routes(fertilizer, ready_kind)
	_check_other_fertilizers()
	_check_split_fertilizers()
	print("Nursery fertilizer checks: preparation, growth, harvestable Plot drops and purchases, stacked hatch yields and previews; failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check_duration(fertilizer: FertilizerData, expected_fresh: int, expected_late: int) -> void:
	var label := fertilizer.display_name
	var prepared := NurseryPlotData.new()
	_expect(prepared.apply_fertilizer(fertilizer), label + ": can prepare empty dirt")
	prepared.planted_spore = SporeData.new()
	prepared.begin_planted_grow()
	_expect(prepared.remaining_days() == expected_fresh, label + ": prepared effect applies at planting")
	var growing := _planted_plot()
	_expect(growing.check_fertilizer_application(fertilizer).allowed, label + ": eligible while growing")
	_expect(growing.apply_fertilizer(fertilizer), label + ": applies while growing")
	_expect(growing.remaining_days() == expected_fresh, label + ": changes Remaining Time while growing")
	var late := _planted_plot()
	late.tick_day()
	_expect(late.apply_fertilizer(fertilizer), label + ": applies with one Day remaining")
	_expect(late.remaining_days() == expected_late, label + ": late effect uses Remaining Time")


func _check_ready_routes(fertilizer: FertilizerData, ready_kind: int) -> void:
	GameState.nursery = NurseryData.new()
	GameState.nursery.seed_if_empty()
	GameState.biomass.amount = 20
	var plot := _planted_plot()
	if ready_kind == 2:
		plot.remaining_time = 0
	else:
		plot.tick_day()
		plot.tick_day()
		if ready_kind == 1:
			plot.remaining_time = NurseryPlotData.REMAINING_UNSET
	GameState.nursery.plots[0] = plot
	GameState.nursery.stock.set_at(0, fertilizer)
	var offer := ShopOffer.new()
	offer.item = fertilizer
	offer.cost = fertilizer.biomass_cost
	GameState.nursery.spore_shop.offers[0] = offer
	var label := "%s, ready kind %d" % [fertilizer.display_name, ready_kind]
	var spore := plot.planted_spore
	var remaining := plot.remaining_time
	var grown := plot.days_grown
	_expect(plot.can_harvest(), label + ": fixture is harvestable")
	var decision := plot.check_fertilizer_application(fertilizer)
	_expect(not decision.allowed and decision.reason == ActionReasons.PLOT_STATE_REJECTS_FERTILIZER,
		label + ": eligibility rejects growth-stage violation")
	_expect(not plot.apply_fertilizer(fertilizer), label + ": direct application rejects")
	_expect(not GameState.nursery.apply_fertilizer_from_stock(0, 0), label + ": Stock application rejects")
	_expect(GameState.nursery.stock.get_at(0) == fertilizer, label + ": rejected Stock item is retained")
	var tile := PlotTile.new()
	tile._plot = plot
	for drop_type in ["fertilizer", "shop_fertilizer"]:
		_expect(not tile._accepts_drag_data({"type": drop_type, "fertilizer": fertilizer}),
			label + ": rejects " + drop_type + " drop")
	tile.free()
	var screen := NurseryScreen.new()
	screen._apply_fertilizer_from_shop(0, {
		"type": "shop_fertilizer", "fertilizer": fertilizer,
		"cost": offer.cost, "slot_index": 0,
	})
	screen.free()
	_expect(GameState.biomass.amount == 20, label + ": rejected Shop application retains Biomass")
	_expect(GameState.nursery.spore_shop.offers[0] == offer, label + ": rejected Shop offer is retained")
	_expect(plot.planted_spore == spore and plot.days_grown == grown
		and plot.remaining_time == remaining and plot.applied_fertilizers.is_empty() and plot.can_harvest(),
		label + ": rejection preserves the grow and free Fertilizer slot")


func _check_other_fertilizers() -> void:
	for path in NurseryData._FERTILIZER_PATHS:
		var fertilizer := load(path) as FertilizerData
		if fertilizer.growth_bonus != 0 or fertilizer.force_ready \
			or fertilizer.behavior == FertilizerData.Behavior.SLOW_STEADY:
			continue
		var plot := _planted_plot()
		plot.remaining_time = 0
		_expect(plot.check_fertilizer_application(fertilizer).allowed,
			fertilizer.display_name + ": remains eligible when harvestable")
		_expect(plot.apply_fertilizer(fertilizer), fertilizer.display_name + ": applies when harvestable")
	var full := _planted_plot()
	full.remaining_time = 0
	var brute := load("res://assets/base/nursery/fertilizers/brute_force.tres") as FertilizerData
	_expect(full.apply_fertilizer(brute), "Stat Fertilizer fills the harvestable Plot's slot")
	_expect(not full.apply_fertilizer(brute), "Fertilizer capacity still applies when harvestable")
	var fungicide := load("res://assets/base/nursery/fertilizers/fungicide.tres") as FertilizerData
	_expect(full.apply_fertilizer(fungicide), "Fungicide still applies to a full harvestable Plot")
	_expect(full.is_empty() and full.pending_stat_bonus == NurseryPlotData.FUNGICIDE_NEXT_SPORE_BONUS,
		"Fungicide kills the harvestable grow and leaves Extra nutrition")


func _check_split_fertilizers() -> void:
	GameState.seals.add(load("res://assets/base/seals/fertilizer_spreader.tres") as SealData)
	var cases := [
		[[], 1],
		[["meiosis"], 2],
		[["triploid_cells"], 3],
		[["meiosis", "meiosis"], 4],
		[["triploid_cells", "triploid_cells"], 9],
		[["meiosis", "triploid_cells"], 6],
		[["triploid_cells", "meiosis"], 6],
	]
	for lineage in [false, true]:
		for entry in cases:
			var plot := _planted_plot()
			if lineage:
				plot.planted_spore.lineage_name = "Split test"
				plot.planted_spore.mean_stats = UnitStatsData.new()
				plot.planted_spore.mean_stats.strength = 26
				plot.planted_spore.mean_stats.dex = 44
				plot.planted_spore.mean_stats.con = 62
				plot.pending_stat_bonus = 4
			plot.remaining_time = 0
			GameState.nursery.plots[0] = plot.duplicate(true)
			var baseline := GameState.nursery.harvest(0)
			var count: int = entry[1]
			var label := "%s, lineage %s" % [str(entry[0]), str(lineage)]
			for fertilizer_name in entry[0]:
				var fertilizer := load("res://assets/base/nursery/fertilizers/%s.tres" % fertilizer_name) as FertilizerData
				_expect(plot.apply_fertilizer(fertilizer), label + ": stacked Fertilizer applies")
			var preview := SporeDetailCard.new()
			preview.spore_data = plot.planted_spore
			preview.plot_data = plot
			var expected_average := UnitStatsData.average_for_tier(plot.planted_spore.power_tier)
			if lineage:
				expected_average = plot.planted_spore.mean_stats.duplicate(true) as UnitStatsData
			expected_average.add_all(plot.pending_stat_bonus)
			_expect_divided_stats(preview._preview_average_stats(), expected_average, count, label + ": preview")
			preview.free()
			GameState.nursery.plots[0] = plot
			var units := GameState.nursery.harvest(0)
			_expect(units.size() == count, label + ": correct hatch count")
			for unit in units:
				_expect_divided_stats(unit.stats, baseline[0].stats, count, label + ": hatch")
			if units.size() > 1:
				var sibling_strength := units[1].stats.strength
				units[0].stats.strength += 1
				_expect(units[1].stats.strength == sibling_strength, label + ": hatchlings have independent Stats")
			_expect(plot.is_empty() and plot.applied_fertilizers.is_empty(), label + ": harvest consumes the grow")
	GameState.seals = SealsCollection.new()


func _expect_divided_stats(actual: UnitStatsData, original: UnitStatsData, divisor: int, label: String) -> void:
	_expect(actual.strength == maxi(1, roundi(float(original.strength) / divisor))
		and actual.dex == maxi(1, roundi(float(original.dex) / divisor))
		and actual.con == maxi(1, roundi(float(original.con) / divisor)),
		label + ": divides all Stats once, preserving rounding and the minimum of 1")


func _planted_plot() -> NurseryPlotData:
	var plot := NurseryPlotData.new()
	plot.planted_spore = SporeData.new()
	plot.begin_planted_grow()
	return plot


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
