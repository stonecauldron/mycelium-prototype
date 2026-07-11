class_name DaySummaryFeed
extends RefCounted

## Pending end-of-day summary rows (text + optional range_class for icon color).
static var entries: Array[Dictionary] = []


static func clear() -> void:
	entries.clear()


static func add_entry(text: String, range_class: int = -1) -> void:
	entries.append({
		"text": text,
		"range_class": range_class,
	})


static func add_fallen_unit(unit: RosterUnitData) -> void:
	if unit == null:
		return
	add_entry(
		"%s has fallen" % unit.display_name,
		int(unit.get_range_class())
	)


static func take_entries() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	copy.assign(entries)
	entries.clear()
	return copy
