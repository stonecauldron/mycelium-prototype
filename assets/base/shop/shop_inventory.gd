class_name ShopInventory
extends Resource

## Number of offer slots this shop shows.
@export var slot_count: int = 4
## Persistent offers for the run. Each entry is a ShopOffer (or null when cleared).
@export var offers: Array[ShopOffer] = []


func clear() -> void:
	offers.clear()


## Fill empty inventory by calling generate_offer(slot_index) once per slot.
## Only fills when offers is completely empty (first fill). Growing slot_count
## extends with nulls — emptied slots are not auto-regenerated mid-visit.
## generate_offer must return a ShopOffer (unlocked; locked is forced false).
func ensure_filled(generate_offer: Callable) -> void:
	if not offers.is_empty():
		_normalize_size()
		return
	_fill_all(generate_offer)


## Reroll every empty slot and every unlocked non-locked slot.
## Locked filled slots keep their current offer.
## generate_offer must return a ShopOffer; receives the slot index.
func reroll_unlocked(generate_offer: Callable) -> void:
	_normalize_size()
	for i in offers.size():
		var current := offers[i]
		if current != null and current.locked and not current.is_empty():
			continue
		var next: ShopOffer = generate_offer.call(i) as ShopOffer
		if next == null:
			continue
		next.locked = false
		offers[i] = next


## Clear one slot after a purchase (no auto-regeneration).
func replace_slot(slot_index: int) -> void:
	_normalize_size()
	if slot_index < 0 or slot_index >= offers.size():
		return
	offers[slot_index] = null


func set_locked(slot_index: int, locked: bool) -> void:
	if slot_index < 0 or slot_index >= offers.size():
		return
	var offer := offers[slot_index]
	if offer == null or offer.is_empty():
		return
	offer.locked = locked


func toggle_locked(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= offers.size():
		return false
	var offer := offers[slot_index]
	if offer == null or offer.is_empty():
		return false
	offer.locked = not offer.locked
	return offer.locked


func is_locked(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= offers.size():
		return false
	var offer := offers[slot_index]
	return offer != null and not offer.is_empty() and offer.locked


func _fill_all(generate_offer: Callable) -> void:
	offers.clear()
	for i in slot_count:
		var offer: ShopOffer = generate_offer.call(i) as ShopOffer
		if offer == null:
			offer = ShopOffer.new()
		offer.locked = false
		offers.append(offer)


func _normalize_size() -> void:
	while offers.size() < slot_count:
		offers.append(null)
	if offers.size() > slot_count:
		offers.resize(slot_count)
