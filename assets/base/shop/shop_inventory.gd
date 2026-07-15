class_name ShopInventory
extends Resource

## Number of offer slots this shop shows.
@export var slot_count: int = 3
## Persistent offers for the run. Each entry is a ShopOffer.
@export var offers: Array[ShopOffer] = []


func clear() -> void:
	offers.clear()


## Fill empty inventory by calling generate_offer() once per slot.
## generate_offer must return a ShopOffer (unlocked; locked is forced false).
func ensure_filled(generate_offer: Callable) -> void:
	if not offers.is_empty():
		_normalize_size(generate_offer)
		return
	_fill_all(generate_offer)


## Reroll every unlocked slot. Locked slots keep their current offer.
## generate_offer must return a ShopOffer.
func reroll_unlocked(generate_offer: Callable) -> void:
	ensure_filled(generate_offer)
	for i in offers.size():
		var current := offers[i]
		if current != null and current.locked:
			continue
		var was_locked := current != null and current.locked
		var next: ShopOffer = generate_offer.call() as ShopOffer
		if next == null:
			continue
		next.locked = was_locked
		offers[i] = next


## Replace one slot after a purchase. Always rolls a fresh unlocked offer.
func replace_slot(slot_index: int, generate_offer: Callable) -> void:
	ensure_filled(generate_offer)
	if slot_index < 0 or slot_index >= offers.size():
		return
	var next: ShopOffer = generate_offer.call() as ShopOffer
	if next == null:
		next = ShopOffer.new()
	next.locked = false
	offers[slot_index] = next


func set_locked(slot_index: int, locked: bool) -> void:
	if slot_index < 0 or slot_index >= offers.size():
		return
	var offer := offers[slot_index]
	if offer == null:
		return
	offer.locked = locked


func toggle_locked(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= offers.size():
		return false
	var offer := offers[slot_index]
	if offer == null:
		return false
	offer.locked = not offer.locked
	return offer.locked


func is_locked(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= offers.size():
		return false
	var offer := offers[slot_index]
	return offer != null and offer.locked


func _fill_all(generate_offer: Callable) -> void:
	offers.clear()
	for _i in slot_count:
		var offer: ShopOffer = generate_offer.call() as ShopOffer
		if offer == null:
			offer = ShopOffer.new()
		offer.locked = false
		offers.append(offer)


func _normalize_size(generate_offer: Callable) -> void:
	while offers.size() < slot_count:
		var offer: ShopOffer = generate_offer.call() as ShopOffer
		if offer == null:
			offer = ShopOffer.new()
		offer.locked = false
		offers.append(offer)
	if offers.size() > slot_count:
		offers.resize(slot_count)
