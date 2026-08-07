class_name NurseryData
extends Resource

const MAX_PLOT_COUNT := 9
const STARTING_UNLOCKED_PLOTS := 1
const SHOP_SLOT_COUNT := 4
const STOCK_SLOT_COUNT := 5
const STARTER_SPORE_COUNT := 0
## Slots 0..(SPORE_SHOP_SLOT_COUNT-1) are spores; the rest are fertilizers.
const SPORE_SHOP_SLOT_COUNT := 2
const _COMMON_SPORE_PATH := "res://assets/base/nursery/common_spore.tres"
const _UNCOMMON_SPORE_PATH := "res://assets/base/nursery/uncommon_spore.tres"
const _RARE_SPORE_PATH := "res://assets/base/nursery/rare_spore.tres"
const _EPIC_SPORE_PATH := "res://assets/base/nursery/epic_spore.tres"
const _LEGENDARY_SPORE_PATH := "res://assets/base/nursery/legendary_spore.tres"
## Rarity-tier spores are all Generalist at different power tiers.
const _SPORE_SHOP_PATHS: Array[String] = [
	_COMMON_SPORE_PATH,
	_UNCOMMON_SPORE_PATH,
	_RARE_SPORE_PATH,
	_EPIC_SPORE_PATH,
	_LEGENDARY_SPORE_PATH,
]
## Named specialty strains (not Generalist — that comes from rarity rolls above).
const _STRAIN_SPORE_PATHS: Array[String] = [
	"res://assets/base/nursery/spores/death_cap_spore.tres",
	"res://assets/base/nursery/spores/inky_cap_spore.tres",
	"res://assets/base/nursery/spores/boom_cap_spore.tres",
	"res://assets/base/nursery/spores/mini_cap_spore.tres",
	"res://assets/base/nursery/spores/lanky_cap_spore.tres",
	"res://assets/base/nursery/spores/fat_cap_spore.tres",
	"res://assets/base/nursery/spores/wall_cap_spore.tres",
	"res://assets/base/nursery/spores/bank_cap_spore.tres",
	"res://assets/base/nursery/spores/zombie_cap_spore.tres",
	"res://assets/base/nursery/spores/rubber_cap_spore.tres",
	"res://assets/base/nursery/spores/brood_empress_spore.tres",
]
const _STRAIN_SPORE_OFFER_CHANCE := 0.5
const _FERTILIZER_PATHS: Array[String] = [
	"res://assets/base/nursery/fertilizers/reinforced_chitin.tres",
	"res://assets/base/nursery/fertilizers/brute_force.tres",
	"res://assets/base/nursery/fertilizers/hollow_chitin.tres",
	"res://assets/base/nursery/fertilizers/finesse.tres",
	"res://assets/base/nursery/fertilizers/stress_induced_growth.tres",
	"res://assets/base/nursery/fertilizers/slow_and_steady.tres",
	"res://assets/base/nursery/fertilizers/fast_metabolism.tres",
	"res://assets/base/nursery/fertilizers/slow_metabolism.tres",
	"res://assets/base/nursery/fertilizers/meiosis.tres",
	"res://assets/base/nursery/fertilizers/triploid_cells.tres",
	"res://assets/base/nursery/fertilizers/fungicide.tres",
	"res://assets/base/nursery/fertilizers/amok.tres",
	"res://assets/base/nursery/fertilizers/training_amnesia.tres",
	"res://assets/base/nursery/fertilizers/cocooning.tres",
	"res://assets/base/nursery/fertilizers/stimulants.tres",
	"res://assets/base/nursery/fertilizers/late_bloomer.tres",
]

@export var plots: Array = []
## Shared nursery inventory: SporeData and FertilizerData entries.
@export var stock: StockInventory
## Nursery shop state (offers + locks). Shared ShopInventory used by any shop screen.
@export var spore_shop: ShopInventory
@export var unlocked_plot_count: int = STARTING_UNLOCKED_PLOTS
## Paid shop reroll cost for this day; doubles after each successful paid reroll.
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
	if GameState.debug_mode_active:
		return BiomassData.SHOP_REROLL_COST
	return shop_reroll_cost


func advance_shop_reroll_cost() -> void:
	if GameState.debug_mode_active:
		return
	shop_reroll_cost *= 2


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


