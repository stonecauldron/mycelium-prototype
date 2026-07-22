class_name NurseryScreen
extends BaseScreen

const STOCK_SLOT_COUNT := NurseryData.STOCK_SLOT_COUNT
const SHOP_SLOT_COUNT := NurseryData.SHOP_SLOT_COUNT
const _PLOT_TILE_SCENE := preload("res://assets/base/plot_tile/plot_tile.tscn")
const _SPORE_CARD_SCENE := preload("res://assets/base/nursery/spore_card/spore_card.tscn")
const _SHOP_OFFER_CARD_SCENE := preload("res://assets/base/shop/shop_offer_card.tscn")
const _DROP_SLOT_SCENE := preload("res://assets/base/drop_slot/drop_slot.tscn")
const _SPORE_ICON := preload("res://assets/base/nursery/spores.png")

@onready var _stock_row: HBoxContainer = %StockRow
@onready var _shop_drop_zone: ShopDropZone = %ShopDropZone
@onready var _shop_row: HBoxContainer = %ShopRow
@onready var _middle_shop_column: VBoxContainer = %MiddleShopColumn
@onready var _stock_shop_panel: PanelContainer = %StockShopPanel
@onready var _plot_row: HBoxContainer = %PlotRow
@onready var _reroll_button: Button = %RerollButton
@onready var _reroll_cost_label: Label = %RerollCostLabel

var _tiles: Array[PlotTile] = []
var _stock_slots: Array[DropSlot] = []
var _shop_cards: Array[ShopOfferCard] = []
var _spore_icon_atlas: AtlasTexture


func _ready() -> void:
	_spore_icon_atlas = AtlasTexture.new()
	_spore_icon_atlas.atlas = _SPORE_ICON
	_spore_icon_atlas.region = Rect2(171, 166, 171, 179)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_shop_drop_zone.accepted_drag_types = PackedStringArray(["spore"])
	_shop_drop_zone.item_dropped.connect(_on_shop_sell_dropped)
	_build_stock_slots()
	_build_plot_tiles()
	_set_structure_mouse_ignore()
	_hydrate_and_refresh()


func on_screen_shown() -> void:
	_hydrate_and_refresh()


func _hydrate_and_refresh() -> void:
	GameState.ensure_nursery_seeded()
	GameState.nursery.ensure_shop_offers()
	_rebuild_shop_cards()
	_refresh()


func _set_structure_mouse_ignore() -> void:
	for path in [
		"StockShopMargin",
		"StockShopMargin/StockShopVBox",
		"StockShopMargin/StockShopVBox/StockShopTitle",
		"StockShopMargin/StockShopVBox/StockShopRow",
	]:
		var node := _stock_shop_panel.get_node_or_null(path) as Control
		if node:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_middle_shop_column.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_stock_slots() -> void:
	for child in _stock_row.get_children():
		child.queue_free()
	_stock_slots.clear()
	for i in STOCK_SLOT_COUNT:
		var slot: DropSlot = _DROP_SLOT_SCENE.instantiate()
		slot.slot_index = i
		slot.accepted_drag_types = PackedStringArray(["shop_spore"])
		slot.item_dropped.connect(_on_stock_item_dropped)
		_stock_row.add_child(slot)
		_stock_slots.append(slot)


func _build_plot_tiles() -> void:
	for child in _plot_row.get_children():
		_plot_row.remove_child(child)
		child.queue_free()
	_tiles.clear()
	GameState.ensure_nursery_seeded()
	var nursery := GameState.nursery
	var visible_count := nursery.unlocked_plot_count
	if nursery.can_unlock_plot():
		visible_count += 1
	for i in visible_count:
		var tile: PlotTile = _PLOT_TILE_SCENE.instantiate()
		_plot_row.add_child(tile)
		tile.plot_pressed.connect(_on_plot_pressed)
		tile.spore_dropped.connect(_on_spore_dropped)
		_tiles.append(tile)


