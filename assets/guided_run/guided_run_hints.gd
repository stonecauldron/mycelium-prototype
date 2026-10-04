class_name GuidedRunHints
extends RefCounted

## Optional arrows introduce today's unlocks, never change gameplay.
static func next_hint() -> Dictionary:
	if not GameState.is_guided_run or GameState.debug_mode_active or GameState.has_won_run():
		return {}
	var day := GameState.get_upcoming_day()
	if GameState.pending_seal_choice:
		return _first_unseen([_hint("seal", &"battle", &"war")])

	var candidates: Array[Dictionary] = []
	match day:
		1:
			candidates.append(_hint("battle", &"battle", &"war"))
		2:
			candidates.append(_training_hint(WeaponSchool.Id.BOW, true))
		3:
			candidates.append(_training_hint(WeaponSchool.Id.SWORD))
		4:
			var progression := _hint("progression", &"progression", &"war")
			progression["action_required"] = true
			candidates.append(progression)
			var mace := _training_hint(WeaponSchool.Id.MACE)
			if not mace.is_empty():
				mace.erase("source")
				mace["action_required"] = true
			candidates.append(mace)
		5:
			candidates.append(_harvest_hint())
			candidates.append(_lineage_hint())
			candidates.append(_plant_hint())
			candidates.append(_grow_item_hint(false))
		6:
			candidates.append(_capacity_hint())
		7:
			candidates.append(_grow_item_hint(true))
			candidates.append(_harvested_shield_hint())
			candidates.append(_compost_hint())
		8:
			candidates.append(_plot_capacity_hint())
		9:
			var spear := _training_hint(WeaponSchool.Id.SPEAR)
			spear.erase("source")
			candidates.append(spear)
	return _first_unseen(candidates)


static func history_key(hint: Dictionary) -> String:
	return "%d:%s" % [GameState.get_upcoming_day(), str(hint.get("id", ""))]


static func record_training(unit: RosterUnitData, school: int) -> void:
	if not GameState.is_guided_run:
		return
	var day := GameState.get_upcoming_day()
	if day == 4 and school == WeaponSchool.Id.MACE:
		GameState.guided_hint_history["4:training_%d" % WeaponSchool.Id.MACE] = true
	if day != 3:
		return
	var trained_units: Array = GameState.guided_hint_history.get("3:trained_units", [])
	if not trained_units.has(unit):
		trained_units.append(unit)
	GameState.guided_hint_history["3:trained_units"] = trained_units
	if trained_units.size() >= 2:
		GameState.guided_hint_history["3:training_%d" % WeaponSchool.Id.SWORD] = true


static func record_day_inspected(day: int) -> void:
	if GameState.is_guided_run and GameState.get_upcoming_day() == 4 and day == 5:
		GameState.guided_hint_history["4:progression"] = true


static func record_harvest(units: Array[RosterUnitData]) -> void:
	if GameState.is_guided_run and GameState.get_upcoming_day() == 7 and not units.is_empty():
		GameState.guided_hint_history["7:harvested_units"] = units.duplicate()


static func record_compost_hover() -> void:
	if GameState.is_guided_run and GameState.is_feature_available(&"compost"):
		GameState.guided_hint_history["%d:compost" % GameState.get_upcoming_day()] = true


static func record_shield_hover() -> void:
	if GameState.is_guided_run and GameState.is_school_available(WeaponSchool.Id.SHIELD):
		GameState.guided_hint_history["%d:training_%d" % [GameState.get_upcoming_day(), WeaponSchool.Id.SHIELD]] = true


static func record_spear_hover() -> void:
	if GameState.is_guided_run and GameState.is_school_available(WeaponSchool.Id.SPEAR):
		GameState.guided_hint_history["%d:training_%d" % [GameState.get_upcoming_day(), WeaponSchool.Id.SPEAR]] = true


static func _first_unseen(candidates: Array[Dictionary]) -> Dictionary:
	for candidate in candidates:
		if not candidate.is_empty() and not bool(GameState.guided_hint_history.get(history_key(candidate), false)):
			return candidate
	return {}


static func _hint(id: String, target: StringName, tab: StringName, passive: bool = false) -> Dictionary:
	return {"id": id, "target": target, "tab": tab, "passive": passive}


static func _with_source(hint: Dictionary, source: Dictionary) -> Dictionary:
	source["id"] = "%s:source" % str(hint["id"])
	source["passive"] = false
	hint["source"] = source
	return hint


static func _unit_source(unit: RosterUnitData) -> Dictionary:
	return {"target": &"unit", "tab": &"war", "unit": unit}


static func _troop_units() -> Array[RosterUnitData]:
	var units: Array[RosterUnitData] = []
	for row in [GameState.troop.squad, GameState.troop.bench]:
		for unit: RosterUnitData in row:
			if unit != null:
				units.append(unit)
	return units


static func _training_hint(school: int, children_only: bool = false) -> Dictionary:
	for unit in _troop_units():
		if children_only and unit.is_adult_stage():
			continue
		var candidate := _train_unit_hint(unit, school)
		if not candidate.is_empty():
			return candidate
	return {}


static func _harvested_shield_hint() -> Dictionary:
	var harvested: Array = GameState.guided_hint_history.get("7:harvested_units", [])
	var troop_units := _troop_units()
	for unit: RosterUnitData in harvested:
		# Undo or overflow can leave a harvested Unit outside the current Troop.
		if not troop_units.has(unit):
			continue
		var candidate := _train_unit_hint(unit, WeaponSchool.Id.SHIELD)
		if not candidate.is_empty():
			return candidate
	return {}


