class_name ShopOffer
extends Resource

## Biomass cost to purchase this offer.
@export var cost: int = 0
## When true, rerolls skip this slot.
@export var locked: bool = false
## Opaque product for the owning shop (SporeData, WeaponData, etc.).
@export var item: Resource
