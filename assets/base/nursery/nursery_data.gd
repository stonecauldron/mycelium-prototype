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
	"res://assets/base/nursery/spores/magi_cap_spore.tres",
	"res://assets/base/nursery/spores/chad_cap_spore.tres",
	"res://assets/base/nursery/spores/rush_cap_spore.tres",
	"res://assets/base/nursery/spores/wall_cap_spore.tres",
	"res://assets/base/nursery/spores/bank_cap_spore.tres",
	"res://assets/base/nursery/spores/zombie_cap_spore.tres",
	"res://assets/base/nursery/spores/rubber_cap_spore.tres",
]
const _STRAIN_SPORE_OFFER_CHANCE := 0.5
const _FERTILIZER_PATHS: Array[String] = [
	"res://assets/base/nursery/fertilizers/reinforced_chitin.tres",
	"res://assets/base/nursery/fertilizers/brute_force.tres",
	"res://assets/base/nursery/fertilizers/feather_weight.tres",
	"res://assets/base/nursery/fertilizers/finesse.tres",
	"res://assets/base/nursery/fertilizers/quick_growth.tres",
	"res://assets/base/nursery/fertilizers/stress_induced_growth.tres",
	"res://assets/base/nursery/fertilizers/volatile.tres",
	"res://assets/base/nursery/fertilizers/overkill.tres",
	"res://assets/base/nursery/fertilizers/meiosis.tres",
	"res://assets/base/nursery/fertilizers/slow_and_steady.tres",
	"res://assets/base/nursery/fertilizers/fungicide.tres",
	"res://assets/base/nursery/fertilizers/amok.tres",
]

@export var plots: Array = []
## Shared nursery inventory: SporeData and FertilizerData entries.
@export var stock: StockInventory
## Nursery shop state (offers + locks). Shared ShopInventory used by any shop screen.
@export var spore_shop: ShopInventory
@export var unlocked_plot_count: int = STARTING_UNLOCKED_PLOTS

var _seeded: bool = false


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
	_ensure_plot_count()
	_ensure_stock()
	stock.clear()


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
	return stock.add(item, slot_index)


func can_add_spore() -> bool:
	return can_add_stock_item()


func add_spore(spore: SporeData) -> bool:
	return add_stock_item(spore)


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


func _shop_has_common_generalist() -> bool:
	for i in SPORE_SHOP_SLOT_COUNT:
		if i >= spore_shop.offers.size():
			break
		var offer := spore_shop.offers[i]
		if offer == null or offer.is_empty():
			continue
		if _is_common_generalist_spore(offer.item as SporeData):
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


func _is_common_generalist_spore(spore: SporeData) -> bool:
	if spore == null:
		return false
	if not spore.resource_path.is_empty():
		return spore.resource_path == _COMMON_SPORE_PATH
	if spore.power_tier != UnitStatsData.PowerTier.COMMON:
		return false
	var strain := spore.resolved_strain()
	return strain != null and strain.resource_path == "res://assets/units/generalist/generalist_strain.tres"


func _make_spore_offer_from_path(path: String) -> ShopOffer:
	var spore := load(path) as SporeData
	var offer := ShopOffer.new()
	offer.item = spore
	offer.cost = spore.biomass_cost if spore != null else BiomassData.COMMON_SPORE_COST
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
	var as_imago := plot.will_harvest_as_imago()
	var pending := plot.consume_pending_stat_bonus()
	result = _make_harvest_units(plot.planted_spore, plot.applied_fertilizers, pending)
	if as_imago:
		for unit in result:
			if unit != null:
				unit.promote_to_imago()
	plot.clear()
	return result


func _make_harvest_units(
	spore: SporeData,
	fertilizers: Array[FertilizerData],
	pending_stat_bonus: int
) -> Array[RosterUnitData]:
	var units: Array[RosterUnitData] = []
	var weapon := RiboforgeData.get_default_weapon()
	var unit_strain := spore.resolved_strain() if spore != null else null
	var tier := UnitStatsData.PowerTier.COMMON
	if spore != null and (unit_strain == null or unit_strain.use_power_tier):
		tier = spore.power_tier
	var stats := UnitStatsData.create_for_tier(tier)
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
	for fert in fertilizers:
		if fert != null and fert.behavior == FertilizerData.Behavior.MEIOSIS:
			yield_count = maxi(yield_count, 2)
			break

	var force_amok := false
	for fert in fertilizers:
		if fert != null and fert.behavior == FertilizerData.Behavior.AMOK:
			force_amok = true
			break

	var meiosis := false
	for fert in fertilizers:
		if fert != null and fert.behavior == FertilizerData.Behavior.MEIOSIS:
			meiosis = true
			break

	for i in yield_count:
		var unit_stats := stats.duplicate(true) as UnitStatsData
		if meiosis:
			unit_stats.strength = maxi(1, roundi(float(unit_stats.strength) * 0.5))
			unit_stats.dex = maxi(1, roundi(float(unit_stats.dex) * 0.5))
			unit_stats.con = maxi(1, roundi(float(unit_stats.con) * 0.5))
			unit_stats.spd = maxi(1, roundi(float(unit_stats.spd) * 0.5))
		var unit := RosterUnitData.create(
			UnitNames.pick(),
			unit_stats,
			weapon,
			unit_strain,
			tier
		)
		if force_amok:
			unit.forced_engagement_stance = WeaponData.EngagementStance.PRESS_FORWARD
		if unit_strain != null:
			unit_strain.call_effect(&"on_hatch", [unit])
		units.append(unit)
	return units


func _apply_fertilizer_stats(stats: UnitStatsData, fertilizers: Array[FertilizerData]) -> void:
	if stats == null:
		return
	var volatile_count := 0
	for fert in fertilizers:
		if fert != null and fert.behavior == FertilizerData.Behavior.VOLATILE:
			volatile_count += 1
	var scale_factor := 1
	if volatile_count > 0:
		scale_factor = int(pow(2.0, float(volatile_count)))
	for fert in fertilizers:
		if fert == null:
			continue
		if fert.is_stat_source():
			fert.apply_to(stats, scale_factor)
	for fert in fertilizers:
		if fert != null and fert.behavior == FertilizerData.Behavior.OVERKILL:
			_apply_overkill(stats)
			break


func _apply_overkill(stats: UnitStatsData) -> void:
	if stats == null:
		return
	var values: Array[int] = [stats.strength, stats.dex, stats.con, stats.spd]
	var highest: int = values[0]
	var lowest: int = values[0]
	for v in values:
		highest = maxi(highest, v)
		lowest = mini(lowest, v)
	var high_idxs: Array[int] = []
	var low_idxs: Array[int] = []
	for i in values.size():
		if values[i] == highest:
			high_idxs.append(i)
		if values[i] == lowest:
			low_idxs.append(i)
	var high_i: int = high_idxs[randi() % high_idxs.size()]
	var low_i: int = low_idxs[randi() % low_idxs.size()]
	# Prefer distinct stats when possible.
	if high_i == low_i and high_idxs.size() > 1:
		high_idxs.erase(high_i)
		high_i = high_idxs[randi() % high_idxs.size()]
	elif high_i == low_i and low_idxs.size() > 1:
		low_idxs.erase(low_i)
		low_i = low_idxs[randi() % low_idxs.size()]
	values[high_i] = clampi(values[high_i] + 2, 1, 99)
	values[low_i] = clampi(values[low_i] - 2, 1, 99)
	stats.strength = values[0]
	stats.dex = values[1]
	stats.con = values[2]
	stats.spd = values[3]


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
