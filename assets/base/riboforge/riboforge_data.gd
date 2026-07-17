class_name RiboforgeData
extends Resource

const SHOP_SLOT_COUNT := 3
## Bare fists: the unremovable fallback weapon for units with nothing equipped.
const DEFAULT_WEAPON_PATH := "res://assets/weapons/bare_fists.tres"
const MELEE_WEAPON_PATH := "res://assets/weapons/basic_melee/basic_melee.tres"
const SPEAR_WEAPON_PATH := "res://assets/weapons/basic_spear/basic_spear.tres"
const _DEFAULT_WEAPON_COST := 5

static var _default_weapon: WeaponData

@export var weapon_stock: Array[WeaponData] = []
## Weapon shop state (offers + locks). Shared ShopInventory used by any shop screen.
@export var weapon_shop: ShopInventory

var _seeded: bool = false


func _init() -> void:
	_ensure_weapon_shop()


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
	if _seeded:
		return
	_ensure_weapon_shop()
	weapon_stock.clear()
	weapon_shop.ensure_filled(generate_weapon_offer)
	_seeded = true


func reset() -> void:
	weapon_stock.clear()
	_ensure_weapon_shop()
	weapon_shop.clear()
	_seeded = false


func ensure_shop_offers() -> void:
	_ensure_weapon_shop()
	weapon_shop.ensure_filled(generate_weapon_offer)


func reroll_unlocked_shop_offers() -> void:
	_ensure_weapon_shop()
	weapon_shop.reroll_unlocked(generate_weapon_offer)


func replace_shop_slot(slot_index: int) -> void:
	_ensure_weapon_shop()
	weapon_shop.replace_slot(slot_index, generate_weapon_offer)


func generate_weapon_offer() -> ShopOffer:
	var path := SPEAR_WEAPON_PATH if randf() < 0.5 else MELEE_WEAPON_PATH
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
