class_name NurseryScreen
extends BaseScreen

const STOCK_SLOT_COUNT := NurseryData.STOCK_SLOT_COUNT
const SHOP_SLOT_COUNT := NurseryData.SHOP_SLOT_COUNT
var _stock_drag_types := PackedStringArray(["spore", "fertilizer"])
var _intake_drag_types := PackedStringArray(["shop_spore", "shop_fertilizer"])
const _HATCH_TOAST_FADE_SEC := 0.18
const _HATCH_TOAST_GAP := 10.0
const _PLOT_TILE_SCENE := preload("res://assets/base/plot_tile/plot_tile.tscn")
const _SPORE_CARD_SCENE := preload("res://assets/base/nursery/spore_card/spore_card.tscn")
const _FERTILIZER_CARD_SCENE := preload("res://assets/base/nursery/fertilizer_card/fertilizer_card.tscn")
const _SHOP_OFFER_CARD_SCENE := preload("res://assets/base/shop/shop_offer_card.tscn")
const _DROP_SLOT_SCENE := preload("res://assets/base/drop_slot/drop_slot.tscn")
const _UNIT_DETAIL_CARD_SCENE := preload("res://assets/base/unit_detail_card/unit_detail_card.tscn")
const _SPORE_ICON := preload("res://assets/base/nursery/spores.png")
const _FERTILIZER_ICON := preload("res://assets/base/nursery/fertilizers/fertiliser.png")

@onready var _stock_row: HBoxContainer = %StockRow
@onready var _shop_drop_zone: ShopDropZone = %ShopDropZone
@onready var _shop_row: HBoxContainer = %ShopRow
@onready var _middle_shop_column: VBoxContainer = %MiddleShopColumn
@onready var _stock_panel: PanelContainer = %StockPanel
@onready var _shop_panel: PanelContainer = %ShopPanel
@onready var _plot_row: HBoxContainer = %PlotRow
@onready var _reroll_button: Button = %RerollButton
@onready var _reroll_cost_label: Label = %RerollCostLabel

var _tiles: Array[PlotTile] = []
var _stock_slots: Array[DropSlot] = []
var _shop_cards: Array[ShopOfferCard] = []
var _spore_icon_atlas: AtlasTexture
var _fertilizer_icon_atlas: AtlasTexture
var _hatch_toasts: Array[UnitDetailCard] = []
var _hatch_toast_dimmer: Control = null
var _hatch_toast_tween: Tween = null


func _ready() -> void:
	_spore_icon_atlas = AtlasTexture.new()
	_spore_icon_atlas.atlas = _SPORE_ICON
	_spore_icon_atlas.region = Rect2(171, 166, 171, 179)
	_fertilizer_icon_atlas = AtlasTexture.new()
	_fertilizer_icon_atlas.atlas = _FERTILIZER_ICON
	# Crop padded 512x512 art to the bag (same idea as spore atlas).
	_fertilizer_icon_atlas.region = Rect2(183, 167, 169, 180)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_reroll_button.mouse_entered.connect(_on_reroll_hover_entered)
	_reroll_button.mouse_exited.connect(_on_reroll_hover_exited)
	_shop_drop_zone.accepted_drag_types = PackedStringArray(["spore", "fertilizer"])
	_shop_drop_zone.item_dropped.connect(_on_shop_sell_dropped)
	_build_stock_slots()
	_build_plot_tiles()
	_set_structure_mouse_ignore()
	_hydrate_and_refresh()


func on_screen_shown() -> void:
	_hydrate_and_refresh()


func on_screen_hidden() -> void:
	_dismiss_hatch_toast(false)


func _hydrate_and_refresh() -> void:
	GameState.ensure_nursery_seeded()
	GameState.nursery.ensure_shop_offers()
	_rebuild_shop_cards()
	_refresh()


