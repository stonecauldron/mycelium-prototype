class_name BaseUndoHistory
extends RefCounted

signal changed()
signal restored()

var _active: bool = false
var _generation: int = 0
var _steps: Array[BaseUndoSnapshot] = []
var _pending_snapshot: WeakRef = null


func begin_visit() -> void:
	_active = true
	clear()


func end_visit() -> void:
	_active = false
	clear()


## Successful rerolls are barriers, including their cost and price increase.
func clear() -> void:
	_generation += 1
	_steps.clear()
	_pending_snapshot = null
	changed.emit()


func capture(action_name: String) -> BaseUndoSnapshot:
	_pending_snapshot = null
	if not _active:
		return null
	var snapshot := BaseUndoSnapshot.new()
	snapshot.action_name = action_name
	snapshot.history_generation = _generation
	snapshot.capture()
	# Failed actions release their local snapshot without retaining an open transaction.
	_pending_snapshot = weakref(snapshot)
	return snapshot


func record(snapshot: BaseUndoSnapshot) -> void:
	_pending_snapshot = null
	if not _active or snapshot == null or snapshot.history_generation != _generation:
		return
	if snapshot.matches_current_state():
		return
	_steps.append(snapshot)
	changed.emit()


## Called only for resource events that Analytics actually sends.
func note_resource_event(flow: String, item_type: String, item_id: String, amount: int) -> void:
	if not _active or _pending_snapshot == null:
		return
	var snapshot := _pending_snapshot.get_ref() as BaseUndoSnapshot
	if snapshot == null or snapshot.history_generation != _generation:
		return
	snapshot.resource_events.append({
		"flow": flow,
		"item_type": item_type,
		"item_id": item_id,
		"amount": amount,
	})


func can_undo() -> bool:
	return _active and not _steps.is_empty()


func next_action_name() -> String:
	return _steps.back().action_name if can_undo() else ""


func next_biomass_delta() -> int:
	return _steps.back().biomass_delta() if can_undo() else 0


func undo() -> bool:
	if not can_undo():
		return false
	var snapshot: BaseUndoSnapshot = _steps.pop_back()
	_pending_snapshot = null
	snapshot.restore()
	_pending_snapshot = null
	for event in snapshot.resource_events:
		if event["flow"] == "sink":
			Analytics.biomass_source(event["item_type"], event["item_id"], event["amount"])
		else:
			Analytics.biomass_sink(event["item_type"], event["item_id"], event["amount"])
	restored.emit()
	changed.emit()
	return true