func _rebuild_shop_cards() -> void:
	for child in _middle_shop_column.get_children():
		if child != _reroll_button:
			child.queue_free()
	for child in _shop_row.get_children():
		if child != _middle_shop_column:
			child.queue_free()
	_shop_cards.clear()
	var shop := GameState.nursery.spore_shop
	if shop == null:
		return
	var middle_index := SHOP_SLOT_COUNT / 2
	var built: Array[ShopOfferCard] = []
	built.resize(SHOP_SLOT_COUNT)
	for i in SHOP_SLOT_COUNT:
		if i >= shop.offers.size():
			break
		var offer := shop.offers[i]
		if offer == null:
			continue
		var spore := offer.item as SporeData
		if spore == null:
			continue
		var card: ShopOfferCard = _SHOP_OFFER_CARD_SCENE.instantiate()
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
		built[i] = card
		_shop_cards.append(card)
	for i in middle_index:
		var left_card := built[i]
		if left_card == null:
			continue
		_shop_row.add_child(left_card)
		_shop_row.move_child(left_card, i)
		left_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var middle_card := built[middle_index] if middle_index < built.size() else null
	if middle_card != null:
		_middle_shop_column.add_child(middle_card)
		_middle_shop_column.move_child(middle_card, 0)
		_middle_shop_column.move_child(_reroll_button, 1)
	for i in range(middle_index + 1, SHOP_SLOT_COUNT):
		var right_card := built[i]
		if right_card == null:
			continue
		_shop_row.add_child(right_card)
		right_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _sync_stock_slots() -> void:
	var stock := GameState.nursery.spore_stock
	var can_add := GameState.nursery.can_add_spore()
	for i in _stock_slots.size():
		var slot := _stock_slots[i]
		slot.accepts_drops = can_add
		slot.clear_card()
		if i >= stock.size():
			continue
		var spore := stock[i] as SporeData
		if spore == null:
			continue
		var card: SporeCard = _SPORE_CARD_SCENE.instantiate()
		card.setup(spore, i)
		slot.set_card(card)


func _refresh() -> void:
	var nursery := GameState.nursery
	var expected_visible := nursery.unlocked_plot_count
	if nursery.can_unlock_plot():
		expected_visible += 1
	if _tiles.size() != expected_visible:
		_build_plot_tiles()
	var can_plant := not nursery.spore_stock.is_empty()
	_sync_stock_slots()
	_refresh_shop_affordability()
	for i in nursery.unlocked_plot_count:
		if i >= _tiles.size():
			break
		var plot := nursery.plots[i] as NurseryPlotData if i < nursery.plots.size() else null
		_tiles[i].setup(i, plot, can_plant)
	if nursery.can_unlock_plot() and _tiles.size() > nursery.unlocked_plot_count:
		var unlock_index := nursery.unlocked_plot_count
		_tiles[unlock_index].setup_unlockable(unlock_index, nursery.next_unlock_cost())


func _refresh_shop_affordability() -> void:
	for card in _shop_cards:
		card.set_affordable(GameState.biomass.can_afford(card.cost))
	_reroll_cost_label.text = "%d" % BiomassData.SHOP_REROLL_COST
	var can_reroll := GameState.biomass.can_afford(BiomassData.SHOP_REROLL_COST)
	_reroll_button.disabled = not can_reroll
	_reroll_button.modulate = Color.WHITE if can_reroll else Color(1, 1, 1, 0.45)
	for tile in _tiles:
		if tile.is_unlockable:
			tile.setup_unlockable(tile.plot_index, tile.unlock_cost)


func _on_reroll_pressed() -> void:
	if not GameState.biomass.try_spend(BiomassData.SHOP_REROLL_COST):
		return
	GameState.nursery.reroll_unlocked_shop_offers()
	_rebuild_shop_cards()
	_refresh_shop_affordability()
	_refresh_base_hud()


