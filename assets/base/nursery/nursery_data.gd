class_name NurseryData
extends Resource

const MAX_PLOT_COUNT := 9
const STARTING_UNLOCKED_PLOTS := 1
const SHOP_SLOT_COUNT := 3
const STOCK_SLOT_COUNT := 5
const STARTER_SPORE_COUNT := 0
const SPORE_SHOP_SLOT := 0
const _COMMON_SPORE_PATH := "res://assets/base/nursery/common_spore.tres"
const _UNCOMMON_SPORE_PATH := "res://assets/base/nursery/uncommon_spore.tres"
const _RARE_SPORE_PATH := "res://assets/base/nursery/rare_spore.tres"
const _EPIC_SPORE_PATH := "res://assets/base/nursery/epic_spore.tres"
const _LEGENDARY_SPORE_PATH := "res://assets/base/nursery/legendary_spore.tres"
const _SPORE_SHOP_PATHS: Array[String] = [
	_COMMON_SPORE_PATH,
	_UNCOMMON_SPORE_PATH,
	_RARE_SPORE_PATH,
	_EPIC_SPORE_PATH,
	_LEGENDARY_SPORE_PATH,
]
const _FERTILIZER_PATHS: Array[String] = [
	"res://assets/base/nursery/fertilizers/reinforced_chitin.tres",
	"res://assets/base/nursery/fertilizers/brute_force.tres",
	"res://assets/base/nursery/fertilizers/feather_weight.tres",
	"res://assets/base/nursery/fertilizers/finesse.tres",
	"res://assets/base/nursery/fertilizers/quick_growth.tres",
]

@export var plots: Array = []
## Shared nursery inventory: SporeData and FertilizerData entries.
@export var stock: Array[Resource] = []
## Nursery shop state (offers + locks). Shared ShopInventory used by any shop screen.
@export var spore_shop: ShopInventory
@export var unlocked_plot_count: int = STARTING_UNLOCKED_PLOTS

var _seeded: bool = false


func _init() -> void:
	unlocked_plot_count = STARTING_UNLOCKED_PLOTS
	_ensure_plot_count()
	_ensure_spore_shop()


func is_seeded() -> bool:
	return _seeded


func seed_if_empty() -> void:
	if _seeded:
		return
	_ensure_plot_count()
	_ensure_spore_shop()
	stock.clear()
	var common_spore := load(_COMMON_SPORE_PATH) as SporeData
	if common_spore != null:
		for _i in mini(STARTER_SPORE_COUNT, STOCK_SLOT_COUNT):
			stock.append(common_spore)
	spore_shop.ensure_filled(generate_offer_for_slot)
	_seeded = true


func reset() -> void:
	plots.clear()
	stock.clear()
	unlocked_plot_count = STARTING_UNLOCKED_PLOTS
	_ensure_spore_shop()
	spore_shop.clear()
	_seeded = false
	_ensure_plot_count()


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


func replace_shop_slot(slot_index: int) -> void:
	_ensure_spore_shop()
	spore_shop.replace_slot(slot_index, generate_offer_for_slot)


func can_add_stock_item() -> bool:
	return stock.size() < STOCK_SLOT_COUNT


func add_stock_item(item: Resource) -> bool:
	if item == null or not can_add_stock_item():
		return false
	if not (item is SporeData or item is FertilizerData):
		return false
	stock.append(item)
	return true


func can_add_spore() -> bool:
	return can_add_stock_item()


func add_spore(spore: SporeData) -> bool:
	return add_stock_item(spore)


func add_fertilizer(fertilizer: FertilizerData) -> bool:
	return add_stock_item(fertilizer)


func has_spore_in_stock() -> bool:
	return first_spore_stock_index() >= 0


func first_spore_stock_index() -> int:
	for i in stock.size():
		if stock[i] is SporeData:
			return i
	return -1


func generate_offer_for_slot(slot_index: int = 0) -> ShopOffer:
	if is_fertilizer_shop_slot(slot_index):
		return generate_fertilizer_offer()
	return generate_spore_offer()


func is_fertilizer_shop_slot(slot_index: int) -> bool:
	return slot_index != SPORE_SHOP_SLOT


func generate_spore_offer(_slot_index: int = 0) -> ShopOffer:
	var path := _pick_weighted_spore_path()
	var spore := load(path) as SporeData
	var offer := ShopOffer.new()
	offer.item = spore
	offer.cost = spore.biomass_cost if spore != null else BiomassData.COMMON_SPORE_COST
	offer.locked = false
	return offer


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
	offer.cost = fertilizer.biomass_cost if fertilizer != null else 6
	offer.locked = false
	return offer


func _ensure_spore_shop() -> void:
	if spore_shop == null:
		spore_shop = ShopInventory.new()
	spore_shop.slot_count = SHOP_SLOT_COUNT


func plant(plot_index: int, stock_index: int = -1) -> bool:
	if plot_index < 0 or plot_index >= plots.size():
		return false
	if stock_index < 0:
		stock_index = first_spore_stock_index()
	if stock_index < 0 or stock_index >= stock.size():
		return false
	var spore := stock[stock_index] as SporeData
	if spore == null:
		return false
	if not plant_spore(plot_index, spore):
		return false
	stock.remove_at(stock_index)
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
	if stock_index < 0 or stock_index >= stock.size():
		return false
	var fertilizer := stock[stock_index] as FertilizerData
	if fertilizer == null:
		return false
	if not apply_fertilizer_to_plot(plot_index, fertilizer):
		return false
	stock.remove_at(stock_index)
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
		plot.days_grown += 1
		if plot.days_grown == plot.planted_spore.days_to_mature:
			matured.append({
				"plot_index": i,
				"spore_name": plot.planted_spore.display_name,
			})
	return matured


func harvest(plot_index: int) -> RosterUnitData:
	if not is_plot_unlocked(plot_index):
		return null
	if plot_index >= plots.size():
		return null
	var plot := plots[plot_index] as NurseryPlotData
	if plot == null or not plot.can_harvest():
		return null
	var as_imago := plot.will_harvest_as_imago()
	var unit := _make_harvest_unit(plot.planted_spore, plot.applied_fertilizers)
	if as_imago and unit != null:
		unit.promote_to_imago()
	plot.clear()
	return unit


func _make_harvest_unit(spore: SporeData, fertilizers: Array[FertilizerData]) -> RosterUnitData:
	var weapon := RiboforgeData.get_default_weapon()
	var tier := UnitStatsData.PowerTier.COMMON
	if spore != null:
		tier = spore.power_tier
	var stats := UnitStatsData.create_for_tier(tier)
	for fertilizer in fertilizers:
		if fertilizer != null:
			fertilizer.apply_to(stats)
	return RosterUnitData.create(UnitNames.pick(), stats, weapon, null, tier)


func _ensure_plot_count() -> void:
	unlocked_plot_count = clampi(unlocked_plot_count, STARTING_UNLOCKED_PLOTS, MAX_PLOT_COUNT)
	while plots.size() < MAX_PLOT_COUNT:
		plots.append(NurseryPlotData.new())
	if plots.size() > MAX_PLOT_COUNT:
		plots.resize(MAX_PLOT_COUNT)
	for i in plots.size():
		if plots[i] == null:
			plots[i] = NurseryPlotData.new()
