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

	var boom := load("res://assets/base/nursery/mutations/cap/boom.tres") as MutationData
	var fat := load("res://assets/base/nursery/mutations/body/fat.tres") as MutationData
	var wall := load("res://assets/base/nursery/mutations/cap/wall.tres") as MutationData

	# Empty plots accept mutations (capacity 1).
	var empty_plot := NurseryPlotData.new()
	if not empty_plot.apply_mutation(boom):
		errs.append("empty plot should accept mutation")
	if empty_plot.cap_mutation != boom:
		errs.append("empty plot did not keep cap")
	if empty_plot.apply_mutation(fat):
		errs.append("capacity 1 should reject second slot on empty plot")
	if not empty_plot.apply_mutation(wall):
		errs.append("same-slot replace on empty plot failed")
	if empty_plot.cap_mutation != wall or empty_plot.body_mutation != null:
		errs.append("same-slot replace left wrong slots")

	if not nursery.plant_spore(0, nursery.make_fresh_common_spore()):
		errs.append("plant failed")
	if not nursery.apply_mutation_to_plot(0, boom):
		errs.append("apply boom failed")
	if nursery.apply_mutation_to_plot(0, fat):
		errs.append("capacity 1 should reject body while cap filled")
	var plot := nursery.plots[0] as NurseryPlotData
	if plot.cap_mutation != boom or plot.body_mutation != null:
		errs.append("plot slots wrong after capacity reject")
	if not nursery.apply_mutation_to_plot(0, wall):
		errs.append("replace failed")
	if plot.cap_mutation != wall:
		errs.append("replace did not consume prior cap")

	# READY plots reject mutations (same as duration Fertilizers).
	var ready_plot := NurseryPlotData.new()
	ready_plot.planted_spore = nursery.make_fresh_common_spore()
	ready_plot.begin_planted_grow()
	ready_plot.remaining_time = 0
	if ready_plot.get_state() != NurseryPlotData.State.READY:
		errs.append("remaining 0 should be READY")
	elif ready_plot.can_apply_mutation(boom) or ready_plot.apply_mutation(boom):
		errs.append("READY plot should reject mutation")

	plot.remaining_time = 0
	var units := nursery.harvest(0)
	print("hatch=", units.size())
	if units.is_empty():
		errs.append("harvest empty")
	for u in units:
		if u.cap_mutation == null or u.cap_mutation.display_name != "Wall":
			errs.append("cap clone missing")
		if u.body_mutation != null:
			errs.append("harvest should not clone empty body")
		if u.cap_mutation == wall:
			errs.append("cap not duplicated")
		if u.stats == null:
			errs.append("missing stats")

	nursery.plant_spore(0, nursery.make_fresh_common_spore())
	nursery.apply_mutation_to_plot(0, boom)
	var meiosis := load("res://assets/base/nursery/fertilizers/meiosis.tres") as FertilizerData
	nursery.apply_fertilizer_to_plot(0, meiosis)
	plot = nursery.plots[0] as NurseryPlotData
	plot.remaining_time = 0
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
	if nursery.apply_mutation_to_plot(0, boom):
		errs.append("triploid setup should not allow second mutation")
	nursery.apply_fertilizer_to_plot(0, triploid)
	plot = nursery.plots[0] as NurseryPlotData
	plot.remaining_time = 0
	units = nursery.harvest(0)
	print("triploid=", units.size())
	if units.size() != 3:
		errs.append("triploid expected 3 got %d" % units.size())
	for u in units:
		if u.body_mutation == null or u.body_mutation.display_name != "Fat":
			errs.append("triploid body clone")
		if u.cap_mutation != null:
			errs.append("triploid should not have cap")

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

	var stacks := SealModifiers.max_fertilizer_stacks()
	print("fert stacks=", stacks, " (spreader only affects ferts)")

	_check_lineage_and_plant_merge(errs)

	if errs.is_empty():
		print("ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("ERRORS:")
		for e in errs:
			print(" - ", e)
		get_tree().quit(1)


func _check_lineage_and_plant_merge(errs: Array[String]) -> void:
	var boom := load("res://assets/base/nursery/mutations/cap/boom.tres") as MutationData
	var fat := load("res://assets/base/nursery/mutations/body/fat.tres") as MutationData
	var wall := load("res://assets/base/nursery/mutations/cap/wall.tres") as MutationData
	var meiosis := load("res://assets/base/nursery/fertilizers/meiosis.tres") as FertilizerData

	var adult := RosterUnitData.create(
		"Darwin",
		UnitStatsData.create_for_tier(UnitStatsData.PowerTier.UNCOMMON),
		WeaponSchool.sickle(),
		UnitStatsData.PowerTier.UNCOMMON
	)
	adult.lineage_name = "Darwin"
	adult.generation = 1
	adult.is_imago = true
	adult.cap_mutation = boom.duplicate(true) as MutationData
	adult.weapon_trainings = [WeaponSchool.Id.SWORD as int]
	adult.applied_fertilizers = [meiosis]
	adult.stats.strength = 10
	adult.stats.dex = 10
	adult.stats.con = 10
	adult.stats.spd = 10

	var nursery := NurseryData.new()
	nursery.seed_if_empty()
	var spore := nursery.add_death_spore(adult)
	if spore == null:
		errs.append("lineage spore emit failed")
		return
	print("lineage spore=", spore.display_name)
	if not spore.is_lineage_spore():
		errs.append("emitted spore not lineage")
	if spore.power_tier != UnitStatsData.PowerTier.UNCOMMON:
		errs.append("lineage lost tier")
	if spore.mean_stats == null:
		errs.append("lineage lost mean stats")
	elif spore.mean_stats.strength != 10:
		errs.append(
			"mean_stats should copy live stats (got STR %d)" % spore.mean_stats.strength
		)
	if spore.weapon_trainings.size() != 1:
		errs.append("lineage lost trainings")
	if spore.cap_mutation == null or spore.cap_mutation.display_name != "Boom":
		errs.append("lineage missing cap mutation snapshot")
	if spore.body_mutation != null:
		errs.append("lineage should not snapshot empty body")
	if spore.cap_mutation == adult.cap_mutation:
		errs.append("cap mutation not duplicated on emit")
	if spore.get("applied_fertilizers") != null:
		errs.append("spore should not expose fertilizer items")

	# Children do not emit lineage spores.
	var child := adult.duplicate(true) as RosterUnitData
	child.is_imago = false
	child.life_stage_id = &"juvenile"
	if nursery.add_death_spore(child) != null:
		errs.append("child should not emit lineage spore")

	# Spores no longer expose mutation apply API.
	if spore.has_method("apply_mutation"):
		errs.append("SporeData.apply_mutation should be removed")

	# Plant leaves plot slots empty so the apply chip stays ghost; harvest inherits spore Cap.
	if not nursery.plant_spore(0, spore):
		errs.append("plant lineage spore failed")
	var plot := nursery.plots[0] as NurseryPlotData
	if plot.cap_mutation != null:
		errs.append("plant should not seed spore cap onto plot")
	if plot.body_mutation != null:
		errs.append("plant should not invent body")
	if not plot.can_apply_mutation():
		errs.append("planted lineage with inheritance should still accept a plot mutation")
	plot.remaining_time = 0
	var units := nursery.harvest(0)
	print("lineage hatch=", units.size())
	if units.is_empty():
		errs.append("lineage harvest empty")
	for u in units:
		if u.cap_mutation == null or u.cap_mutation.display_name != "Boom":
			errs.append("lineage child missing cap")
		if u.body_mutation != null:
			errs.append("lineage child should not have body")
		if u.is_adult_stage():
			errs.append("lineage harvest should yield Children")
		if u.power_tier != UnitStatsData.PowerTier.UNCOMMON:
			errs.append("lineage child lost tier")
		if u.weapon_trainings.size() != 1:
			errs.append("lineage child lost trainings")

	# Plot Body + spore Cap stack at harvest (different slots keep both).
	nursery.plots[0] = NurseryPlotData.new()
	nursery.plots[0].apply_mutation(fat)
	var spore2 := SporeData.from_fallen_unit(adult)
	if spore2 == null:
		errs.append("second lineage spore failed")
		return
	if not nursery.plant_spore(0, spore2):
		errs.append("plant stack failed")
	var stacked_plot := nursery.plots[0] as NurseryPlotData
	if stacked_plot.body_mutation == null or stacked_plot.body_mutation.display_name != "Fat":
		errs.append("plant should keep staged plot body")
	if stacked_plot.cap_mutation != null:
		errs.append("plant should not seed spore cap onto plot")
	stacked_plot.remaining_time = 0
	var stacked_units := nursery.harvest(0)
	if stacked_units.is_empty():
		errs.append("stack harvest empty")
	for u in stacked_units:
		if u.body_mutation == null or u.body_mutation.display_name != "Fat":
			errs.append("stack harvest missing plot body")
		if u.cap_mutation == null or u.cap_mutation.display_name != "Boom":
			errs.append("stack harvest missing spore cap")

	# Same-slot: staged plot Cap wins over spore Cap (no overwrite on plant).
	nursery.plots[0] = NurseryPlotData.new()
	nursery.plots[0].apply_mutation(wall)
	var spore3 := SporeData.from_fallen_unit(adult)
	if not nursery.plant_spore(0, spore3):
		errs.append("same-slot plant failed")
	var overwritten := nursery.plots[0] as NurseryPlotData
	if overwritten.cap_mutation == null or overwritten.cap_mutation.display_name != "Wall":
		errs.append("same-slot plant should keep staged plot cap")
	if overwritten.body_mutation != null:
		errs.append("same-slot plant should not invent body")
	overwritten.remaining_time = 0
	var overwrite_units := nursery.harvest(0)
	if overwrite_units.is_empty():
		errs.append("same-slot harvest empty")
	for u in overwrite_units:
		if u.cap_mutation == null or u.cap_mutation.display_name != "Wall":
			errs.append("same-slot harvest should prefer plot cap")
		if u.body_mutation != null:
			errs.append("same-slot harvest should not invent body")

	# Plot-only kept when spore has no mutation.
	nursery.plots[0] = NurseryPlotData.new()
	nursery.plots[0].apply_mutation(fat)
	if not nursery.plant_spore(0, nursery.make_fresh_common_spore()):
		errs.append("fresh plant onto staged plot failed")
	var kept := nursery.plots[0] as NurseryPlotData
	if kept.body_mutation == null or kept.body_mutation.display_name != "Fat":
		errs.append("fresh plant should keep plot staged mutation")

	var detail_spore := SporeData.from_fallen_unit(adult)
	var tip := detail_spore.mutation_tooltip_lines()
	if tip.is_empty():
		errs.append("spore detail mutation lines missing")
