class_name BaseUndoSnapshot
extends RefCounted

## Restore live model objects in place, retaining signal connections and unit identity.
## Containers are copied; authored art, weapons, Seals and item definitions stay shared.
const _STATE_FIELDS: Array[StringName] = [
	&"pending_seal_choice", &"favourite_child_used_today",
	&"show_start_combat_hint", &"show_plot_harvest_hint", &"show_plot_plant_hint",
]
const _STOCK_SEQ := &"_nursery_stock_seq"

var action_name: String
var history_generation: int
var resource_events: Array[Dictionary] = []
var _state: Dictionary = {}
var _objects: Dictionary = {}
var _stock_sequences: Dictionary = {}


func capture() -> void:
	for field in _STATE_FIELDS:
		_state[field] = GameState.get(field)
	for model in [GameState.troop, GameState.nursery, GameState.pupation, GameState.biomass, GameState.seals]:
		_capture_object(model)


func matches_current_state() -> bool:
	for field in _state:
		if GameState.get(field) != _state[field]:
			return false
	for object: Object in _objects:
		var fields: Dictionary = _objects[object]
		for field in fields:
			if object.get(field) != fields[field]:
				return false
	for object: Object in _stock_sequences:
		if _stock_sequence(object) != _stock_sequences[object]:
			return false
	return true


func biomass_delta() -> int:
	return int(_objects[GameState.biomass][&"amount"]) - GameState.biomass.amount


func restore() -> void:
	# No observer may see a refunded balance before its associated items are restored.
	var biomass_signals_blocked := GameState.biomass.is_blocking_signals()
	GameState.biomass.set_block_signals(true)
	for object: Object in _objects:
		var fields: Dictionary = _objects[object]
		for field in fields:
			var saved: Variant = fields[field]
			var current: Variant = object.get(field)
			if saved is Array and current is Array:
				current.assign(saved.duplicate(true))
			else:
				object.set(field, _copy_value(saved))
	for object: Object in _stock_sequences:
		var sequence: Variant = _stock_sequences[object]
		if sequence == null:
			object.remove_meta(_STOCK_SEQ)
		else:
			object.set_meta(_STOCK_SEQ, sequence)
	for field in _state:
		GameState.set(field, _state[field])
	GameState.biomass.set_block_signals(biomass_signals_blocked)
	GameState.nursery.emit_changed()
	GameState.biomass.emit_changed()
	GameState.seals_changed.emit()


func _capture_object(object: Object) -> void:
	if object == null or _stock_sequences.has(object):
		return
	_stock_sequences[object] = _stock_sequence(object)
	if not _is_mutable_model(object):
		return
	var fields: Dictionary = {}
	_objects[object] = fields
	for property in object.get_property_list():
		var usage := int(property["usage"])
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			_capture_field(object, StringName(property["name"]), fields)
	# Resource duplication omits these non-exported run fields.
	if object is TroopData:
		_capture_field(object, &"_seeded", fields)
	elif object is NurseryData:
		for field in [&"_seeded", &"_first_spore_planted", &"first_lineage_spore", &"_next_stock_seq", &"_guided_shop_day"]:
			_capture_field(object, field, fields)
	elif object is RosterUnitData:
		_capture_field(object, &"last_death_biomass_yield", fields)
		_capture_field(object, &"emitted_death_spore", fields)
	elif object is SealsCollection:
		_capture_field(object, &"owned", fields)


func _capture_field(object: Object, field: StringName, fields: Dictionary) -> void:
	var value: Variant = object.get(field)
	fields[field] = _copy_value(value)
	_capture_references(value)


func _capture_references(value: Variant) -> void:
	if value is Resource or value is SealsCollection:
		_capture_object(value)
	elif value is Array:
		for entry in value:
			_capture_references(entry)
	elif value is Dictionary:
		for entry in value.values():
			_capture_references(entry)


static func _copy_value(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value


static func _stock_sequence(object: Object) -> Variant:
	return object.get_meta(_STOCK_SEQ) if object.has_meta(_STOCK_SEQ) else null


static func _is_mutable_model(object: Object) -> bool:
	return (
		object is TroopData or object is NurseryData or object is PupationData
		or object is BiomassData or object is RosterUnitData or object is UnitStatsData
		or object is NurseryPlotData or object is SporeData or object is StockInventory
		or object is ShopInventory or object is ShopOffer or object is SealsCollection
	)
