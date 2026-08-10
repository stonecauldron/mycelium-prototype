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

	_check_lineage_mutations(errs)

	if errs.is_empty():
		print("ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("ERRORS:")
		for e in errs:
			print(" - ", e)
		get_tree().quit(1)


func _check_lineage_mutations(errs: Array[String]) -> void:
	var boom := load("res://assets/base/nursery/mutations/boom.tres") as MutationData
	var fat := load("res://assets/base/nursery/mutations/fat.tres") as MutationData
	var wall := load("res://assets/base/nursery/mutations/wall.tres") as MutationData
	var meiosis := load("res://assets/base/nursery/fertilizers/meiosis.tres") as FertilizerData

	var adult := RosterUnitData.create(
		"Darwin",
		UnitStatsData.create_for_tier(UnitStatsData.PowerTier.UNCOMMON),
		WeaponSchool.sickle(),
		load("res://assets/units/generalist/generalist_strain.tres") as UnitStrain,
		UnitStatsData.PowerTier.UNCOMMON
	)
	adult.lineage_name = "Darwin"
	adult.generation = 1
	adult.is_imago = true
	adult.body_mutation = fat.duplicate(true) as MutationData
	adult.cap_mutation = boom.duplicate(true) as MutationData
	adult.weapon_trainings = [WeaponSchool.Id.SWORD as int]
	adult.applied_fertilizers = [meiosis]
	# Live adult stats already include Mutation hatch deltas (as after a real hatch).
	adult.stats.strength = 10
	adult.stats.dex = 10
	adult.stats.con = 10
	adult.stats.spd = 10
	fat.apply_hatch_stats(adult.stats)
	boom.apply_hatch_stats(adult.stats)
	var live_str := adult.stats.strength

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
	elif spore.mean_stats.strength != live_str:
		errs.append(
			"mean_stats should keep baked mutation hatch deltas (got STR %d, live was %d)"
			% [spore.mean_stats.strength, live_str]
		)
	if spore.weapon_trainings.size() != 1:
		errs.append("lineage lost trainings")
	if spore.body_mutation == null or spore.body_mutation.display_name != "Fat":
		errs.append("lineage missing body mutation snapshot")
	if spore.cap_mutation == null or spore.cap_mutation.display_name != "Boom":
		errs.append("lineage missing cap mutation snapshot")
	if spore.body_mutation == adult.body_mutation:
		errs.append("body mutation not duplicated on emit")
	# Fertilizers must not ride the spore as items.
	if spore.get("applied_fertilizers") != null:
		errs.append("spore should not expose fertilizer items")

	# Children do not emit lineage spores.
	var child := adult.duplicate(true) as RosterUnitData
	child.is_imago = false
	child.life_stage_id = &"juvenile"
	if nursery.add_death_spore(child) != null:
		errs.append("child should not emit lineage spore")

	# Stock prep / replace on lineage spore.
	if not nursery.add_mutation(wall.duplicate(true) as MutationData):
		errs.append("add wall mutation to stock failed")
	var spore_idx := -1
	var mut_idx := -1
	for i in nursery.stock.slots.size():
		var item: Resource = nursery.stock.slots[i]
		if item == spore:
			spore_idx = i
		elif item is MutationData and (item as MutationData).display_name == "Wall":
			mut_idx = i
	if spore_idx < 0 or mut_idx < 0:
		errs.append("stock indices missing for lineage prep")
	elif not nursery.apply_mutation_from_stock_to_lineage_spore(spore_idx, mut_idx):
		errs.append("stock lineage mutation apply failed")
	elif spore.cap_mutation == null or spore.cap_mutation.display_name != "Wall":
		errs.append("lineage replace did not consume prior cap")
	elif nursery.stock.get_at(mut_idx) != null:
		errs.append("mutation stock slot not consumed after lineage prep")

	# Non-lineage spores reject prep.
	var fresh := nursery.make_fresh_common_spore()
	if fresh.apply_mutation(boom):
		errs.append("fresh spore should reject mutation prep")

	# Plant + harvest yields Children with prepared Mutations.
	if not nursery.plant_spore(0, spore):
		errs.append("plant lineage spore failed")
	var plot := nursery.plots[0] as NurseryPlotData
	if plot.body_mutation == null or plot.body_mutation.display_name != "Fat":
		errs.append("plant did not seed body onto plot")
	if plot.cap_mutation == null or plot.cap_mutation.display_name != "Wall":
		errs.append("plant did not seed cap onto plot")
	plot.days_grown = plot.days_to_mature_effective()
	var units := nursery.harvest(0)
	print("lineage hatch=", units.size())
	if units.is_empty():
		errs.append("lineage harvest empty")
	for u in units:
		if u.body_mutation == null or u.body_mutation.display_name != "Fat":
			errs.append("lineage child missing body")
		if u.cap_mutation == null or u.cap_mutation.display_name != "Wall":
			errs.append("lineage child missing cap")
		if u.is_adult_stage():
			errs.append("lineage harvest should yield Children")
		if u.power_tier != UnitStatsData.PowerTier.UNCOMMON:
			errs.append("lineage child lost tier")
		if u.weapon_trainings.size() != 1:
			errs.append("lineage child lost trainings")

	# Detail lines for prepared mutations.
	var detail_spore := SporeData.from_fallen_unit(adult)
	var tip := detail_spore.mutation_tooltip_lines()
	if tip.size() < 2:
		errs.append("spore detail mutation lines missing")