static func _train_unit_hint(unit: RosterUnitData, school: int) -> Dictionary:
	if not GameState.biomass.can_afford(WeaponSchool.COCOON_COST):
		return {}
	if not GameState.can_cocoon_for_pupation(unit, school):
		return {}
	var hint := _hint("training_%d" % school, &"school", &"war")
	hint["school"] = school
	return _with_source(hint, _unit_source(unit))


static func _harvest_hint() -> Dictionary:
	if not GameState.is_feature_available(&"nursery") or not GameState.troop.has_free_slot():
		return {}
	for index in GameState.nursery.unlocked_plot_count:
		var plot := GameState.nursery.plots[index] as NurseryPlotData
		if plot != null and plot.can_harvest():
			return _plot_hint("harvest", index)
	return {}


static func _plant_hint() -> Dictionary:
	if not GameState.is_feature_available(&"nursery"):
		return {}
	if not GameState.biomass.can_afford(SealModifiers.fresh_plant_cost()):
		return {}
	var index := GameState.nursery.first_empty_plot_index()
	if index >= 0 and GameState.nursery.can_plant_on_plot(index):
		return _plot_hint("plant", index)
	return {}


static func _lineage_hint() -> Dictionary:
	if not GameState.is_feature_available(&"nursery"):
		return {}
	var index := GameState.nursery.first_empty_plot_index()
	if index < 0 or not GameState.nursery.can_plant_on_plot(index):
		return {}
	for stock_index in GameState.nursery.stock.slots.size():
		var spore := GameState.nursery.stock.get_at(stock_index) as SporeData
		if spore == null or not spore.is_lineage_spore():
			continue
		var hint := _plot_hint("lineage", index)
		hint["plot_action"] = &"apply"
		return _with_source(hint, {"target": &"stock", "tab": &"nursery", "stock_index": stock_index})
	return {}


static func _grow_item_hint(mutation: bool) -> Dictionary:
	var feature := &"mutations" if mutation else &"shop"
	if not GameState.is_feature_available(feature):
		return {}
	var id := "mutation" if mutation else "quick_growth"
	return _available_item_hint(id, _is_intro_item.bind(mutation))


static func _available_item_hint(id: String, accepts: Callable) -> Dictionary:
	for index in GameState.nursery.stock.slots.size():
		var item := GameState.nursery.stock.get_at(index)
		if not accepts.call(item):
			continue
		var candidate := _item_plot_hint(item, id, {"target": &"stock", "tab": &"nursery", "stock_index": index})
		if not candidate.is_empty():
			return candidate
	var shop := GameState.nursery.spore_shop
	if shop == null:
		return {}
	for index in shop.offers.size():
		var offer := shop.offers[index]
		if offer == null or not accepts.call(offer.item):
			continue
		var cost := SealModifiers.mutation_cost(offer.cost) if offer.item is MutationData else SealModifiers.fertilizer_cost(offer.cost)
		if not GameState.biomass.can_afford(cost):
			continue
		var candidate := _item_plot_hint(offer.item, id, {"target": &"shop", "tab": &"nursery", "shop_index": index})
		if not candidate.is_empty():
			return candidate
	return {}


static func _is_intro_item(item: Resource, mutation: bool) -> bool:
	if mutation:
		var mutation_data := item as MutationData
		return mutation_data != null and mutation_data.effect != null and mutation_data.effect.get_script() == GuidedRun.MOULD.effect.get_script()
	var fertilizer := item as FertilizerData
	return fertilizer != null and fertilizer.growth_bonus > 0


static func _item_plot_hint(item: Resource, id: String, source: Dictionary) -> Dictionary:
	for index in GameState.nursery.unlocked_plot_count:
		var plot := GameState.nursery.plots[index] as NurseryPlotData
		if plot == null:
			continue
		if item is FertilizerData:
			var fertilizer := item as FertilizerData
			if not plot.check_fertilizer_application(fertilizer).allowed:
				continue
			if (fertilizer.growth_bonus > 0 or fertilizer.force_ready) and (plot.is_empty() or plot.remaining_days() <= 0):
				continue
		elif item is MutationData:
			if not plot.check_mutation_application(item as MutationData).allowed:
				continue
		else:
			continue
		var hint := _plot_hint(id, index)
		hint["plot_action"] = &"apply"
		return _with_source(hint, source)
	return {}


static func _plot_capacity_hint() -> Dictionary:
	var nursery := GameState.nursery
	if not nursery.can_unlock_plot() or nursery.first_empty_plot_index() >= 0:
		return {}
	var cost := nursery.next_unlock_cost()
	if cost < 0 or not GameState.biomass.can_afford(cost):
		return {}
	return _hint("plot_slot", &"plot_slot", &"nursery")


static func _capacity_hint() -> Dictionary:
	if not GameState.troop.can_unlock_squad_slot() or GameState.troop.first_empty_unlocked_squad() >= 0:
		return {}
	var cost := GameState.troop.next_squad_unlock_cost()
	if cost < 0 or not GameState.biomass.can_afford(cost):
		return {}
	var needs_room := GameState.nursery.ready_plot_count() > 0
	for unit: RosterUnitData in GameState.troop.bench:
		needs_room = needs_room or unit != null
	if needs_room:
		return _hint("squad_slot", &"squad_slot", &"war")
	return {}


static func _compost_hint() -> Dictionary:
	if GameState.nursery.first_lineage_spore != null:
		return {}
	for item in GameState.nursery.stock.slots:
		var spore := item as SporeData
		if spore != null and spore.is_lineage_spore():
			return {}
	for unit in _troop_units():
		if unit.is_adult_stage() and GameState.can_compost_unit(unit):
			return _hint("compost", &"compost", &"war")
	return {}


static func _plot_hint(id: String, index: int) -> Dictionary:
	var hint := _hint(id, &"plot", &"nursery")
	hint["plot_index"] = index
	return hint
