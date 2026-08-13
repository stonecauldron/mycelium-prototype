class_name NurseryData
extends Resource

const MAX_PLOT_COUNT := 9
const STARTING_UNLOCKED_PLOTS := 1
const SHOP_SLOT_COUNT := 4
const SHOP_FERTILIZER_SLOT_COUNT := 2
const SHOP_MUTATION_SLOT_COUNT := 2
const STOCK_SLOT_COUNT := 5
const STARTER_SPORE_COUNT := 0
## Fresh empty-plot grows use the Common Spore baseline (cost / days).
const _COMMON_SPORE_PATH := "res://assets/base/nursery/common_spore.tres"
const _FERTILIZER_PATHS: Array[String] = [
	"res://assets/base/nursery/fertilizers/reinforced_chitin.tres",
	"res://assets/base/nursery/fertilizers/brute_force.tres",
	"res://assets/base/nursery/fertilizers/hollow_chitin.tres",
	"res://assets/base/nursery/fertilizers/finesse.tres",
	"res://assets/base/nursery/fertilizers/stress_induced_growth.tres",
	"res://assets/base/nursery/fertilizers/quick_growth.tres",
	"res://assets/base/nursery/fertilizers/slow_and_steady.tres",
	"res://assets/base/nursery/fertilizers/meiosis.tres",
	"res://assets/base/nursery/fertilizers/triploid_cells.tres",
	"res://assets/base/nursery/fertilizers/fungicide.tres",
	"res://assets/base/nursery/fertilizers/amok.tres",
	"res://assets/base/nursery/fertilizers/training_amnesia.tres",
	"res://assets/base/nursery/fertilizers/cocooning.tres",
	"res://assets/base/nursery/fertilizers/stimulants.tres",
	"res://assets/base/nursery/fertilizers/late_bloomer.tres",
	"res://assets/base/nursery/fertilizers/normifier.tres",
	"res://assets/base/nursery/fertilizers/volatile.tres",
]
const _BODY_MUTATION_PATHS: Array[String] = [
	"res://assets/base/nursery/mutations/body/fat.tres",
	"res://assets/base/nursery/mutations/body/rubber.tres",
	"res://assets/base/nursery/mutations/body/zombie.tres",
	"res://assets/base/nursery/mutations/body/thorny.tres",
]
const _CAP_MUTATION_PATHS: Array[String] = [
	"res://assets/base/nursery/mutations/cap/death.tres",
	"res://assets/base/nursery/mutations/cap/inky.tres",
	"res://assets/base/nursery/mutations/cap/boom.tres",
	"res://assets/base/nursery/mutations/cap/wall.tres",
	"res://assets/base/nursery/mutations/cap/bank.tres",
	"res://assets/base/nursery/mutations/cap/brood_empress.tres",
	"res://assets/base/nursery/mutations/cap/mould.tres",
]

@export var plots: Array = []
## Shared nursery inventory: SporeData, FertilizerData, and MutationData entries.
@export var stock: StockInventory
## Nursery shop state (offers + locks). Shared ShopInventory used by any shop screen.
@export var spore_shop: ShopInventory
@export var unlocked_plot_count: int = STARTING_UNLOCKED_PLOTS
## Paid shop reroll cost (flat; kept for save/API compatibility with reset/advance).
@export var shop_reroll_cost: int = BiomassData.SHOP_REROLL_COST

var _seeded: bool = false
## Monotonic stamp for FIFO eviction when death-spores overflow stock.
var _next_stock_seq: int = 1
const _STOCK_SEQ_META := &"_nursery_stock_seq"


func _init() -> void:
	unlocked_plot_count = STARTING_UNLOCKED_PLOTS
	_ensure_plot_count()
	_ensure_stock()
	_ensure_spore_shop()


func is_seeded() -> bool:
	return _seeded


func seed_if_empty() -> void:
	_ensure_plot_count()
	_ensure_spore_shop()
	_ensure_stock()
	if _seeded:
		return
	stock.clear()
	var common_spore := load(_COMMON_SPORE_PATH) as SporeData
	if common_spore != null:
		for i in mini(STARTER_SPORE_COUNT, STOCK_SLOT_COUNT):
			stock.set_at(i, common_spore)
	spore_shop.ensure_filled(generate_offer_for_slot)
	_normalize_shop_offers()
	_seeded = true


