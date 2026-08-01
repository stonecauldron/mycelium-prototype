class_name DaySummaryFeed
extends RefCounted

## Pending end-of-day summary rows.
## Keys: text, optional formation_line, optional unit, optional biomass, optional nursery_ready.
static var entries: Array[Dictionary] = []


static func clear() -> void:
	entries.clear()


static func add_entry(text: String, formation_line: int = -1) -> void:
	entries.append({
		"text": text,
		"formation_line": formation_line,
	})


static func add_base_unlock(feature_name: String) -> void:
	var trimmed := feature_name.strip_edges()
	if trimmed.is_empty():
		return
	add_entry("%s unlocked" % trimmed)


static func add_fallen_unit(unit: RosterUnitData) -> void:
	if unit == null:
		return
	var text: String
	if unit.last_death_biomass_yield > 0:
		text = "%s died and yielded %d kg of biomass" % [
			unit.display_name,
			unit.last_death_biomass_yield,
		]
	else:
		text = "%s has fallen" % unit.display_name
	entries.append({
		"text": text,
		"formation_line": int(unit.get_formation_line()),
		"unit": unit,
	})


static func add_unit_became_imago(unit: RosterUnitData) -> void:
	if unit == null:
		return
	entries.append({
		"text": "%s has matured (+2 all STATS)." % unit.display_name,
		"formation_line": int(unit.get_formation_line()),
		"unit": unit,
	})


static func add_nursery_matured(
	spore_name: String,
	plot_index: int,
	tint: Color = Color.WHITE,
	as_imago: bool = false,
) -> void:
	entries.append({
		"text": "%s matured in plot %d" % [spore_name, plot_index + 1],
		"nursery_ready": true,
		"tint": tint,
		"as_imago": as_imago,
	})


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
