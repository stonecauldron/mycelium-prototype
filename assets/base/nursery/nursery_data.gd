class_name NurseryData
extends Resource

const PLOT_COUNT := 4
const STARTER_SPORE_COUNT := 0
const _COMMON_SPORE_PATH := "res://assets/base/nursery/common_spore.tres"
const _MELEE_WEAPON_PATH := "res://assets/weapons/basic_melee.tres"

@export var plots: Array = []
@export var spore_stock: Array[SporeData] = []

var _seeded: bool = false


func _init() -> void:
	_ensure_plot_count()


func is_seeded() -> bool:
	return _seeded


func seed_if_empty() -> void:
	if _seeded:
		return
	_ensure_plot_count()
	spore_stock.clear()
	var common_spore := load(_COMMON_SPORE_PATH) as SporeData
	if common_spore != null:
		for _i in STARTER_SPORE_COUNT:
			spore_stock.append(common_spore)
	_seeded = true


func reset() -> void:
	plots.clear()
	spore_stock.clear()
	_seeded = false
	_ensure_plot_count()


func plant(plot_index: int, stock_index: int = 0) -> bool:
	if plot_index < 0 or plot_index >= plots.size():
		return false
	if stock_index < 0 or stock_index >= spore_stock.size():
		return false
	var plot := plots[plot_index] as NurseryPlotData
	if plot == null or not plot.is_empty():
		return false
	var spore := spore_stock[stock_index] as SporeData
	if spore == null:
		return false
	spore_stock.remove_at(stock_index)
	plot.planted_spore = spore
	plot.days_grown = 0
	return true


func advance_day() -> Array[Dictionary]:
	var matured: Array[Dictionary] = []
	for i in plots.size():
		var plot := plots[i] as NurseryPlotData
		if plot == null or plot.planted_spore == null:
			continue
		if plot.get_state() != NurseryPlotData.State.GROWING:
			continue
		plot.days_grown += 1
		if plot.get_state() != NurseryPlotData.State.READY:
			continue
		matured.append({
			"plot_index": i,
			"spore_name": plot.planted_spore.display_name,
		})
	return matured


func harvest(plot_index: int) -> RosterUnitData:
	if plot_index < 0 or plot_index >= plots.size():
		return null
	var plot := plots[plot_index] as NurseryPlotData
	if plot == null or not plot.can_harvest():
		return null
	var unit := _make_harvest_unit()
	plot.clear()
	return unit


func _make_harvest_unit() -> RosterUnitData:
	var weapon := load(_MELEE_WEAPON_PATH) as WeaponData
	var stats := UnitStatsData.create_for_tier(UnitStatsData.PowerTier.AVERAGE)
	return RosterUnitData.create(UnitNames.pick(), stats, weapon)


func _ensure_plot_count() -> void:
	while plots.size() < PLOT_COUNT:
		plots.append(NurseryPlotData.new())
	if plots.size() > PLOT_COUNT:
		plots.resize(PLOT_COUNT)
	for i in plots.size():
		if plots[i] == null:
			plots[i] = NurseryPlotData.new()
