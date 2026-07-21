class_name NurseryData
extends Resource

const MAX_PLOT_COUNT := 9
const STARTING_UNLOCKED_PLOTS := 1
const SHOP_SLOT_COUNT := 3
const STOCK_SLOT_COUNT := 5
const STARTER_SPORE_COUNT := 0
const _COMMON_SPORE_PATH := "res://assets/base/nursery/common_spore.tres"
const _RARE_SPORE_PATH := "res://assets/base/nursery/rare_spore.tres"

@export var plots: Array = []
@export var spore_stock: Array[SporeData] = []
## Spore shop state (offers + locks). Shared ShopInventory used by any shop screen.
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
	spore_stock.clear()
	var common_spore := load(_COMMON_SPORE_PATH) as SporeData
	if common_spore != null:
		for _i in mini(STARTER_SPORE_COUNT, STOCK_SLOT_COUNT):
			spore_stock.append(common_spore)
	spore_shop.ensure_filled(generate_spore_offer)
	_seeded = true


func reset() -> void:
	plots.clear()
	spore_stock.clear()
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
	spore_shop.ensure_filled(generate_spore_offer)


func reroll_unlocked_shop_offers() -> void:
	_ensure_spore_shop()
	spore_shop.reroll_unlocked(generate_spore_offer)


func replace_shop_slot(slot_index: int) -> void:
	_ensure_spore_shop()
	spore_shop.replace_slot(slot_index, generate_spore_offer)


func can_add_spore() -> bool:
	return spore_stock.size() < STOCK_SLOT_COUNT


func add_spore(spore: SporeData) -> bool:
	if spore == null or not can_add_spore():
		return false
	spore_stock.append(spore)
	return true


func generate_spore_offer() -> ShopOffer:
	var path := _RARE_SPORE_PATH if randf() < BiomassData.RARE_SPORE_CHANCE else _COMMON_SPORE_PATH
	var spore := load(path) as SporeData
	var offer := ShopOffer.new()
	offer.item = spore
	offer.cost = spore.biomass_cost if spore != null else BiomassData.COMMON_SPORE_COST
	offer.locked = false
	return offer


func _ensure_spore_shop() -> void:
	if spore_shop == null:
		spore_shop = ShopInventory.new()
	spore_shop.slot_count = SHOP_SLOT_COUNT


func plant(plot_index: int, stock_index: int = 0) -> bool:
	if plot_index < 0 or plot_index >= plots.size():
		return false
	if stock_index < 0 or stock_index >= spore_stock.size():
		return false
	var spore := spore_stock[stock_index] as SporeData
	if spore == null:
		return false
	if not plant_spore(plot_index, spore):
		return false
	spore_stock.remove_at(stock_index)
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
	plot.days_grown = 0
	return true


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
	var unit := _make_harvest_unit(plot.planted_spore)
	if as_imago and unit != null:
		unit.promote_to_imago()
	plot.clear()
	return unit


func _make_harvest_unit(spore: SporeData) -> RosterUnitData:
	var weapon := RiboforgeData.get_default_weapon()
	var tier := UnitStatsData.PowerTier.AVERAGE
	if spore != null:
		tier = spore.power_tier
	var stats := UnitStatsData.create_for_tier(tier)
	return RosterUnitData.create(UnitNames.pick(), stats, weapon)


func _ensure_plot_count() -> void:
	unlocked_plot_count = clampi(unlocked_plot_count, STARTING_UNLOCKED_PLOTS, MAX_PLOT_COUNT)
	while plots.size() < MAX_PLOT_COUNT:
		plots.append(NurseryPlotData.new())
	if plots.size() > MAX_PLOT_COUNT:
		plots.resize(MAX_PLOT_COUNT)
	for i in plots.size():
		if plots[i] == null:
			plots[i] = NurseryPlotData.new()