func reroll_unlocked_shop_offers() -> void:
	_ensure_spore_shop()
	spore_shop.reroll_unlocked(generate_offer_for_slot)


## Day-start only: guarantee a Common Generalist among spore slots on day 2.
func apply_day_start_shop_rules() -> void:
	_ensure_day_two_common_generalist()
	refresh_spore_offer_costs()


## Recompute shop spore costs from current seals (e.g. Rotten Thumb).
func refresh_spore_offer_costs() -> void:
	_ensure_spore_shop()
	for offer in spore_shop.offers:
		if offer == null or offer.item == null:
			continue
		var spore := offer.item as SporeData
		if spore == null:
			continue
		offer.cost = SealModifiers.spore_shop_cost(spore.biomass_cost)


func replace_shop_slot(slot_index: int) -> void:
	_ensure_spore_shop()
	spore_shop.replace_slot(slot_index)


func can_add_stock_item() -> bool:
	_ensure_stock()
	return stock.can_add()


func add_stock_item(item: Resource) -> bool:
	return add_stock_item_at(item, -1) >= 0


## Places item in first empty slot (or `slot_index` if >= 0). Returns slot index, or -1.
func add_stock_item_at(item: Resource, slot_index: int = -1) -> int:
	_ensure_stock()
	if item == null or not (item is SporeData or item is FertilizerData):
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
	if is_fertilizer_shop_slot(slot_index):
		return generate_fertilizer_offer()
	return generate_spore_offer()


func is_fertilizer_shop_slot(slot_index: int) -> bool:
	return slot_index >= SPORE_SHOP_SLOT_COUNT


func generate_spore_offer(_slot_index: int = 0) -> ShopOffer:
	var path := _pick_spore_shop_path()
	return _make_spore_offer_from_path(path)


## Day 2 (upcoming day == 2): keep at least one Common Generalist among spore slots.
func _ensure_day_two_common_generalist() -> void:
	if GameState.get_upcoming_day() != 2:
		return
	_ensure_spore_shop()
	if _shop_has_common_generalist():
		return
	var target := _first_replaceable_spore_slot()
	if target < 0:
		target = 0
	while spore_shop.offers.size() <= target:
		spore_shop.offers.append(null)
	spore_shop.offers[target] = _make_spore_offer_from_path(_COMMON_SPORE_PATH)


func is_common_generalist_spore(spore: SporeData) -> bool:
	if spore == null:
		return false
	if not spore.resource_path.is_empty():
		return spore.resource_path == _COMMON_SPORE_PATH
	if spore.power_tier != UnitStatsData.PowerTier.COMMON:
		return false
	var strain := spore.resolved_strain()
	return strain != null and strain.resource_path == "res://assets/units/generalist/generalist_strain.tres"


func _shop_has_common_generalist() -> bool:
	for i in SPORE_SHOP_SLOT_COUNT:
		if i >= spore_shop.offers.size():
			break
		var offer := spore_shop.offers[i]
		if offer == null or offer.is_empty():
			continue
		if is_common_generalist_spore(offer.item as SporeData):
			return true
	return false


func _first_replaceable_spore_slot() -> int:
	for i in SPORE_SHOP_SLOT_COUNT:
		if i >= spore_shop.offers.size():
			return i
		var offer := spore_shop.offers[i]
		if offer == null or offer.is_empty() or not offer.locked:
			return i
	return -1


func _make_spore_offer_from_path(path: String) -> ShopOffer:
	var spore := load(path) as SporeData
	var offer := ShopOffer.new()
	offer.item = spore
	var base_cost := spore.biomass_cost if spore != null else BiomassData.COMMON_SPORE_COST
	offer.cost = SealModifiers.spore_shop_cost(base_cost)
	offer.locked = false
	return offer


func _pick_spore_shop_path() -> String:
	if not _STRAIN_SPORE_PATHS.is_empty() and randf() < _STRAIN_SPORE_OFFER_CHANCE:
		return _STRAIN_SPORE_PATHS[randi() % _STRAIN_SPORE_PATHS.size()]
	return _pick_weighted_spore_path()


