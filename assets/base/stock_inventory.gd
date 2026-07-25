class_name StockInventory
extends Resource

## Fixed sparse inventory slots (null = empty). Shared by nursery and riboforge stock.

const DEFAULT_SLOT_COUNT := 5

@export var slot_count: int = DEFAULT_SLOT_COUNT
@export var slots: Array[Resource] = []


func clear() -> void:
	slots.clear()
	ensure_size()


func ensure_size() -> void:
	slot_count = maxi(slot_count, 1)
	if slots.is_empty():
		slots.resize(slot_count)
		slots.fill(null)
		return
	while slots.size() < slot_count:
		slots.append(null)
	if slots.size() > slot_count:
		slots.resize(slot_count)


func can_add() -> bool:
	return first_empty() >= 0


func first_empty() -> int:
	ensure_size()
	for i in slots.size():
		if slots[i] == null:
			return i
	return -1


func get_at(index: int) -> Resource:
	ensure_size()
	if index < 0 or index >= slots.size():
		return null
	return slots[index]


func set_at(index: int, item: Resource) -> bool:
	ensure_size()
	if index < 0 or index >= slots.size():
		return false
	slots[index] = item
	return true


## Places item in first empty slot (or `slot_index` if >= 0). Returns slot index, or -1.
func add(item: Resource, slot_index: int = -1) -> int:
	ensure_size()
	if item == null:
		return -1
	var dest := slot_index
	if dest < 0:
		dest = first_empty()
	if dest < 0 or dest >= slots.size() or slots[dest] != null:
		return -1
	slots[dest] = item
	return dest


## Move or swap between slots. Returns false if indices are invalid or source empty.
func move(from_index: int, to_index: int) -> bool:
	ensure_size()
	if from_index < 0 or from_index >= slots.size():
		return false
	if to_index < 0 or to_index >= slots.size():
		return false
	if from_index == to_index:
		return false
	if slots[from_index] == null:
		return false
	var moving := slots[from_index]
	slots[from_index] = slots[to_index]
	slots[to_index] = moving
	return true


func clear_slot(index: int) -> Resource:
	ensure_size()
	if index < 0 or index >= slots.size():
		return null
	var item := slots[index]
	slots[index] = null
	return item


## Configure DropSlots: always accept stock rearrange types; intake types only when not full.
static func configure_drop_slots(
	drop_slots: Array[DropSlot],
	stock_drag_types: PackedStringArray,
	intake_drag_types: PackedStringArray,
	accept_intake: bool
) -> void:
	var types := stock_drag_types.duplicate()
	if accept_intake:
		for drag_type in intake_drag_types:
			types.append(drag_type)
	for slot in drop_slots:
		slot.accepted_drag_types = types
		slot.accepts_drops = true


## If `data` is a stock rearrange drag, move/swap into `to_index` and return true (drop consumed).
static func consume_stock_rearrange(
	inventory: StockInventory,
	data: Dictionary,
	to_index: int,
	stock_drag_types: PackedStringArray
) -> bool:
	if inventory == null:
		return false
	var drop_type := str(data.get("type", ""))
	if drop_type not in stock_drag_types:
		return false
	inventory.move(int(data.get("stock_index", -1)), to_index)
	return true
