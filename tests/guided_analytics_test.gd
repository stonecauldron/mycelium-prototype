extends Node

## Public Run lifecycle events with a local GameAnalytics collector.
## Run: godot --headless --path . res://tests/guided_analytics_test.tscn
class EventCollector:
	extends RefCounted
	var resources: Array[Dictionary] = []
	var designs: Array[String] = []
	var progression: Array[Dictionary] = []

	func addResourceEvent(flow: String, _currency: String, amount: float, item_type: String, item_id: String, _options: Dictionary) -> void:
		resources.append({"flow": flow, "amount": int(amount), "item_type": item_type, "item_id": item_id})

	func addDesignEvent(event_id: String, _options: Dictionary) -> void:
		designs.append(event_id)

	func addProgressionEvent(status: String, one: String, two: String, _three: String, _options: Dictionary) -> void:
		progression.append({"status": status, "one": one, "two": two})

	func addProgressionEventWithScore(status: String, one: String, two: String, _three: String, _score: int) -> void:
		progression.append({"status": status, "one": one, "two": two})

	func clear() -> void:
		resources.clear()
		designs.clear()
		progression.clear()


var _failures := 0
var _checks := 0
var _collector := EventCollector.new()
var _settings_existed := false
var _settings_bytes := PackedByteArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_settings_existed = FileAccess.file_exists(SettingsServer.PATH)
	if _settings_existed:
		_settings_bytes = FileAccess.get_file_as_bytes(SettingsServer.PATH)
	Analytics.ga = _collector
	_test_ordinary_unchanged()
	_test_guided_actions_are_excluded()
	_test_guided_terminal_day()
	_test_window_close()
	Analytics.ga = null
	if _settings_existed:
		var file := FileAccess.open(SettingsServer.PATH, FileAccess.WRITE)
		file.store_buffer(_settings_bytes)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SettingsServer.PATH))
	print("Guided analytics checks: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_ordinary_unchanged() -> void:
	GameState.reset_run(false)
	GameState.troop.seed_if_empty([GuidedRun.make_starter(true)])
	Analytics.maybe_start_day()
	Analytics.day_complete()
	Analytics.run_complete()
	Analytics.biomass_sink("Training", "Bow", 3)
	Analytics.intent("title", "base")
	_expect(_collector.progression.size() == 4, "Ordinary Run and Day progression still send")
	_expect(_collector.progression[0]["one"] == "run", "Ordinary progression root remains run")
	_expect(_collector.progression[1]["one"] == "day", "Ordinary progression root remains day")
	_expect(_collector.resources.size() == 2, "Ordinary starting grant and spending still send")
	_expect(_collector.designs == ["intent:title:base"], "Ordinary intent events stay unchanged")


func _test_guided_actions_are_excluded() -> void:
	_collector.clear()
	GameState.reset_run(true)
	_expect(_collector.designs == ["guided:run:start"], "Guided Run sends its explicit start event")
	while GameState.get_upcoming_day() < 7:
		GameState.debug_advance_day()
	GameState.biomass.add(40)
	GameState.ensure_guided_preparation_checkpoint()
	GameState.base_undo.begin_visit()
	var child: RosterUnitData = GameState.troop.squad[1]
	var undo := GameState.base_undo.capture("Train")
	_expect(GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.BOW), "Guided preparation still spends normally")
	GameState.base_undo.record(undo)
	_expect(GameState.base_undo.undo(), "Guided Base Undo still works")
	_expect(GameState.try_plant_fresh_common(0), "Guided Nursery still works")
	GameState.capture_guided_battle_checkpoint(GameState.make_upcoming_enemy_roster())
	GameState.biomass.add(20)
	Analytics.biomass_source("Battle", "Reward", 20)
	Analytics.note_hit_biomass(4)
	Analytics.flush_hit_biomass()
	Analytics.maybe_start_day()
	Analytics.day_complete()
	Analytics.day_fail()
	Analytics.run_complete()
	Analytics.run_fail()
	Analytics.intent("title", "base")
	Analytics.intent("quit", "combat")
	Analytics.intent("feedback", "victory")
	_expect(GameState.restart_guided_battle(), "Guided battle retry still restores")
	_expect(GameState.restore_guided_preparation(), "Guided preparation retry still restores")
	_expect(_collector.resources.is_empty(), "All guided Resource events are excluded")
	_expect(_collector.progression.is_empty(), "All guided Run and Day progression is excluded")
	_expect(_collector.designs == ["guided:run:start"], "Actions, battles and retries add no guided events")
	GameState.finish_run()
	GameState.finish_run(true)
	_expect(_collector.designs == ["guided:run:start", "guided:run:quit:7"], "Preparation exit reports reached Day once")


func _test_guided_terminal_day() -> void:
	_collector.clear()
	GameState.reset_run(true)
	GameState.current_day = 9
	DaySummaryFeed.set_guided_result(true, 9)
	GameState.finish_run()
	_expect(_collector.designs == ["guided:run:start", "guided:run:quit:9"], "Quitting a victory awaiting Continue reports its Battle, not next Day")
	_collector.clear()
	GameState.reset_run(true)
	GameState.current_day = 9
	GameState.finish_run()
	_expect(_collector.designs == ["guided:run:start", "guided:run:quit:10"], "After accepting victory the next preparation Day is reported")
	_collector.clear()
	GameState.reset_run(true)
	GameState.current_day = 10
	GameState.finish_run(true)
	GameState.finish_run()
	_expect(_collector.designs == ["guided:run:start", "guided:run:complete:10"], "Final completion is clamped to Day 10 and emitted once")
	Analytics.intent("wishlist", "title")
	_expect(_collector.designs.back() == "intent:wishlist:title", "Unrelated Title analytics remain available after guided mode")


func _test_window_close() -> void:
	_collector.clear()
	GameState.reset_run(true)
	GameState.current_day = 9
	Analytics.request_quit("combat")
	Analytics.request_quit("combat")
	_expect(_collector.designs == ["guided:run:start", "guided:run:quit:10"], "App/window quit reports reached Day exactly once")
	_expect(_collector.resources.is_empty() and _collector.progression.is_empty(), "Window quit does not leak ordinary analytics")


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
