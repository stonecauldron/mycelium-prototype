class_name RiboforgeScreen
extends BaseScreen

const STOCK_SLOT_COUNT := RiboforgeData.STOCK_SLOT_COUNT
const SHOP_SLOT_COUNT := RiboforgeData.SHOP_SLOT_COUNT
const _WEAPON_CARD_SCENE := preload("res://assets/base/riboforge/weapon_card.tscn")
const _SHOP_OFFER_CARD_SCENE := preload("res://assets/base/shop/shop_offer_card.tscn")
const _UNIT_CARD_SCENE := preload("res://assets/base/unit_card/unit_card.tscn")
const _DROP_SLOT_SCENE := preload("res://assets/base/drop_slot/drop_slot.tscn")
const _FLOOR_TILE_FORGE := preload("res://assets/base/background/floor_tile_forge.png")

@onready var _stock_row: HBoxContainer = %StockRow
@onready var _shop_drop_zone: ShopDropZone = %ShopDropZone
@onready var _shop_row: HBoxContainer = %ShopRow
@onready var _middle_shop_column: VBoxContainer = %MiddleShopColumn
@onready var _stock_shop_panel: PanelContainer = %StockShopPanel
@onready var _squad_row: HBoxContainer = %SquadRow
@onready var _reroll_button: Button = %RerollButton
@onready var _reroll_cost_label: Label = %RerollCostLabel

var _stock_slots: Array[DropSlot] = []
var _shop_cards: Array[ShopOfferCard] = []


func _ready() -> void:
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_shop_drop_zone.accepted_drag_types = PackedStringArray(["weapon", "equipped_weapon"])
	_shop_drop_zone.item_dropped.connect(_on_shop_sell_dropped)
	_build_stock_slots()
	_set_structure_mouse_ignore()
	_hydrate_and_refresh()


func on_screen_shown() -> void:
	_hydrate_and_refresh()


func _hydrate_and_refresh() -> void:
	GameState.ensure_riboforge_seeded()
	GameState.riboforge.ensure_shop_offers()
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
		slot.accepted_drag_types = PackedStringArray(["shop_weapon", "equipped_weapon"])
		slot.item_dropped.connect(_on_stock_item_dropped)
		_stock_row.add_child(slot)
		slot.set_floor_texture(_FLOOR_TILE_FORGE)
		_stock_slots.append(slot)