func reset() -> void:
	plots.clear()
	unlocked_plot_count = STARTING_UNLOCKED_PLOTS
	_ensure_spore_shop()
	spore_shop.clear()
	_seeded = false
	_next_stock_seq = 1
	_ensure_plot_count()
	_ensure_stock()
	stock.clear()
	reset_shop_reroll_cost()


func current_shop_reroll_cost() -> int:
	return BiomassData.SHOP_REROLL_COST


func advance_shop_reroll_cost() -> void:
	pass


func reset_shop_reroll_cost() -> void:
	shop_reroll_cost = BiomassData.SHOP_REROLL_COST


func is_plot_unlocked(plot_index: int) -> bool:
	return plot_index >= 0 and plot_index < unlocked_plot_count


func can_unlock_plot() -> bool:
	return unlocked_plot_count < MAX_PLOT_COUNT


func next_unlock_cost() -> int:
	if not can_unlock_plot():
		return -1
	return BiomassData.PLOT_UNLOCK_BASE_COST * unlocked_plot_count * unlocked_plot_count


func unlock_next_plot() -> bool:
	if not can_unlock_plot():
		return false
	unlocked_plot_count += 1
	_ensure_plot_count()
	return true


func ensure_shop_offers() -> void:
	_ensure_spore_shop()
	spore_shop.ensure_filled(generate_offer_for_slot)
	_normalize_shop_offers()


func reroll_unlocked_shop_offers() -> void:
	_ensure_spore_shop()
	spore_shop.reroll_unlocked(generate_offer_for_slot)
	_normalize_shop_offers()


## Drop legacy Spore SKUs and keep slot kinds: 0–1 Fertilizer, 2–3 Mutation.
func _normalize_shop_offers() -> void:
	_ensure_spore_shop()
	while spore_shop.offers.size() < SHOP_SLOT_COUNT:
		spore_shop.offers.append(null)
	for i in spore_shop.offers.size():
		var offer := spore_shop.offers[i]
		if offer == null or offer.is_empty():
			continue
		if offer.item is SporeData:
			spore_shop.offers[i] = generate_offer_for_slot(i)
			continue
		if is_mutation_shop_slot(i):
			if not (offer.item is MutationData):
				spore_shop.offers[i] = generate_mutation_offer()
		elif not (offer.item is FertilizerData):
			spore_shop.offers[i] = generate_fertilizer_offer()


func replace_shop_slot(slot_index: int) -> void:
	_ensure_spore_shop()
	spore_shop.replace_slot(slot_index)


static func is_mutation_shop_slot(slot_index: int) -> bool:
	return slot_index >= SHOP_FERTILIZER_SLOT_COUNT


func can_add_stock_item() -> bool:
	_ensure_stock()
	return stock.can_add()


func add_stock_item(item: Resource) -> bool:
	return add_stock_item_at(item, -1) >= 0


## Places item in first empty slot (or `slot_index` if >= 0). Returns slot index, or -1.
func add_stock_item_at(item: Resource, slot_index: int = -1) -> int:
	_ensure_stock()
	if item == null or not (item is SporeData or item is FertilizerData or item is MutationData):
		return -1
	var dest := stock.add(item, slot_index)
	if dest >= 0:
		_stamp_stock_seq(item)
	return dest


func can_add_spore() -> bool:
	return can_add_stock_item()


func add_spore(spore: SporeData) -> bool:
	return add_stock_item(spore)


## Build a lineage spore from a fallen adult and place it in stock (FIFO if full).
func add_death_spore(unit: RosterUnitData) -> SporeData:
	if unit == null or not unit.is_adult_stage():
		return null
	var spore := SporeData.from_fallen_unit(unit)
	if spore == null:
		return null
	_ensure_stock()
	if not stock.can_add():
		_evict_oldest_stock_item()
	if not add_stock_item(spore):
		return null
	unit.emitted_death_spore = true
	return spore


func _stamp_stock_seq(item: Resource) -> void:
	if item == null:
		return
	item.set_meta(_STOCK_SEQ_META, _next_stock_seq)
	_next_stock_seq += 1


func _evict_oldest_stock_item() -> void:
	_ensure_stock()
	var oldest_idx := -1
	var oldest_seq := 0x7fffffff
	for i in stock.slots.size():
		var item: Resource = stock.slots[i]
		if item == null:
			continue
		var seq := 0
		if item.has_meta(_STOCK_SEQ_META):
			seq = int(item.get_meta(_STOCK_SEQ_META))
		if oldest_idx < 0 or seq < oldest_seq:
			oldest_seq = seq
			oldest_idx = i
	if oldest_idx >= 0:
		stock.clear_slot(oldest_idx)


