class_name RiboforgeData
extends Resource

const SHOP_SLOT_COUNT := 3
const STOCK_SLOT_COUNT := 5
## Bare fists: the unremovable fallback weapon for units with nothing equipped.
const DEFAULT_WEAPON_PATH := "res://assets/weapons/bare_fists.tres"
const SWORD_WEAPON_PATH := "res://assets/weapons/basic_sword/basic_sword.tres"
const SPEAR_WEAPON_PATH := "res://assets/weapons/basic_spear/basic_spear.tres"
const BOW_WEAPON_PATH := "res://assets/weapons/basic_bow/basic_bow.tres"
const SHIELD_WEAPON_PATH := "res://assets/weapons/basic_shield/basic_shield.tres"
const _DEFAULT_WEAPON_COST := 5
const _SHOP_WEAPON_PATHS := [
	SWORD_WEAPON_PATH,
	SPEAR_WEAPON_PATH,
	BOW_WEAPON_PATH,
	SHIELD_WEAPON_PATH,
]

static var _default_weapon: WeaponData

@export var weapon_stock: StockInventory
## Weapon shop state (offers + locks). Shared ShopInventory used by any shop screen.
@export var weapon_shop: ShopInventory

var _seeded: bool = false


func _init() -> void:
	_ensure_weapon_shop()
	_ensure_stock()


static func get_default_weapon() -> WeaponData:
	if _default_weapon == null:
		_default_weapon = load(DEFAULT_WEAPON_PATH) as WeaponData
	return _default_weapon


static func is_default_weapon(weapon: WeaponData) -> bool:
	return weapon == null or weapon == get_default_weapon()


static func icon_for_weapon(weapon: WeaponData) -> Texture2D:
	if weapon == null:
		return null
	return weapon.icon


func is_seeded() -> bool:
	return _seeded


func seed_if_empty() -> void:
	_ensure_weapon_shop()
	_ensure_stock()
	if _seeded:
		return
	weapon_stock.clear()
	weapon_shop.ensure_filled(generate_weapon_offer)
	_seeded = true


func reset() -> void:
	_ensure_weapon_shop()
	weapon_shop.clear()
	_seeded = false
	_ensure_stock()
	weapon_stock.clear()


func ensure_shop_offers() -> void:
	_ensure_weapon_shop()
	weapon_shop.ensure_filled(generate_weapon_offer)


func reroll_unlocked_shop_offers() -> void:
	_ensure_weapon_shop()
	weapon_shop.reroll_unlocked(generate_weapon_offer)


func replace_shop_slot(slot_index: int) -> void:
	_ensure_weapon_shop()
	weapon_shop.replace_slot(slot_index, generate_weapon_offer)


func can_add_weapon() -> bool:
	_ensure_stock()
	return weapon_stock.can_add()


## Places weapon in first empty slot. Returns slot index, or -1 on failure.
func add_weapon(weapon: WeaponData) -> int:
	_ensure_stock()
	if weapon == null:
		return -1
	return weapon_stock.add(weapon)


func generate_weapon_offer(_slot_index: int = 0) -> ShopOffer:
	var path: String = _SHOP_WEAPON_PATHS[randi() % _SHOP_WEAPON_PATHS.size()]
	var weapon := load(path) as WeaponData
	var offer := ShopOffer.new()
	offer.item = weapon
	offer.cost = weapon.biomass_cost if weapon != null else _DEFAULT_WEAPON_COST
	offer.locked = false
	return offer


func _ensure_weapon_shop() -> void:
	if weapon_shop == null:
		weapon_shop = ShopInventory.new()
	weapon_shop.slot_count = SHOP_SLOT_COUNT


func _ensure_stock() -> void:
	if weapon_stock == null:
		weapon_stock = StockInventory.new()
	weapon_stock.slot_count = STOCK_SLOT_COUNT
	weapon_stock.ensure_size()