func _pick_weighted_spore_path() -> String:
	var weights := BiomassData.SPORE_SHOP_WEIGHTS
	var total := 0.0
	for i in mini(weights.size(), _SPORE_SHOP_PATHS.size()):
		total += maxf(weights[i], 0.0)
	if total <= 0.0:
		return _COMMON_SPORE_PATH
	var roll := randf() * total
	var cumulative := 0.0
	for i in mini(weights.size(), _SPORE_SHOP_PATHS.size()):
		cumulative += maxf(weights[i], 0.0)
		if roll < cumulative:
			return _SPORE_SHOP_PATHS[i]
	return _SPORE_SHOP_PATHS[0]


func generate_fertilizer_offer() -> ShopOffer:
	var path := _FERTILIZER_PATHS[randi() % _FERTILIZER_PATHS.size()]
	var fertilizer := load(path) as FertilizerData
	var offer := ShopOffer.new()
	offer.item = fertilizer
	offer.cost = fertilizer.biomass_cost if fertilizer != null else 2
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


func plant_spore(plot_index: int, spore: SporeData) -> bool:
	if not is_plot_unlocked(plot_index):
		return false
	if plot_index >= plots.size():
		return false
	if spore == null:
		return false
	var plot := plots[plot_index] as NurseryPlotData
	if plot == null or not plot.is_empty():
		return false
	plot.planted_spore = spore
	plot.days_grown = plot.total_growth_bonus()
	plot.snap_after_plant()
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


func advance_day() -> Array[Dictionary]:
	var matured: Array[Dictionary] = []
	for i in unlocked_plot_count:
		if i >= plots.size():
			break
		var plot := plots[i] as NurseryPlotData
		if plot == null or plot.planted_spore == null:
			continue
		var was_ready := plot.get_state() == NurseryPlotData.State.READY
		plot.days_grown += 1
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
	result = _make_harvest_units(plot.planted_spore, plot.applied_fertilizers, pending)
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
	pending_stat_bonus: int
) -> Array[RosterUnitData]:
	var units: Array[RosterUnitData] = []
	var weapon := WeaponSchool.sickle()
	var unit_strain := spore.resolved_strain() if spore != null else null
	var tier := UnitStatsData.PowerTier.COMMON
	if spore != null and (unit_strain == null or unit_strain.use_power_tier):
		tier = spore.power_tier
	var lineage := spore != null and spore.is_lineage_spore()
	if lineage:
		tier = spore.power_tier
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
	if unit_strain != null:
		unit_strain.apply_hatch_stats(stats)

	var yield_count := 1
	if unit_strain != null:
		yield_count = maxi(unit_strain.hatch_count, 1)
	var meiosis := false
	var triploid := false
	var force_amok := false
	var training_amnesia := false
	var cocooning := false
	var stimulants := false
	var late_bloomer := false
	var fast_metabolism := false
	var slow_metabolism := false
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
			FertilizerData.Behavior.FAST_METABOLISM:
				fast_metabolism = true
			FertilizerData.Behavior.SLOW_METABOLISM:
				slow_metabolism = true
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
			unit_strain,
			tier
		)
		unit.lineage_name = hatch_lineage
		unit.generation = hatch_generation
		unit.display_name = hatch_name
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
			unit.pending_adult_stat_bonus = 6
		if cocooning:
			unit.pupation_stat_multiplier = 2
		unit.applied_fertilizers = _copy_display_fertilizers(fertilizers)
		unit.cocoon_duration_days = _baked_cocoon_duration(cocooning, fast_metabolism, slow_metabolism)
		if unit.max_days_alive >= 0:
			if fast_metabolism:
				unit.max_days_alive = int(unit.max_days_alive / 2)
			if slow_metabolism:
				unit.max_days_alive = unit.max_days_alive * 2
		if unit_strain != null:
			unit_strain.call_effect(&"on_hatch", [unit])
		units.append(unit)
	return units


func _copy_display_fertilizers(fertilizers: Array[FertilizerData]) -> Array[FertilizerData]:
	var copied: Array[FertilizerData] = []
	for fert in fertilizers:
		if fert == null or fert.behavior == FertilizerData.Behavior.FUNGICIDE:
			continue
		copied.append(fert)
	return copied


func _baked_cocoon_duration(cocooning: bool, fast_metabolism: bool, slow_metabolism: bool) -> int:
	var days := WeaponSchool.COCOON_DURATION_DAYS
	if cocooning:
		days = 2
	if slow_metabolism:
		days *= 2
	if fast_metabolism:
		days = int(days / 2)
	return days


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