func add_fertilizer(fertilizer: FertilizerData) -> bool:
	return add_stock_item(fertilizer)


func add_mutation(mutation: MutationData) -> bool:
	return add_stock_item(mutation)


func has_spore_in_stock() -> bool:
	return first_spore_stock_index() >= 0


func first_spore_stock_index() -> int:
	_ensure_stock()
	for i in stock.slots.size():
		if stock.slots[i] is SporeData:
			return i
	return -1


func first_empty_plot_index() -> int:
	_ensure_plot_count()
	for i in unlocked_plot_count:
		if i >= plots.size():
			break
		var plot := plots[i] as NurseryPlotData
		if plot != null and plot.is_empty():
			return i
	return -1


func generate_offer_for_slot(slot_index: int = 0) -> ShopOffer:
	if is_mutation_shop_slot(slot_index):
		return generate_mutation_offer()
	return generate_fertilizer_offer()


func generate_fertilizer_offer() -> ShopOffer:
	var path := _FERTILIZER_PATHS[randi() % _FERTILIZER_PATHS.size()]
	var fertilizer := load(path) as FertilizerData
	var offer := ShopOffer.new()
	offer.item = fertilizer
	offer.cost = fertilizer.biomass_cost if fertilizer != null else 2
	offer.locked = false
	return offer


## Each Mutation slot rolls body or cap independently, then picks from that pool.
func generate_mutation_offer() -> ShopOffer:
	var use_body := randf() < 0.5
	var paths := _BODY_MUTATION_PATHS if use_body else _CAP_MUTATION_PATHS
	var path := paths[randi() % paths.size()]
	var mutation := load(path) as MutationData
	var offer := ShopOffer.new()
	offer.item = mutation
	offer.cost = MutationData.BIOMASS_COST
	if mutation != null:
		offer.cost = mutation.biomass_cost
	offer.locked = false
	return offer


func _ensure_spore_shop() -> void:
	if spore_shop == null:
		spore_shop = ShopInventory.new()
	spore_shop.slot_count = SHOP_SLOT_COUNT


func plant(plot_index: int, stock_index: int = -1) -> bool:
	_ensure_stock()
	if plot_index < 0 or plot_index >= plots.size():
		return false
	if stock_index < 0:
		stock_index = first_spore_stock_index()
	var spore := stock.get_at(stock_index) as SporeData
	if spore == null:
		return false
	if not plant_spore(plot_index, spore):
		return false
	stock.clear_slot(stock_index)
	return true


## Common Spore template for pay-on-plot planting (duplicated so plots don't share .tres).
func make_fresh_common_spore() -> SporeData:
	var template := load(_COMMON_SPORE_PATH) as SporeData
	if template == null:
		return null
	return template.duplicate(true) as SporeData


func can_plant_on_plot(plot_index: int) -> bool:
	if not is_plot_unlocked(plot_index):
		return false
	if plot_index >= plots.size():
		return false
	var plot := plots[plot_index] as NurseryPlotData
	return plot != null and plot.is_empty()


func plant_spore(plot_index: int, spore: SporeData) -> bool:
	if spore == null:
		return false
	if not can_plant_on_plot(plot_index):
		return false
	var plot := plots[plot_index] as NurseryPlotData
	plot.planted_spore = spore
	# Inherited spore mutations stay on planted_spore — do not seed plot slots, so the
	# plot apply chip stays empty and the player can still apply one mutation this grow.
	plot.begin_planted_grow()
	return true


func apply_fertilizer_from_stock(plot_index: int, stock_index: int) -> bool:
	_ensure_stock()
	var fertilizer := stock.get_at(stock_index) as FertilizerData
	if fertilizer == null:
		return false
	if not apply_fertilizer_to_plot(plot_index, fertilizer):
		return false
	stock.clear_slot(stock_index)
	return true


func apply_fertilizer_to_plot(plot_index: int, fertilizer: FertilizerData) -> bool:
	if not is_plot_unlocked(plot_index):
		return false
	if plot_index >= plots.size():
		return false
	if fertilizer == null:
		return false
	var plot := plots[plot_index] as NurseryPlotData
	if plot == null:
		return false
	return plot.apply_fertilizer(fertilizer)


func apply_mutation_from_stock(plot_index: int, stock_index: int) -> bool:
	_ensure_stock()
	var mutation := stock.get_at(stock_index) as MutationData
	if mutation == null:
		return false
	if not apply_mutation_to_plot(plot_index, mutation):
		return false
	stock.clear_slot(stock_index)
	return true


