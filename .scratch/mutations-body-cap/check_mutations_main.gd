extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errs: Array[String] = []
	var nursery := NurseryData.new()
	nursery.seed_if_empty()
	var fert_count := 0
	var mut_count := 0
	for i in nursery.spore_shop.offers.size():
		var offer := nursery.spore_shop.offers[i]
		if offer == null or offer.item == null:
			errs.append("empty offer %d" % i)
			continue
		if offer.item is FertilizerData:
			fert_count += 1
			if NurseryData.is_mutation_shop_slot(i):
				errs.append("fert in mut slot %d" % i)
		elif offer.item is MutationData:
			mut_count += 1
			if not NurseryData.is_mutation_shop_slot(i):
				errs.append("mut in fert slot %d" % i)
			if offer.cost != MutationData.BIOMASS_COST:
				errs.append("mut cost %d" % offer.cost)
		else:
			errs.append("bad item type slot %d" % i)
	print("shop fert=", fert_count, " mut=", mut_count)
	if fert_count != 2 or mut_count != 2:
		errs.append("expected 2+2 shop")

	if not nursery.plant_spore(0, nursery.make_fresh_common_spore()):
		errs.append("plant failed")
	var boom := load("res://assets/base/nursery/mutations/boom.tres") as MutationData
	var fat := load("res://assets/base/nursery/mutations/fat.tres") as MutationData
	var wall := load("res://assets/base/nursery/mutations/wall.tres") as MutationData
	if not nursery.apply_mutation_to_plot(0, boom):
		errs.append("apply boom failed")
	if not nursery.apply_mutation_to_plot(0, fat):
		errs.append("apply fat failed")
	var plot := nursery.plots[0] as NurseryPlotData
	if plot.cap_mutation != boom or plot.body_mutation != fat:
		errs.append("plot slots wrong")
	if not nursery.apply_mutation_to_plot(0, wall):
		errs.append("replace failed")
	if plot.cap_mutation != wall:
		errs.append("replace did not consume prior cap")

	# Empty plot rejects mutations.
	if NurseryPlotData.new().apply_mutation(boom):
		errs.append("empty plot should reject mutation")

	# force_ready (Triploid) must not block mutation apply on READY plots.
	var ready_plot := NurseryPlotData.new()
	ready_plot.planted_spore = nursery.make_fresh_common_spore()
	var triploid_gate := load("res://assets/base/nursery/fertilizers/triploid_cells.tres") as FertilizerData
	ready_plot.apply_fertilizer(triploid_gate)
	if ready_plot.get_state() != NurseryPlotData.State.READY:
		errs.append("triploid should force READY")
	elif not ready_plot.apply_mutation(boom):
		errs.append("READY plot should still accept mutation")

	plot.days_grown = plot.days_to_mature_effective()
	var units := nursery.harvest(0)
	print("hatch=", units.size())
	if units.is_empty():
		errs.append("harvest empty")
	for u in units:
		if u.body_mutation == null or u.body_mutation.display_name != "Fat":
			errs.append("body clone missing")
		if u.cap_mutation == null or u.cap_mutation.display_name != "Wall":
			errs.append("cap clone missing")
		if u.body_mutation == fat:
			errs.append("body not duplicated")
		# Fat hatch deltas applied
		if u.stats == null:
			errs.append("missing stats")

	nursery.plant_spore(0, nursery.make_fresh_common_spore())
	nursery.apply_mutation_to_plot(0, boom)
	var meiosis := load("res://assets/base/nursery/fertilizers/meiosis.tres") as FertilizerData
	nursery.apply_fertilizer_to_plot(0, meiosis)
	plot = nursery.plots[0] as NurseryPlotData
	plot.days_grown = plot.days_to_mature_effective()
	units = nursery.harvest(0)
	print("meiosis=", units.size())
	if units.size() != 2:
		errs.append("meiosis expected 2 got %d" % units.size())
	for u in units:
		if u.cap_mutation == null or u.cap_mutation.display_name != "Boom":
			errs.append("meiosis missing boom clone")

	var triploid := load("res://assets/base/nursery/fertilizers/triploid_cells.tres") as FertilizerData
	nursery.plant_spore(0, nursery.make_fresh_common_spore())
	nursery.apply_mutation_to_plot(0, fat)
	nursery.apply_mutation_to_plot(0, boom)
	nursery.apply_fertilizer_to_plot(0, triploid)
	plot = nursery.plots[0] as NurseryPlotData
	plot.days_grown = plot.days_to_mature_effective()
	units = nursery.harvest(0)
	print("triploid=", units.size())
	if units.size() != 3:
		errs.append("triploid expected 3 got %d" % units.size())
	for u in units:
		if u.body_mutation == null or u.body_mutation.display_name != "Fat":
			errs.append("triploid body clone")
		if u.cap_mutation == null or u.cap_mutation.display_name != "Boom":
			errs.append("triploid cap clone")

	var starter := StarterPackages.preview_unit(StarterPackages.all_ids()[0])
	if starter.body_mutation != null or starter.cap_mutation != null:
		errs.append("starter mutations should be empty")

	# Buy / sell
	GameState.biomass.amount = 20
	GameState.nursery = NurseryData.new()
	GameState.nursery.seed_if_empty()
	var mut_offer: MutationData = null
	var mut_slot := -1
	for i in GameState.nursery.spore_shop.offers.size():
		var o := GameState.nursery.spore_shop.offers[i]
		if o != null and o.item is MutationData:
			mut_offer = o.item as MutationData
			mut_slot = i
			break
	if mut_offer == null:
		errs.append("no mutation offer to buy")
	elif not GameState.try_buy_mutation(mut_offer, mut_offer.biomass_cost):
		errs.append("buy mutation failed")
	else:
		var stock_idx := -1
		for i in GameState.nursery.stock.slots.size():
			if GameState.nursery.stock.slots[i] is MutationData:
				stock_idx = i
				break
		if stock_idx < 0:
			errs.append("bought mutation not in stock")
		elif not GameState.try_sell_nursery_stock_item(stock_idx):
			errs.append("sell mutation failed")

	# Spreader stays fertilizer-only: mutation apply ignores stack count.
	var stacks := SealModifiers.max_fertilizer_stacks()
	print("fert stacks=", stacks, " (spreader only affects ferts)")

	if errs.is_empty():
		print("ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("ERRORS:")
		for e in errs:
			print(" - ", e)
		get_tree().quit(1)