func _on_shop_lock_toggled(card: ShopOfferCard) -> void:
	var shop := GameState.nursery.spore_shop
	if shop == null:
		return
	var locked := shop.toggle_locked(card.slot_index)
	card.set_locked(locked)


func _on_shop_offer_clicked(card: ShopOfferCard) -> void:
	_try_buy_shop_payload(card.payload)


func _on_stock_item_dropped(_slot: DropSlot, data: Dictionary) -> void:
	_try_buy_shop_payload(data)


func _on_shop_sell_dropped(_zone: ShopDropZone, data: Dictionary) -> void:
	if str(data.get("type", "")) != "spore":
		return
	var stock_index := int(data.get("stock_index", -1))
	if GameState.try_sell_spore_from_stock(stock_index):
		_refresh()
		_refresh_base_hud()


func _try_buy_shop_payload(data: Dictionary) -> void:
	var spore := data.get("spore") as SporeData
	var cost := int(data.get("cost", 0))
	var slot_index := int(data.get("slot_index", -1))
	if spore == null:
		return
	if not GameState.nursery.can_add_spore():
		return
	if GameState.try_buy_spore(spore, cost):
		_replace_bought_shop_slot(slot_index)
		_rebuild_shop_cards()
		_refresh()
		_refresh_base_hud()


func _replace_bought_shop_slot(slot_index: int) -> void:
	if slot_index < 0:
		return
	GameState.nursery.replace_shop_slot(slot_index)


func _on_plot_pressed(tile: PlotTile) -> void:
	if tile.is_unlockable:
		_try_unlock_plot()
		return
	var nursery := GameState.nursery
	if not nursery.is_plot_unlocked(tile.plot_index):
		return
	if tile.plot_index >= nursery.plots.size():
		return
	var plot := nursery.plots[tile.plot_index] as NurseryPlotData
	if plot == null:
		return

	match plot.get_state():
		NurseryPlotData.State.EMPTY:
			if nursery.spore_stock.is_empty():
				return
			if nursery.plant(tile.plot_index):
				_refresh()
		NurseryPlotData.State.GROWING:
			pass
		NurseryPlotData.State.READY:
			if not GameState.troop.is_seeded():
				var empty_bench: Array[RosterUnitData] = []
				GameState.troop.seed_if_empty(empty_bench)
			if not GameState.troop.has_free_slot():
				return
			var unit := nursery.harvest(tile.plot_index)
			if unit == null:
				return
			GameState.troop.try_add_unit(unit)
			_refresh()


func _on_spore_dropped(tile: PlotTile, data: Dictionary) -> void:
	if tile.is_unlockable:
		return
	var drop_type := str(data.get("type", ""))
	if drop_type == "shop_spore":
		_plant_from_shop(tile.plot_index, data)
		return
	if drop_type == "spore":
		var stock_index := int(data.get("stock_index", 0))
		if GameState.nursery.plant(tile.plot_index, stock_index):
			_refresh()


func _try_unlock_plot() -> void:
	if GameState.try_unlock_plot():
		_build_plot_tiles()
		_refresh()
		_refresh_base_hud()


func _plant_from_shop(plot_index: int, data: Dictionary) -> void:
	var spore := data.get("spore") as SporeData
	var cost := int(data.get("cost", 0))
	var slot_index := int(data.get("slot_index", -1))
	if spore == null:
		return
	GameState.ensure_nursery_seeded()
	if not GameState.biomass.try_spend(cost):
		return
	if not GameState.nursery.plant_spore(plot_index, spore):
		GameState.biomass.add(cost)
		return
	_replace_bought_shop_slot(slot_index)
	_rebuild_shop_cards()
	_refresh()
	_refresh_base_hud()


func _refresh_base_hud() -> void:
	var base := get_tree().current_scene
	if base != null and base.has_method("_refresh_hud"):
		base._refresh_hud()