func _set_structure_mouse_ignore() -> void:
	for path in [
		"StockMargin",
		"StockMargin/StockVBox",
		"StockMargin/StockVBox/StockTitle",
		"StockMargin/StockVBox/StockRow",
	]:
		var node := _stock_panel.get_node_or_null(path) as Control
		if node:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for path in [
		"ShopMargin",
		"ShopMargin/ShopVBox",
		"ShopMargin/ShopVBox/ShopTitle",
	]:
		var node := _shop_panel.get_node_or_null(path) as Control
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
		slot.item_dropped.connect(_on_stock_item_dropped)
		_stock_row.add_child(slot)
		_stock_slots.append(slot)
	_update_stock_slot_accepts()


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
		tile.spore_dropped.connect(_on_plot_item_dropped)
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
	var built: Array[ShopOfferCard] = []
	built.resize(SHOP_SLOT_COUNT)
	for i in SHOP_SLOT_COUNT:
		if i >= shop.offers.size():
			break
		var offer := shop.offers[i]
		if offer == null or offer.is_empty():
			continue
		var card: ShopOfferCard = _SHOP_OFFER_CARD_SCENE.instantiate()
		if offer.item is FertilizerData:
			var fert := offer.item as FertilizerData
			card.setup(
				"Fertilizer",
				fert.display_name,
				offer.cost,
				{
					"type": "shop_fertilizer",
					"fertilizer": fert,
					"cost": offer.cost,
					"slot_index": i,
				},
				_fertilizer_icon_atlas,
				i,
				offer.locked,
				fert.tint,
				fert.short_description.strip_edges()
			)
		elif offer.item is SporeData:
			var spore := offer.item as SporeData
			var strain_name := _spore_shop_strain_name(spore)
			var description := _spore_shop_description(spore)
			card.setup(
				"Spore",
				strain_name,
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
				spore.tint,
				description
			)
		else:
			continue
		card.offer_clicked.connect(_on_shop_offer_clicked)
		card.lock_toggled.connect(_on_shop_lock_toggled)
		built[i] = card
		_shop_cards.append(card)
	# First column: first card (or same-size spacer) on top, reroll fixed below.
	_middle_shop_column.alignment = BoxContainer.ALIGNMENT_BEGIN
	_shop_row.move_child(_middle_shop_column, 0)
	var first_slot: Control = built[0] if not built.is_empty() and built[0] != null else _make_shop_card_spacer()
	_middle_shop_column.add_child(first_slot)
	_middle_shop_column.move_child(first_slot, 0)
	_middle_shop_column.move_child(_reroll_button, 1)
	first_slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for i in range(1, SHOP_SLOT_COUNT):
		var next_card := built[i] if i < built.size() else null
		if next_card == null:
			continue
		_shop_row.add_child(next_card)
		next_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_refresh_common_spore_shop_hint()


func _refresh_common_spore_shop_hint() -> void:
	if not GameState.show_common_spore_shop_hint:
		return
	for card in _shop_cards:
		var spore := card.payload.get("spore") as SporeData
		if GameState.nursery.is_common_generalist_spore(spore):
			card.set_buy_hint_visible(true)
			return


func _make_shop_card_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = ShopOfferCard.CARD_SIZE
	spacer.size = ShopOfferCard.CARD_SIZE
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _spore_shop_strain_name(spore: SporeData) -> String:
	var strain := spore.resolved_strain() if spore != null else null
	if strain == null:
		return spore.display_name if spore != null else ""
	return "%s Strain" % strain.display_name


func _spore_shop_description(spore: SporeData) -> String:
	var strain := spore.resolved_strain() if spore != null else null
	if strain == null:
		return ""
	return strain.short_description.strip_edges()


func _sync_stock_slots() -> void:
	var stock := GameState.nursery.stock
	_update_stock_slot_accepts()
	for i in _stock_slots.size():
		var slot := _stock_slots[i]
		slot.clear_card()
		var item := stock.get_at(i)
		if item is SporeData:
			var card: SporeCard = _SPORE_CARD_SCENE.instantiate()
			card.setup(item as SporeData, i)
			card.spore_clicked.connect(_on_stock_spore_clicked)
			slot.set_card(card)
		elif item is FertilizerData:
			var fert_card: FertilizerCard = _FERTILIZER_CARD_SCENE.instantiate()
			fert_card.setup(item as FertilizerData, i)
			slot.set_card(fert_card)


func _update_stock_slot_accepts() -> void:
	StockInventory.configure_drop_slots(
		_stock_slots,
		_stock_drag_types,
		_intake_drag_types,
		GameState.nursery.can_add_stock_item()
	)


func _refresh() -> void:
	var nursery := GameState.nursery
	var expected_visible := nursery.unlocked_plot_count
	if nursery.can_unlock_plot():
		expected_visible += 1
	if _tiles.size() != expected_visible:
		_build_plot_tiles()
	var can_plant := nursery.has_spore_in_stock()
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
	_reroll_cost_label.text = "%d" % GameState.nursery.shop_reroll_cost
	var can_reroll := GameState.biomass.can_afford(GameState.nursery.shop_reroll_cost)
	# Keep mouse events so hover preview still works when unaffordable.
	_reroll_button.disabled = false
	_reroll_button.modulate = Color.WHITE if can_reroll else Color(1, 1, 1, 0.45)
	for tile in _tiles:
		if tile.is_unlockable:
			tile.setup_unlockable(tile.plot_index, tile.unlock_cost)