func apply_mutation_to_plot(plot_index: int, mutation: MutationData) -> bool:
	if not is_plot_unlocked(plot_index):
		return false
	if plot_index >= plots.size():
		return false
	if mutation == null:
		return false
	var plot := plots[plot_index] as NurseryPlotData
	if plot == null:
		return false
	return plot.apply_mutation(mutation)


func apply_greenhouse_remaining_cut(days: int) -> void:
	if days <= 0:
		return
	_ensure_plot_count()
	for i in unlocked_plot_count:
		if i >= plots.size():
			break
		var plot := plots[i] as NurseryPlotData
		if plot != null:
			plot.apply_greenhouse_remaining_cut(days)


func advance_day() -> Array[Dictionary]:
	var matured: Array[Dictionary] = []
	for i in unlocked_plot_count:
		if i >= plots.size():
			break
		var plot := plots[i] as NurseryPlotData
		if plot == null or plot.planted_spore == null:
			continue
		var was_ready := plot.get_state() == NurseryPlotData.State.READY
		plot.tick_day()
		if not was_ready and plot.get_state() == NurseryPlotData.State.READY:
			matured.append({
				"plot_index": i,
				"spore_name": plot.planted_spore.display_name,
				"tint": plot.planted_spore.tint,
				"as_imago": false,
			})
	return matured


## Harvests a READY plot into zero or more roster units (overflow handled by caller).
func harvest(plot_index: int) -> Array[RosterUnitData]:
	var result: Array[RosterUnitData] = []
	if not is_plot_unlocked(plot_index):
		return result
	if plot_index >= plots.size():
		return result
	var plot := plots[plot_index] as NurseryPlotData
	if plot == null or not plot.can_harvest():
		return result
	var pending := plot.consume_pending_stat_bonus()
	var body: MutationData = plot.body_mutation
	var cap: MutationData = plot.cap_mutation
	var spore := plot.planted_spore
	if spore != null:
		if body == null:
			body = spore.body_mutation
		if cap == null:
			cap = spore.cap_mutation
	result = _make_harvest_units(
		spore,
		plot.stack_fertilizers(),
		pending,
		body,
		cap
	)
	_apply_favourite_child_if_first_hatch(result)
	plot.clear()
	return result


func _apply_favourite_child_if_first_hatch(units: Array[RosterUnitData]) -> void:
	if units.is_empty():
		return
	if not SealModifiers.favourite_child_owned():
		return
	if GameState.favourite_child_used_today:
		return
	GameState.favourite_child_used_today = true
	for unit in units:
		if unit != null:
			unit.favourite_child_buff = true


