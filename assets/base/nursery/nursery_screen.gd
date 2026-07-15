class_name NurseryScreen
extends BaseScreen

const _PLOT_TILE_SCENE := preload("res://assets/base/plot_tile/plot_tile.tscn")
const _SPORE_CARD_SCENE := preload("res://assets/base/nursery/spore_card.tscn")
const _SHOP_OFFER_CARD_SCENE := preload("res://assets/base/shop/shop_offer_card.tscn")
const _SPORE_ICON := preload("res://assets/base/nursery/spores.png")

@onready var _stock_label: Label = %StockLabel
@onready var _stock_row: HBoxContainer = %StockRow
@onready var _stock_panel: StockDropHost = %StockPanel
@onready var _plot_row: HBoxContainer = %PlotRow
@onready var _shop_column: VBoxContainer = %ShopColumn
@onready var _reroll_button: Button = %RerollButton
@onready var _reroll_cost_label: Label = %RerollCostLabel
@onready var _status_label: Label = %StatusLabel

var _tiles: Array[PlotTile] = []
var _shop_cards: Array[ShopOfferCard] = []
var _spore_icon_atlas: AtlasTexture


func _ready() -> void:
	_spore_icon_atlas = AtlasTexture.new()
	_spore_icon_atlas.atlas = _SPORE_ICON
	_spore_icon_atlas.region = Rect2(171, 166, 171, 179)
	_stock_panel.shop_spore_dropped.connect(_on_shop_spore_to_stock)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_build_plot_tiles()
	_hydrate_and_refresh()


func on_screen_shown() -> void:
	_hydrate_and_refresh()


func _hydrate_and_refresh() -> void:
	GameState.ensure_nursery_seeded()
	GameState.nursery.ensure_shop_offers()
	_build_shop_cards()
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


func _build_shop_cards() -> void:
	for child in _shop_column.get_children():
		child.queue_free()
	_shop_cards.clear()
	var shop := GameState.nursery.spore_shop
	if shop == null:
		return
	for i in shop.offers.size():
		var offer := shop.offers[i]
		if offer == null:
			continue
		var spore := offer.item as SporeData
		if spore == null:
			continue
		var card: ShopOfferCard = _SHOP_OFFER_CARD_SCENE.instantiate()
		_shop_column.add_child(card)
		card.setup(
			spore.display_name,
			"growth: %d days" % spore.days_to_mature,
			offer.cost,
			{
				"type": "shop_spore",
				"spore": spore,
				"cost": offer.cost,
				"slot_index": i,
			},
			_spore_icon_atlas,
			i,
			offer.locked,
			spore.tint
		)
		card.offer_clicked.connect(_on_shop_offer_clicked)
		card.lock_toggled.connect(_on_shop_lock_toggled)
		_shop_cards.append(card)


func _refresh() -> void:
	var nursery := GameState.nursery
	var can_plant := not nursery.spore_stock.is_empty()
	_stock_label.text = "Spores in stock: %d" % nursery.spore_stock.size()
	_rebuild_stock_cards()
	_refresh_shop_affordability()
	for i in _tiles.size():
		var plot := nursery.plots[i] as NurseryPlotData if i < nursery.plots.size() else null
		_tiles[i].setup(i, plot, can_plant)


func _refresh_shop_affordability() -> void:
	for card in _shop_cards:
		card.set_affordable(GameState.biomass.can_afford(card.cost))
	_reroll_cost_label.text = "%d" % BiomassData.SHOP_REROLL_COST
	_reroll_button.disabled = not GameState.biomass.can_afford(BiomassData.SHOP_REROLL_COST)


func _on_reroll_pressed() -> void:
	if not GameState.biomass.try_spend(BiomassData.SHOP_REROLL_COST):
		_set_status("Not enough biomass")
		return
	GameState.nursery.reroll_unlocked_shop_offers()
	_build_shop_cards()
	_refresh_shop_affordability()
	_refresh_base_hud()
	_set_status("Shop rerolled")


func _on_shop_lock_toggled(card: ShopOfferCard) -> void:
	var shop := GameState.nursery.spore_shop
	if shop == null:
		return
	var locked := shop.toggle_locked(card.slot_index)
	card.set_locked(locked)
	_set_status("Locked offer" if locked else "Unlocked offer")


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


func _on_shop_offer_clicked(card: ShopOfferCard) -> void:
	_try_buy_shop_payload(card.payload)


func _on_shop_spore_to_stock(data: Dictionary) -> void:
	_try_buy_shop_payload(data)


func _try_buy_shop_payload(data: Dictionary) -> void:
	var spore := data.get("spore") as SporeData
	var cost := int(data.get("cost", 0))
	var slot_index := int(data.get("slot_index", -1))
	if spore == null:
		_set_status("Could not buy")
		return
	if GameState.try_buy_spore(spore, cost):
		_replace_bought_shop_slot(slot_index)
		_set_status("Bought %s" % spore.display_name)
		_build_shop_cards()
		_refresh()
		_refresh_base_hud()
	else:
		_set_status("Not enough biomass")


func _replace_bought_shop_slot(slot_index: int) -> void:
	if slot_index < 0:
		return
	GameState.nursery.replace_shop_slot(slot_index)


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


func _on_spore_dropped(tile: PlotTile, data: Dictionary) -> void:
	var drop_type := str(data.get("type", ""))
	if drop_type == "shop_spore":
		_plant_from_shop(tile.plot_index, data)
		return
	if drop_type == "spore":
		var stock_index := int(data.get("stock_index", 0))
		if GameState.nursery.plant(tile.plot_index, stock_index):
			_set_status("Planted spore in plot %d" % (tile.plot_index + 1))
			_refresh()
		else:
			_set_status("Could not plant")


func _plant_from_shop(plot_index: int, data: Dictionary) -> void:
	var spore := data.get("spore") as SporeData
	var cost := int(data.get("cost", 0))
	var slot_index := int(data.get("slot_index", -1))
	if spore == null:
		_set_status("Could not plant")
		return
	GameState.ensure_nursery_seeded()
	if not GameState.biomass.try_spend(cost):
		_set_status("Not enough biomass")
		return
	if not GameState.nursery.plant_spore(plot_index, spore):
		GameState.biomass.add(cost)
		_set_status("Could not plant")
		return
	_replace_bought_shop_slot(slot_index)
	_build_shop_cards()
	_set_status("Bought & planted in plot %d" % (plot_index + 1))
	_refresh()
	_refresh_base_hud()


func _refresh_base_hud() -> void:
	var base := get_tree().current_scene
	if base != null and base.has_method("_refresh_hud"):
		base._refresh_hud()


func _set_status(text: String) -> void:
	_status_label.text = text