func _rebuild_shop_cards() -> void:
	for child in _middle_shop_column.get_children():
		if child != _reroll_button:
			child.queue_free()
	for child in _shop_row.get_children():
		if child != _middle_shop_column:
			child.queue_free()
	_shop_cards.clear()
	var shop := GameState.riboforge.weapon_shop
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
		var weapon := offer.item as WeaponData
		if weapon == null:
			continue
		var card: ShopOfferCard = _SHOP_OFFER_CARD_SCENE.instantiate()
		var range_name := str(WeaponData.FORMATION_LINE_LABELS.get(weapon.formation_line, "?"))
		var display_dmg: int = roundi(float(weapon.base_damage) * weapon.outgoing_damage_multiplier)
		card.setup(
			weapon.display_name,
			"%s · dmg %d" % [range_name, display_dmg],
			offer.cost,
			{
				"type": "shop_weapon",
				"weapon": weapon,
				"cost": offer.cost,
				"slot_index": i,
			},
			_icon_for_weapon(weapon),
			i,
			offer.locked
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


func _icon_for_weapon(weapon: WeaponData) -> Texture2D:
	return RiboforgeData.icon_for_weapon(weapon)


func _sync_stock_slots() -> void:
	var stock := GameState.riboforge.weapon_stock
	var can_add := GameState.riboforge.can_add_weapon()
	for i in _stock_slots.size():
		var slot := _stock_slots[i]
		slot.accepts_drops = can_add
		slot.clear_card()
		if i >= stock.size():
			continue
		var weapon := stock[i] as WeaponData
		if weapon == null:
			continue
		var card: WeaponCard = _WEAPON_CARD_SCENE.instantiate()
		card.setup(weapon, i)
		slot.set_card(card)


func _refresh() -> void:
	_sync_stock_slots()
	_rebuild_squad_cards()
	_refresh_shop_affordability()


func _refresh_shop_affordability() -> void:
	for card in _shop_cards:
		card.set_affordable(GameState.biomass.can_afford(card.cost))
	_reroll_cost_label.text = "%d" % BiomassData.SHOP_REROLL_COST
	var can_reroll := GameState.biomass.can_afford(BiomassData.SHOP_REROLL_COST)
	_reroll_button.disabled = not can_reroll
	_reroll_button.modulate = Color.WHITE if can_reroll else Color(1, 1, 1, 0.45)


func _rebuild_squad_cards() -> void:
	for child in _squad_row.get_children():
		child.queue_free()
	for entry in GameState.troop.squad:
		var unit := entry as RosterUnitData
		if unit == null:
			continue
		var card: UnitCard = _UNIT_CARD_SCENE.instantiate()
		_squad_row.add_child(card)
		card.setup(unit, "riboforge_squad", null)
		card.weapon_loadout_changed.connect(_on_unit_weapon_changed)


func _on_unit_weapon_changed(_card: UnitCard) -> void:
	_rebuild_shop_cards()
	_refresh()
	_refresh_base_hud()


func _on_reroll_pressed() -> void:
	if not GameState.biomass.try_spend(BiomassData.SHOP_REROLL_COST):
		return
	GameState.riboforge.reroll_unlocked_shop_offers()
	_rebuild_shop_cards()
	_refresh_shop_affordability()
	_refresh_base_hud()


func _on_shop_lock_toggled(card: ShopOfferCard) -> void:
	var shop := GameState.riboforge.weapon_shop
	if shop == null:
		return
	var locked := shop.toggle_locked(card.slot_index)
	card.set_locked(locked)


func _on_shop_offer_clicked(card: ShopOfferCard) -> void:
	_try_buy_shop_payload(card.payload)


func _on_stock_item_dropped(_slot: DropSlot, data: Dictionary) -> void:
	var drop_type := str(data.get("type", ""))
	if drop_type == "shop_weapon":
		_try_buy_shop_payload(data)
		return
	if drop_type == "equipped_weapon":
		_try_unequip_to_stock(data)


func _on_shop_sell_dropped(_zone: ShopDropZone, data: Dictionary) -> void:
	var drop_type := str(data.get("type", ""))
	var sold := false
	if drop_type == "weapon":
		sold = GameState.try_sell_weapon_from_stock(int(data.get("stock_index", -1)))
	elif drop_type == "equipped_weapon":
		sold = GameState.try_sell_equipped_weapon(data.get("unit") as RosterUnitData)
	if sold:
		_refresh()
		_refresh_base_hud()


func _try_unequip_to_stock(data: Dictionary) -> void:
	var unit := data.get("unit") as RosterUnitData
	if unit == null:
		return
	if not GameState.riboforge.can_add_weapon():
		return
	if GameState.try_unequip_weapon_to_stock(unit):
		_refresh()
		_refresh_base_hud()


func _try_buy_shop_payload(data: Dictionary) -> void:
	var weapon := data.get("weapon") as WeaponData
	var cost := int(data.get("cost", 0))
	var slot_index := int(data.get("slot_index", -1))
	if weapon == null:
		return
	if not GameState.riboforge.can_add_weapon():
		return
	if GameState.try_buy_weapon(weapon, cost):
		if slot_index >= 0:
			GameState.riboforge.replace_shop_slot(slot_index)
		_rebuild_shop_cards()
		_refresh()
		_refresh_base_hud()


func _refresh_base_hud() -> void:
	var base := get_tree().current_scene
	if base != null and base.has_method("_refresh_hud"):
		base._refresh_hud()