func _make_harvest_units(
	spore: SporeData,
	fertilizers: Array[FertilizerData],
	pending_stat_bonus: int,
	body_mutation: MutationData = null,
	cap_mutation: MutationData = null
) -> Array[RosterUnitData]:
	var units: Array[RosterUnitData] = []
	var weapon := WeaponSchool.sickle()
	var tier := UnitStatsData.PowerTier.COMMON
	if spore != null:
		tier = spore.power_tier
	var lineage := spore != null and spore.is_lineage_spore()
	var stats: UnitStatsData
	if lineage:
		stats = UnitStatsData.create_around(spore.mean_stats)
	else:
		stats = UnitStatsData.create_for_tier(tier)
	_apply_fertilizer_stats(stats, fertilizers)
	if pending_stat_bonus != 0:
		stats.strength = clampi(stats.strength + pending_stat_bonus, 1, 99)
		stats.dex = clampi(stats.dex + pending_stat_bonus, 1, 99)
		stats.con = clampi(stats.con + pending_stat_bonus, 1, 99)
		stats.spd = clampi(stats.spd + pending_stat_bonus, 1, 99)
	if body_mutation != null:
		body_mutation.apply_hatch_stats(stats)
	if cap_mutation != null:
		cap_mutation.apply_hatch_stats(stats)

	var yield_count := 1
	var meiosis := false
	var triploid := false
	var force_amok := false
	var training_amnesia := false
	var cocooning := false
	var stimulants := false
	var late_bloomer := false
	var volatile := false
	for fert in fertilizers:
		if fert == null:
			continue
		match fert.behavior:
			FertilizerData.Behavior.MEIOSIS:
				meiosis = true
			FertilizerData.Behavior.TRIPLOID:
				triploid = true
			FertilizerData.Behavior.AMOK:
				force_amok = true
			FertilizerData.Behavior.TRAINING_AMNESIA:
				training_amnesia = true
			FertilizerData.Behavior.COCOONING:
				cocooning = true
			FertilizerData.Behavior.STIMULANTS:
				stimulants = true
			FertilizerData.Behavior.LATE_BLOOMER:
				late_bloomer = true
			FertilizerData.Behavior.VOLATILE:
				volatile = true
	if meiosis:
		yield_count *= 2
	if triploid:
		yield_count *= 3

	for i in yield_count:
		var unit_stats := stats.duplicate(true) as UnitStatsData
		if meiosis:
			unit_stats.strength = maxi(1, roundi(float(unit_stats.strength) * 0.5))
			unit_stats.dex = maxi(1, roundi(float(unit_stats.dex) * 0.5))
			unit_stats.con = maxi(1, roundi(float(unit_stats.con) * 0.5))
			unit_stats.spd = maxi(1, roundi(float(unit_stats.spd) * 0.5))
		if triploid:
			unit_stats.strength = maxi(1, roundi(float(unit_stats.strength) / 3.0))
			unit_stats.dex = maxi(1, roundi(float(unit_stats.dex) / 3.0))
			unit_stats.con = maxi(1, roundi(float(unit_stats.con) / 3.0))
			unit_stats.spd = maxi(1, roundi(float(unit_stats.spd) / 3.0))
		var hatch_name := UnitNames.pick()
		var hatch_generation := 1
		var hatch_lineage := hatch_name
		if lineage:
			hatch_lineage = spore.lineage_name
			hatch_generation = maxi(spore.parent_generation, 1) + 1
			hatch_name = UnitNames.format_unit_name(hatch_lineage, hatch_generation)
		var unit := RosterUnitData.create(
			hatch_name,
			unit_stats,
			weapon,
			tier
		)
		unit.lineage_name = hatch_lineage
		unit.generation = hatch_generation
		unit.display_name = hatch_name
		unit.body_mutation = (
			body_mutation.duplicate(true) as MutationData if body_mutation != null else null
		)
		unit.cap_mutation = (
			cap_mutation.duplicate(true) as MutationData if cap_mutation != null else null
		)
		if lineage and not training_amnesia:
			unit.weapon_trainings = []
			for training in spore.weapon_trainings:
				unit.weapon_trainings.append(int(training))
		else:
			unit.weapon_trainings = []
		unit.sync_weapon_from_trainings()
		if force_amok:
			unit.forced_engagement_stance = WeaponData.EngagementStance.PRESS_FORWARD
		if stimulants:
			unit.daily_stat_decay = 1
		if late_bloomer:
			unit.pending_adult_stat_bonus = 7
		if cocooning:
			unit.pupation_stat_multiplier = 2
		if volatile:
			unit.volatile = true
		unit.applied_fertilizers = _copy_display_fertilizers(fertilizers)
		unit.cocoon_duration_days = _baked_cocoon_duration(cocooning)
		unit.call_lifecycle_effect(&"on_hatch", [unit])
		units.append(unit)
	return units


func _copy_display_fertilizers(fertilizers: Array[FertilizerData]) -> Array[FertilizerData]:
	var copied: Array[FertilizerData] = []
	for fert in fertilizers:
		if fert == null or fert.behavior == FertilizerData.Behavior.FUNGICIDE:
			continue
		copied.append(fert)
	return copied


func _baked_cocoon_duration(cocooning: bool) -> int:
	if cocooning:
		return 2
	return WeaponSchool.COCOON_DURATION_DAYS


func _apply_fertilizer_stats(stats: UnitStatsData, fertilizers: Array[FertilizerData]) -> void:
	if stats == null:
		return
	for fert in fertilizers:
		if fert == null:
			continue
		if fert.is_stat_source():
			fert.apply_to(stats)


func _ensure_plot_count() -> void:
	unlocked_plot_count = clampi(unlocked_plot_count, STARTING_UNLOCKED_PLOTS, MAX_PLOT_COUNT)
	while plots.size() < MAX_PLOT_COUNT:
		plots.append(NurseryPlotData.new())
	if plots.size() > MAX_PLOT_COUNT:
		plots.resize(MAX_PLOT_COUNT)
	for i in plots.size():
		if plots[i] == null:
			plots[i] = NurseryPlotData.new()


func _ensure_stock() -> void:
	if stock == null:
		stock = StockInventory.new()
	stock.slot_count = STOCK_SLOT_COUNT
	stock.ensure_size()
