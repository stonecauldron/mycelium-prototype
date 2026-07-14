class_name DaySummaryFeed
extends RefCounted

## Pending end-of-day summary rows.
## Keys: text, optional range_class, optional unit, optional biomass.
static var entries: Array[Dictionary] = []


static func clear() -> void:
	entries.clear()


static func add_entry(text: String, range_class: int = -1) -> void:
	entries.append({
		"text": text,
		"range_class": range_class,
	})


static func add_base_unlock(feature_name: String) -> void:
	var trimmed := feature_name.strip_edges()
	if trimmed.is_empty():
		return
	add_entry("%s unlocked" % trimmed)


static func add_fallen_unit(unit: RosterUnitData) -> void:
	if unit == null:
		return
	entries.append({
		"text": "%s has fallen" % unit.display_name,
		"range_class": int(unit.get_range_class()),
		"unit": unit,
	})


static func add_nursery_matured(spore_name: String, plot_index: int) -> void:
	add_entry("%s matured in plot %d" % [spore_name, plot_index + 1])


static func add_biomass_earned(amount: int) -> void:
	if amount <= 0:
		return
	entries.append({
		"text": "+%d kg" % amount,
		"biomass": true,
	})


static func take_entries() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	copy.assign(entries)
	entries.clear()
	return copy
