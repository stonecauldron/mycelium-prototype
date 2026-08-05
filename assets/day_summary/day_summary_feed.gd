class_name DaySummaryFeed
extends RefCounted

## Pending end-of-day summary rows.
## Keys: text, optional formation_line, optional unit, optional biomass, optional nursery_ready.
static var entries: Array[Dictionary] = []

## Left-column combat recap (separate from event entries).
static var troop_hp_current: int = 0
static var troop_hp_max: int = 0
## Rows: { unit: RosterUnitData, dealt: int, taken: int, max_hp: int, order: int }
static var unit_damage_rows: Array[Dictionary] = []


static func clear() -> void:
	entries.clear()
	troop_hp_current = 0
	troop_hp_max = 0
	unit_damage_rows.clear()


static func set_combat_recap(
	hp_current: int,
	hp_max: int,
	damage_rows: Array[Dictionary]
) -> void:
	troop_hp_current = maxi(hp_current, 0)
	troop_hp_max = maxi(hp_max, 0)
	unit_damage_rows.clear()
	unit_damage_rows.assign(damage_rows)


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
		"text": "%s has matured (+1 all STATS)." % unit.display_name,
		"formation_line": int(unit.get_formation_line()),
		"unit": unit,
	})


static func add_unit_emerged_from_pupation(unit: RosterUnitData, school: int) -> void:
	if unit == null:
		return
	var weapon_name := "a new form"
	if unit.weapon != null and not unit.weapon.display_name.is_empty():
		weapon_name = unit.weapon.display_name
	entries.append({
		"text": "%s emerged with %s (%s training)." % [
			unit.display_name,
			weapon_name,
			WeaponSchool.display_name(school),
		],
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
