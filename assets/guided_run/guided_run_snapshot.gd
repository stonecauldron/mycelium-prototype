class_name GuidedRunSnapshot
extends BaseUndoSnapshot

## Battle checkpoints extend the existing identity-preserving model snapshot.
const RUN_FIELDS: Array[StringName] = [
	&"current_day", &"run_seed", &"upcoming_enemy_formation", &"scout_rerolls_today",
	&"prefer_nursery_tab", &"pending_cocoon_emergences", &"seal_choice_offers",
	&"seal_rerolls_this_pick", &"_seal_choice_queued_day", &"_guided_child_revealed",
	&"_guided_preparation_day", &"_guided_enemy_day", &"_guided_enemy_roster",
]
var day: int = 0
var _run_state: Dictionary = {}
var _bark_state: Dictionary = {}
var enemy_roster: Array[RosterUnitData] = []


func capture() -> void:
	day = GameState.current_day
	super.capture()
	for field in RUN_FIELDS:
		var value: Variant = GameState.get(field)
		_run_state[field] = _copy_value(value)
		_capture_references(value)
	for enemy in enemy_roster:
		_capture_object(enemy)
	for field in [&"_remaining", &"_last_lines", &"last_reaction_speaker"]:
		_bark_state[field] = _copy_value(GameState.barks.get(field))
	_bark_state[&"rng_state"] = GameState.barks.rng.state


func restore() -> void:
	for field in _run_state:
		GameState.set(field, _copy_value(_run_state[field]))
	for field in [&"_remaining", &"_last_lines", &"last_reaction_speaker"]:
		GameState.barks.set(field, _copy_value(_bark_state[field]))
	GameState.barks.rng.state = int(_bark_state[&"rng_state"])
	super.restore()
	GameState.base_undo.end_visit()
	DaySummaryFeed.clear()
	BattleLaunch.enemy_roster.clear()