func _on_reroll_hover_entered() -> void:
	for card in _shop_cards:
		card.set_reroll_preview(true)


func _on_reroll_hover_exited() -> void:
	for card in _shop_cards:
		card.set_reroll_preview(false)


func _on_reroll_pressed() -> void:
	if not GameState.biomass.try_spend(GameState.nursery.shop_reroll_cost):
		return
	for card in _shop_cards:
		card.clear_reroll_preview()
	GameState.nursery.reroll_unlocked_shop_offers()
	GameState.nursery.advance_shop_reroll_cost()
	_rebuild_shop_cards()
	_refresh_shop_affordability()
	_refresh_base_hud()
	_play_shop_reroll_shake()


func _play_shop_reroll_shake() -> void:
	for i in _shop_cards.size():
		_shop_cards[i].play_reroll_shake(0.03 * float(i))


func _on_shop_lock_toggled(card: ShopOfferCard) -> void:
	var shop := GameState.nursery.spore_shop
	if shop == null:
		return
	var locked := shop.toggle_locked(card.slot_index)
	card.set_locked(locked)


func _on_shop_offer_clicked(card: ShopOfferCard) -> void:
	_try_buy_shop_payload(card.payload)


func _on_stock_item_dropped(slot: DropSlot, data: Dictionary) -> void:
	if StockInventory.consume_stock_rearrange(
		GameState.nursery.stock, data, slot.slot_index, _stock_drag_types
	):
		_refresh()
		return
	_try_buy_shop_payload(data)


func _on_stock_spore_clicked(card: SporeCard) -> void:
	if card == null:
		return
	var nursery := GameState.nursery
	var plot_index := nursery.first_empty_plot_index()
	if plot_index < 0:
		return
	if nursery.plant(plot_index, card.stock_index):
		GameState.show_plot_plant_hint = false
		_refresh()


func _on_shop_sell_dropped(_zone: ShopDropZone, data: Dictionary) -> void:
	var drop_type := str(data.get("type", ""))
	if drop_type != "spore" and drop_type != "fertilizer":
		return
	var stock_index := int(data.get("stock_index", -1))
	if GameState.try_sell_nursery_stock_item(stock_index):
		_refresh()
		_refresh_base_hud()


func _try_buy_shop_payload(data: Dictionary) -> void:
	var cost := int(data.get("cost", 0))
	var slot_index := int(data.get("slot_index", -1))
	var drop_type := str(data.get("type", ""))
	if not GameState.nursery.can_add_stock_item():
		return
	var bought := false
	var bought_spore: SporeData = null
	if drop_type == "shop_spore":
		var spore := data.get("spore") as SporeData
		if spore == null:
			return
		bought = GameState.try_buy_spore(spore, cost)
		if bought:
			bought_spore = spore
	elif drop_type == "shop_fertilizer":
		var fertilizer := data.get("fertilizer") as FertilizerData
		if fertilizer == null:
			return
		bought = GameState.try_buy_fertilizer(fertilizer, cost)
	else:
		return
	if bought:
		if GameState.nursery.is_common_generalist_spore(bought_spore):
			GameState.show_common_spore_shop_hint = false
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
			if not nursery.has_spore_in_stock():
				return
			if nursery.plant(tile.plot_index):
				GameState.show_plot_plant_hint = false
				_refresh()
		NurseryPlotData.State.GROWING:
			pass
		NurseryPlotData.State.READY:
			if not GameState.troop.is_seeded():
				var empty_bench: Array[RosterUnitData] = []
				GameState.troop.seed_if_empty(empty_bench)
			if not GameState.troop.has_free_slot():
				return
			var harvested := nursery.harvest(tile.plot_index)
			if harvested.is_empty():
				return
			var kept: Array[RosterUnitData] = []
			for unit in harvested:
				if not GameState.troop.has_free_slot():
					break
				if GameState.troop.try_add_unit(unit) != "":
					kept.append(unit)
			if kept.is_empty():
				return
			GameState.show_plot_harvest_hint = false
			var toast_anchor := tile.get_global_rect()
			_refresh()
			_show_hatch_toasts(kept, toast_anchor)


