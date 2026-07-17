class_name RiboforgeScreen
extends BaseScreen

const _WEAPON_CARD_SCENE := preload("res://assets/base/riboforge/weapon_card.tscn")
const _SHOP_OFFER_CARD_SCENE := preload("res://assets/base/shop/shop_offer_card.tscn")
const _UNIT_CARD_SCENE := preload("res://assets/base/unit_card/unit_card.tscn")

const RANGE_LABELS := {
	WeaponData.WeaponRange.MELEE: "Melee",
	WeaponData.WeaponRange.MID: "Mid",
	WeaponData.WeaponRange.RANGED: "Ranged",
}

@onready var _stock_label: Label = %StockLabel
@onready var _stock_row: HBoxContainer = %StockRow
@onready var _stock_panel: WeaponStockDropHost = %StockPanel
@onready var _squad_row: HBoxContainer = %SquadRow
@onready var _shop_column: VBoxContainer = %ShopColumn
@onready var _reroll_button: Button = %RerollButton
@onready var _reroll_cost_label: Label = %RerollCostLabel
@onready var _status_label: Label = %StatusLabel

var _shop_cards: Array[ShopOfferCard] = []


func _ready() -> void:
	_stock_panel.shop_weapon_dropped.connect(_on_shop_weapon_to_stock)
	_stock_panel.equipped_weapon_dropped.connect(_on_equipped_weapon_to_stock)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_hydrate_and_refresh()


func on_screen_shown() -> void:
	_hydrate_and_refresh()


func _hydrate_and_refresh() -> void:
	GameState.ensure_riboforge_seeded()
	GameState.riboforge.ensure_shop_offers()
	_build_shop_cards()
	_refresh()


func _build_shop_cards() -> void:
	for child in _shop_column.get_children():
		child.queue_free()
	_shop_cards.clear()
	var shop := GameState.riboforge.weapon_shop
	if shop == null:
		return
	for i in shop.offers.size():
		var offer := shop.offers[i]
		if offer == null:
			continue
		var weapon := offer.item as WeaponData
		if weapon == null:
			continue
		var card: ShopOfferCard = _SHOP_OFFER_CARD_SCENE.instantiate()
		_shop_column.add_child(card)
		var range_name := str(RANGE_LABELS.get(weapon.range_class, "?"))
		card.setup(
			weapon.display_name,
			"%s · dmg %d" % [range_name, weapon.base_damage],
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
		_shop_cards.append(card)


func _icon_for_weapon(weapon: WeaponData) -> Texture2D:
	return RiboforgeData.icon_for_weapon(weapon)


func _refresh() -> void:
	var stock := GameState.riboforge.weapon_stock
	_stock_label.text = "Weapons in stock: %d" % stock.size()
	_rebuild_stock_cards()
	_rebuild_squad_cards()
	_refresh_shop_affordability()


func _refresh_shop_affordability() -> void:
	for card in _shop_cards:
		card.set_affordable(GameState.biomass.can_afford(card.cost))
	_reroll_cost_label.text = "%d" % BiomassData.SHOP_REROLL_COST
	var can_reroll := GameState.biomass.can_afford(BiomassData.SHOP_REROLL_COST)
	_reroll_button.disabled = not can_reroll
	_reroll_button.modulate = Color.WHITE if can_reroll else Color(1, 1, 1, 0.45)


func _rebuild_stock_cards() -> void:
	for child in _stock_row.get_children():
		child.queue_free()
	var stock := GameState.riboforge.weapon_stock
	for i in stock.size():
		var weapon := stock[i] as WeaponData
		if weapon == null:
			continue
		var card: WeaponCard = _WEAPON_CARD_SCENE.instantiate()
		_stock_row.add_child(card)
		card.setup(weapon, i)


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
	_set_status("Weapon equipped")
	_build_shop_cards()
	_refresh()
	_refresh_base_hud()


func _on_reroll_pressed() -> void:
	if not GameState.biomass.try_spend(BiomassData.SHOP_REROLL_COST):
		_set_status("Not enough biomass")
		return
	GameState.riboforge.reroll_unlocked_shop_offers()
	_build_shop_cards()
	_refresh_shop_affordability()
	_refresh_base_hud()
	_set_status("Shop rerolled")


func _on_shop_lock_toggled(card: ShopOfferCard) -> void:
	var shop := GameState.riboforge.weapon_shop
	if shop == null:
		return
	var locked := shop.toggle_locked(card.slot_index)
	card.set_locked(locked)
	_set_status("Locked offer" if locked else "Unlocked offer")


func _on_shop_offer_clicked(card: ShopOfferCard) -> void:
	_try_buy_shop_payload(card.payload)


func _on_shop_weapon_to_stock(data: Dictionary) -> void:
	_try_buy_shop_payload(data)


func _on_equipped_weapon_to_stock(data: Dictionary) -> void:
	var unit := data.get("unit") as RosterUnitData
	if unit == null:
		_set_status("Could not unequip")
		return
	if GameState.try_unequip_weapon_to_stock(unit):
		var weapon := data.get("weapon") as WeaponData
		if weapon != null:
			_set_status("Unequipped %s → stock" % weapon.display_name)
		else:
			_set_status("Unequipped weapon → stock")
		_refresh()
		_refresh_base_hud()
	else:
		_set_status("Nothing to unequip")


func _try_buy_shop_payload(data: Dictionary) -> void:
	var weapon := data.get("weapon") as WeaponData
	var cost := int(data.get("cost", 0))
	var slot_index := int(data.get("slot_index", -1))
	if weapon == null:
		_set_status("Could not buy")
		return
	if GameState.try_buy_weapon(weapon, cost):
		if slot_index >= 0:
			GameState.riboforge.replace_shop_slot(slot_index)
		_set_status("Bought %s" % weapon.display_name)
		_build_shop_cards()
		_refresh()
		_refresh_base_hud()
	else:
		_set_status("Not enough biomass")


func _refresh_base_hud() -> void:
	var base := get_tree().current_scene
	if base != null and base.has_method("_refresh_hud"):
		base._refresh_hud()


func _set_status(text: String) -> void:
	_status_label.text = text
