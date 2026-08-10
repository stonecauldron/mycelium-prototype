class_name DaySummaryFeed
extends RefCounted

## Pending end-of-day summary rows.
## Keys: text, optional formation_line, optional unit, optional biomass, optional nursery_ready,
## optional emitted_spores + spore_tint.
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


static func add_fallen_unit(
	unit: RosterUnitData,
	context: MutationEffect.DeathContext = MutationEffect.DeathContext.COMBAT
) -> void:
	if unit == null:
		return
	var emitted := unit.emitted_death_spore
	var text: String
	if unit.last_death_biomass_yield > 0:
		text = "%s died and yielded %d kg of biomass" % [
			unit.display_name,
			unit.last_death_biomass_yield,
		]
	elif emitted:
		if context == MutationEffect.DeathContext.AGED_OUT:
			text = "%s has died of old age and emitted spores" % unit.display_name
		else:
			text = "%s has died and emitted spores" % unit.display_name
	else:
		text = "%s has fallen" % unit.display_name
	var entry := {
		"text": text,
		"formation_line": int(unit.get_formation_line()),
		"unit": unit,
		"emitted_spores": emitted,
	}
	if emitted:
		entry["spore_tint"] = UnitStatsData.tint_for_tier(unit.power_tier)
		if unit.cap_mutation != null and unit.cap_mutation.tint != Color.WHITE:
			entry["spore_tint"] = unit.cap_mutation.tint
		elif unit.body_mutation != null and unit.body_mutation.tint != Color.WHITE:
			entry["spore_tint"] = unit.body_mutation.tint
	entries.append(entry)


static func add_unit_became_imago(unit: RosterUnitData) -> void:
	if unit == null:
		return
	var bonus := unit.maturity_stat_bonus()
	var text: String
	if bonus > 0:
		text = "%s has matured (+%d all STATS)." % [unit.display_name, bonus]
	elif bonus < 0:
		text = "%s has matured (%d all STATS)." % [unit.display_name, bonus]
	else:
		text = "%s has matured." % unit.display_name
	entries.append({
		"text": text,
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