func _show_hatch_toasts(units: Array[RosterUnitData], anchor_global_rect: Rect2) -> void:
	_dismiss_hatch_toast(false)
	if units.is_empty():
		return
	var dimmer := Control.new()
	dimmer.name = "HatchToastDimmer"
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.gui_input.connect(_on_hatch_toast_dimmer_input)
	add_child(dimmer)
	_hatch_toast_dimmer = dimmer

	var cards: Array[UnitDetailCard] = []
	for unit in units:
		var card: UnitDetailCard = _UNIT_DETAIL_CARD_SCENE.instantiate()
		card.setup(unit)
		card.modulate.a = 0.0
		add_child(card)
		card.reset_compact_layout()
		card.gui_input.connect(_on_hatch_toast_card_input)
		cards.append(card)
	_hatch_toasts = cards
	_position_hatch_toasts(cards, anchor_global_rect)

	var tween := create_tween()
	_hatch_toast_tween = tween
	tween.set_parallel(true)
	for card in cards:
		tween.tween_property(card, "modulate:a", 1.0, _HATCH_TOAST_FADE_SEC)
	tween.chain().tween_callback(func() -> void: _hatch_toast_tween = null)


func _position_hatch_toasts(cards: Array[UnitDetailCard], anchor_global_rect: Rect2) -> void:
	if cards.is_empty():
		return
	var card_size := cards[0].card_size()
	var count := cards.size()
	var total_width := card_size.x * count + _HATCH_TOAST_GAP * maxi(count - 1, 0)
	var local_top_left := anchor_global_rect.position - global_position
	var row_x := local_top_left.x + (anchor_global_rect.size.x - total_width) * 0.5
	var row_y := local_top_left.y - card_size.y + 24.0
	row_x = clampf(row_x, 8.0, maxf(8.0, size.x - total_width - 8.0))
	row_y = clampf(row_y, 8.0, maxf(8.0, size.y - card_size.y - 8.0))
	for i in count:
		cards[i].position = Vector2(
			row_x + float(i) * (card_size.x + _HATCH_TOAST_GAP),
			row_y
		)


func _on_hatch_toast_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_dismiss_hatch_toast(true)
			accept_event()


func _on_hatch_toast_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_dismiss_hatch_toast(true)
			accept_event()


func _dismiss_hatch_toast(animated: bool) -> void:
	if _hatch_toast_tween != null:
		_hatch_toast_tween.kill()
		_hatch_toast_tween = null
	var cards := _hatch_toasts
	var dimmer := _hatch_toast_dimmer
	_hatch_toast_dimmer = null
	if dimmer != null and is_instance_valid(dimmer):
		dimmer.queue_free()
	var valid_cards: Array[UnitDetailCard] = []
	for card in cards:
		if card != null and is_instance_valid(card):
			valid_cards.append(card)
	if valid_cards.is_empty():
		_hatch_toasts = []
		return
	if not animated:
		_hatch_toasts = []
		for card in valid_cards:
			card.queue_free()
		return
	var tween := create_tween()
	_hatch_toast_tween = tween
	tween.set_parallel(true)
	for card in valid_cards:
		tween.tween_property(card, "modulate:a", 0.0, _HATCH_TOAST_FADE_SEC)
	tween.chain().tween_callback(func() -> void:
		for card in valid_cards:
			if is_instance_valid(card):
				card.queue_free()
		if not _hatch_toasts.is_empty() and _hatch_toasts[0] == valid_cards[0]:
			_hatch_toasts = []
		_hatch_toast_tween = null
	)


func _on_plot_item_dropped(tile: PlotTile, data: Dictionary) -> void:
	if tile.is_unlockable:
		return
	var drop_type := str(data.get("type", ""))
	match drop_type:
		"shop_spore":
			_plant_from_shop(tile.plot_index, data)
		"spore":
			var stock_index := int(data.get("stock_index", 0))
			if GameState.nursery.plant(tile.plot_index, stock_index):
				GameState.show_plot_plant_hint = false
				_refresh()
		"shop_fertilizer":
			_apply_fertilizer_from_shop(tile.plot_index, data)
		"fertilizer":
			var fert_index := int(data.get("stock_index", 0))
			if GameState.nursery.apply_fertilizer_from_stock(tile.plot_index, fert_index):
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
	GameState.show_plot_plant_hint = false
	if GameState.nursery.is_common_generalist_spore(spore):
		GameState.show_common_spore_shop_hint = false
	_replace_bought_shop_slot(slot_index)
	_rebuild_shop_cards()
	_refresh()
	_refresh_base_hud()


func _apply_fertilizer_from_shop(plot_index: int, data: Dictionary) -> void:
	var fertilizer := data.get("fertilizer") as FertilizerData
	var cost := int(data.get("cost", 0))
	var slot_index := int(data.get("slot_index", -1))
	if fertilizer == null:
		return
	GameState.ensure_nursery_seeded()
	if not GameState.biomass.try_spend(cost):
		return
	if not GameState.nursery.apply_fertilizer_to_plot(plot_index, fertilizer):
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
