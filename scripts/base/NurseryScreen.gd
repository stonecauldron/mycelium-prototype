class_name NurseryScreen
extends BaseScreen

const _PLOT_TILE_SCENE := preload("res://scenes/base/PlotTile.tscn")
const _SPORE_CARD_SCENE := preload("res://scenes/base/SporeCard.tscn")

@onready var _stock_label: Label = %StockLabel
@onready var _stock_row: HBoxContainer = %StockRow
@onready var _plot_row: HBoxContainer = %PlotRow
@onready var _status_label: Label = %StatusLabel
@onready var _buy_spore_button: Button = %BuySporeButton

var _tiles: Array[PlotTile] = []


func _ready() -> void:
	_buy_spore_button.pressed.connect(_on_buy_spore_pressed)
	_build_plot_tiles()
	_hydrate_and_refresh()


func on_screen_shown() -> void:
	_hydrate_and_refresh()


func _hydrate_and_refresh() -> void:
	GameState.ensure_nursery_seeded()
	_refresh()


func _build_plot_tiles() -> void:
	for child in _plot_row.get_children():
		child.queue_free()
	_tiles.clear()
	for i in NurseryData.PLOT_COUNT:
		var tile: PlotTile = _PLOT_TILE_SCENE.instantiate()
		_plot_row.add_child(tile)
		tile.plot_pressed.connect(_on_plot_pressed)
		tile.spore_dropped.connect(_on_spore_dropped)
		_tiles.append(tile)


func _refresh() -> void:
	var nursery := GameState.nursery
	var can_plant := not nursery.spore_stock.is_empty()
	_stock_label.text = "Spores in stock: %d" % nursery.spore_stock.size()
	_buy_spore_button.text = "Buy Common Spore (%d)" % BiomassData.COMMON_SPORE_COST
	_buy_spore_button.disabled = not GameState.biomass.can_afford(BiomassData.COMMON_SPORE_COST)
	_rebuild_stock_cards()
	for i in _tiles.size():
		var plot := nursery.plots[i] as NurseryPlotData if i < nursery.plots.size() else null
		_tiles[i].setup(i, plot, can_plant)


func _on_buy_spore_pressed() -> void:
	if GameState.try_buy_common_spore():
		_set_status("Bought Common Spore")
		_refresh()
		var base := get_tree().current_scene
		if base != null and base.has_method("_refresh_hud"):
			base._refresh_hud()
	else:
		_set_status("Not enough biomass")


func _rebuild_stock_cards() -> void:
	for child in _stock_row.get_children():
		child.queue_free()
	var stock := GameState.nursery.spore_stock
	for i in stock.size():
		var spore := stock[i] as SporeData
		if spore == null:
			continue
		var card: SporeCard = _SPORE_CARD_SCENE.instantiate()
		_stock_row.add_child(card)
		card.setup(spore, i)


func _on_plot_pressed(tile: PlotTile) -> void:
	var nursery := GameState.nursery
	if tile.plot_index < 0 or tile.plot_index >= nursery.plots.size():
		return
	var plot := nursery.plots[tile.plot_index] as NurseryPlotData
	if plot == null:
		return

	match plot.get_state():
		NurseryPlotData.State.EMPTY:
			if nursery.spore_stock.is_empty():
				_set_status("No spores left")
				return
			if nursery.plant(tile.plot_index):
				_set_status("Planted spore in plot %d" % (tile.plot_index + 1))
				_refresh()
			else:
				_set_status("Could not plant")
		NurseryPlotData.State.GROWING:
			_set_status("Still growing")
		NurseryPlotData.State.READY:
			var unit := nursery.harvest(tile.plot_index)
			if unit == null:
				_set_status("Could not harvest")
				return
			if not GameState.troop.is_seeded():
				var empty_bench: Array[RosterUnitData] = []
				GameState.troop.seed_if_empty(empty_bench)
			GameState.troop.bench.append(unit)
			GameState.troop.sort_bench()
			_set_status("Harvested %s → bench" % unit.display_name)
			_refresh()


func _on_spore_dropped(tile: PlotTile, stock_index: int) -> void:
	var nursery := GameState.nursery
	if nursery.plant(tile.plot_index, stock_index):
		_set_status("Planted spore in plot %d" % (tile.plot_index + 1))
		_refresh()
	else:
		_set_status("Could not plant")


func _set_status(text: String) -> void:
	_status_label.text = text
