extends Node

## Integration checks use actual combat scenes and result buttons. Balance samples
## use the same combat simulation, authored enemies and normal Training Stat rules.
const COMBAT := "res://assets/combat/combat_stage/combat_stage.tscn"
const SUMMARY := "res://assets/day_summary/day_summary.tscn"
const BASE := "res://assets/base/base.tscn"
const VICTORY := "res://assets/victory/victory.tscn"

var _failures := 0
var _checks := 0
var _state: Node
var _settings: Node
var _settings_existed := false
var _settings_bytes := PackedByteArray()
var _simulation_done := false
var _simulation_won := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	get_tree().current_scene = null # Keep the test runner alive across real scene changes.
	_state = get_tree().root.get_node("GameState")
	_settings = get_tree().root.get_node("SettingsServer")
	get_tree().root.get_node("Analytics").set("ga", null)
	_settings_existed = FileAccess.file_exists("user://settings.cfg")
	if _settings_existed:
		_settings_bytes = FileAccess.get_file_as_bytes("user://settings.cfg")
	print("SETTINGS_BACKUP_PATH ", ProjectSettings.globalize_path("user://settings.cfg"))
	await _check_defeat_retries()
	await _check_victory_continue()
	await _check_ordinary_nursery_summary()
	await _sample_balance()
	_state.reset_run(false)
	# Let one-shot combat timers finish after their owning stage exits.
	await get_tree().create_timer(2.1).timeout
	_restore_settings_file()
	print("Guided combat checks: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check_defeat_retries() -> void:
	for day in [1, 5, 10, 15]:
		await _prepare_day(day)
		var expected_balance: int = _state.biomass.amount
		var expected_preference: bool = _settings.guided_run_enabled
		var expected_history: bool = _settings.guided_run_ended
		await _launch_battle()
		for attempt in 2:
			_wipe_side(get_tree().current_scene, true)
			if not await _wait_for_scene(SUMMARY):
				return
			_expect(_state.current_day == day - 1, "Defeat keeps Day %d" % day)
			_expect(_state.is_guided_run, "Defeat keeps guided mode")
			_expect(_settings.guided_run_enabled == expected_preference, "Defeat keeps next-Run preference")
			_expect(_settings.guided_run_ended == expected_history, "Defeat does not record terminal history")
			_expect(not get_tree().current_scene.get_node("%ContinueButton").visible, "Defeat cannot continue to next Day")
			_check_unlock_panel(day + 1, {})
			var restart: Button = get_tree().current_scene.get_node("%RestartButton")
			_expect(restart.visible and not restart.disabled, "Restart remains available after loss %d" % (attempt + 1))
			restart.pressed.emit()
			if not await _wait_for_scene(COMBAT):
				return
			_expect(_state.biomass.amount == expected_balance, "Restart restores precombat biomass")
			_expect(_state.troop.squad_unit_count() > 0, "Restart restores fallen Units")
			_expect(not DaySummaryFeed.guided_result, "Restart clears stale result")
			_expect(DaySummaryFeed.entries.is_empty(), "Restart clears pending summary entries")
		_wipe_side(get_tree().current_scene, true)
		if not await _wait_for_scene(SUMMARY):
			return
		get_tree().current_scene.get_node("%PreparationButton").pressed.emit()
		if not await _wait_for_scene(BASE):
			return
		_expect(_state.current_day == day - 1, "Change preparation keeps Day %d" % day)
		_expect(_state.biomass.amount == expected_balance, "Change preparation restores this Day's spending")
		_expect(is_equal_approx(Engine.time_scale, 1.0), "Base returns to normal engine timing")
	print("PASS: regular and elite defeats remain repeatable")


func _check_victory_continue() -> void:
	for day in [1, 3, 5, 7, 8, 9, 10, 11, 12]:
		await _prepare_day(day)
		await _launch_battle()
		_wipe_side(get_tree().current_scene, false)
		if not await _wait_for_scene(SUMMARY):
			return
		_expect(_state.current_day == day, "Victory advances preparation after Day %d" % day)
		_expect(not _state.has_won_run(), "Victory before Day 15 does not finish the guided Run")
		_check_victory_controls()
		match day:
			1:
				_check_unlock_panel(2, {"school_3": "Bow Training"})
			3:
				_check_unlock_panel(4, {"school_4": "Mace Training", "progression": "Daily progression"})
			5:
				_check_unlock_panel(6, {"nursery": "Nursery"})
				_expect(_summary_label_count("Nursery unlocked") == 0, "Guided Nursery card replaces the legacy Nursery message")
			7:
				_check_unlock_panel(8, {"school_1": "Shield Training", "mutations": "Thorny Mutation"})
			8:
				_check_unlock_panel(9, {"squad_slots": "Squad expansion", "plot_slots": "Plot expansion"})
			9:
				_check_unlock_panel(10, {})
			10:
				_check_unlock_panel(11, {"compost": "Compost", "seals": "Seals"})
			11:
				_check_unlock_panel(12, {"full_shop": "Full Shop"})
			12:
				_check_unlock_panel(13, {"school_2": "Spear Training", "full_seal_pool": "Full Seal pool"})
		get_tree().current_scene.get_node("%ContinueButton").pressed.emit()
		if not await _wait_for_scene(BASE):
			return
		_expect(_state.get_upcoming_day() == day + 1, "Continue enters the next preparation Day")
		_expect(not DaySummaryFeed.guided_result and DaySummaryFeed.entries.is_empty(), "Continue clears consumed result metadata and unlock entries")
		if day == 10:
			_expect(_state.pending_seal_choice, "Day 11 receives its first Seal")
		elif day == 11:
			_expect(not _state.pending_seal_choice, "Day 12 does not receive a second Seal")
		elif day == 12:
			_expect(_state.pending_seal_choice, "Day 13 receives its second Seal")
	await _prepare_day(15)
	var ended_before: bool = _settings.guided_run_ended
	var completed_before: bool = _settings.guided_run_completed
	await _launch_battle()
	_wipe_side(get_tree().current_scene, false)
	if not await _wait_for_scene(SUMMARY):
		return
	_expect(_state.has_won_run(), "Battle 15 reaches the guided victory threshold")
	_expect(_settings.guided_run_ended == ended_before, "Final result waits for Continue before ending the Run")
	_expect(_settings.guided_run_completed == completed_before, "Final result waits for Continue before recording completion")
	_check_victory_controls()
	_check_unlock_panel(16, {})
	get_tree().current_scene.get_node("%ContinueButton").pressed.emit()
	if not await _wait_for_scene(VICTORY):
		return
	_expect(_settings.guided_run_ended and _settings.guided_run_completed, "Accepting final victory records completion")
	print("PASS: regular and final victories show only Continue; Day 10 continues to Day 11")


func _check_ordinary_nursery_summary() -> void:
	await _clear_scene()
	_state.reset_run(false)
	var starters: Array[RosterUnitData] = [GuidedRun.make_starter(true)]
	_state.troop.seed_if_empty(starters)
	_state.ensure_seal_choice_offers()
	_expect(_state.try_add_seal(_state.seal_choice_offers[0]), "Ordinary opening Seal can be selected")
	_state.clear_pending_seal_choice()
	_state.combat_fast_forward = 4
	await _launch_battle()
	_wipe_side(get_tree().current_scene, false)
	if not await _wait_for_scene(SUMMARY):
		return
	_check_unlock_panel(2, {})
	_expect(_summary_label_count("Nursery unlocked") == 1, "Ordinary first victory retains exactly one legacy Nursery message")
	_expect(not DaySummaryFeed.guided_result, "Ordinary summary keeps its existing result mode")
	get_tree().current_scene.get_node("%ContinueButton").pressed.emit()
	if not await _wait_for_scene(BASE):
		return
	_expect(_state.get_upcoming_day() == 2 and _state.is_nursery_unlocked(), "Ordinary Continue still enters the newly unlocked Nursery Day")


func _check_unlock_panel(day: int, expected: Dictionary) -> void:
	var entries: VBoxContainer = get_tree().current_scene.get_node("%Entries")
	var panel := entries.get_node_or_null("DailyUnlocks")
	_expect(DaySummaryFeed.entries.is_empty(), "Summary consumes pending entries once")
	if expected.is_empty():
		_expect(panel == null, "No unlock panel when this result grants no new system")
		return
	_expect(panel != null, "Victory displays newly available systems for Day %d" % day)
	if panel == null:
		return
	var heading := panel.find_child("UnlockHeading", true, false) as Label
	_expect(heading != null and heading.text == "Unlocked for Day %d" % day, "Unlock heading names the next preparation Day")
	_expect(panel.find_children("Unlock_*", "HBoxContainer", true, false).size() == expected.size(), "Unlock panel contains only the newly introduced systems")
	for id: String in expected:
		var row := panel.find_child("Unlock_%s" % id, true, false)
		_expect(row != null, "Unlock panel includes %s" % id)
		if row == null:
			continue
		var labels := row.find_children("*", "Label", false, false)
		_expect(labels.size() == 1 and (labels[0] as Label).text == expected[id], "Unlock row names %s" % expected[id])


func _summary_label_count(text: String) -> int:
	var count := 0
	for label: Label in get_tree().current_scene.get_node("%Entries").find_children("*", "Label", true, false):
		if label.text == text:
			count += 1
	return count


func _check_victory_controls() -> void:
	var summary := get_tree().current_scene
	var day_before: int = _state.current_day
	var continue_button: Button = summary.get_node("%ContinueButton")
	_expect(continue_button.visible and not continue_button.disabled, "Victory presents the normal Continue action")
	_expect(continue_button.text.to_lower() == "continue", "Final and regular victories retain the normal Continue label")
	_expect(summary.get_node_or_null("%RetryHelp") == null, "Victory has no retry explanation text")
	for button_name in ["RestartButton", "PreparationButton", "EndRunButton"]:
		var button: Button = summary.get_node("%" + button_name)
		_expect(not button.visible, "Victory hides %s" % button_name)
		button.pressed.emit()
		_expect(_state.current_day == day_before, "Hidden %s cannot change the Run" % button_name)
		_expect(not get_tree().root.get_node("SceneTransition").is_transitioning(), "Hidden %s cannot leave victory" % button_name)


func _prepare_day(day: int) -> void:
	await _clear_scene()
	_state.reset_run(true)
	_state.run_seed = 90210
	_state.current_day = day - 1
	_state.clear_upcoming_enemy_formation()
	_state.ensure_guided_preparation()
	_state.maybe_queue_seal_choice()
	_state.ensure_guided_preparation_checkpoint()
	if _state.pending_seal_choice:
		_state.ensure_seal_choice_offers()
		_expect(_state.try_add_seal(_state.seal_choice_offers[0]), "Scheduled Seal can be selected before Battle")
		_state.clear_pending_seal_choice()
	_state.combat_fast_forward = 4


func _launch_battle() -> void:
	var enemies: Array[RosterUnitData] = _state.make_upcoming_enemy_roster()
	_state.capture_guided_battle_checkpoint(enemies)
	BattleLaunch.set_enemy_roster(enemies)
	get_tree().change_scene_to_file(COMBAT)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame


func _wipe_side(stage: Node, player: bool) -> void:
	var troop: Node = stage.get_node("World/PlayerTroop" if player else "World/EnemyTroop")
	for unit: Unit in troop.get_living_units():
		unit.take_damage(100000, unit.global_position, 0.0, null, WeaponData.DamageType.BLUNT)


func _wait_for_scene(path: String) -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path:
			if not get_tree().root.get_node("SceneTransition").is_transitioning():
				return true
	_expect(false, "Scene transition reaches %s" % path)
	return false


func _clear_scene() -> void:
	while get_tree().root.get_node("SceneTransition").is_transitioning():
		await get_tree().process_frame
	if get_tree().current_scene != null:
		var previous := get_tree().current_scene
		get_tree().current_scene = null
		previous.queue_free()
	await get_tree().process_frame


func _sample_balance() -> void:
	await _clear_scene()
	for day in [1, 5, 10, 15]:
		for use_mace in ([false] if day == 1 else [false, true]):
			_state.reset_run(true)
			_state.run_seed = 90210
			_state.current_day = day - 1
			_state.clear_upcoming_enemy_formation()
			_state.ensure_guided_preparation()
			_state.combat_fast_forward = 4
			var roster := _balance_roster(day, use_mace)
			_state.troop.reset()
			_state.troop.seed_if_empty(roster)
			if day == 15:
				for seal in GuidedRun.SEALS:
					_state.seals.add(seal)
			var enemies: Array[RosterUnitData] = _state.make_upcoming_enemy_roster()
			_simulation_done = false
			var stage: Node = load(COMBAT).instantiate()
			get_tree().root.add_child(stage) # A non-current stage uses the production sandbox path.
			stage.battle_ended.connect(_on_simulation_ended)
			stage.start_battle(roster, enemies)
			var deadline := Time.get_ticks_msec() + 30000
			while not _simulation_done and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
			_expect(_simulation_done, "Authored Day %d simulation resolves" % day)
			print("BALANCE day=%d mace=%s won=%s elapsed=%.2f player_hp=%d enemy_hp=%d" % [
				day, use_mace, _simulation_won, stage.get("_battle_elapsed_sec"),
				stage.call("_sum_troop_current_hp", stage.get_node("World/PlayerTroop")),
				stage.call("_sum_troop_current_hp", stage.get_node("World/EnemyTroop")),
			])
			if day == 1:
				_expect(_simulation_won, "Fixed Day-1 starter can beat its authored army")
			stage.queue_free()
			await get_tree().process_frame


func _balance_roster(day: int, use_mace: bool) -> Array[RosterUnitData]:
	var starter := GuidedRun.make_starter(true)
	if day == 1:
		return [starter]
	# Normal Child Evolution Stat deltas; Adult combos never add extra Stats.
	starter.apply_pupation_training(WeaponSchool.Id.MACE if use_mace else WeaponSchool.Id.SWORD)
	var bow := GuidedRun.make_starter(false)
	bow.apply_pupation_training(WeaponSchool.Id.BOW)
	var roster: Array[RosterUnitData] = [bow, starter]
	if day >= 10:
		var second_melee := GuidedRun.make_starter(false)
		second_melee.apply_pupation_training(WeaponSchool.Id.SWORD)
		second_melee.apply_pupation_training(WeaponSchool.Id.MACE if use_mace else WeaponSchool.Id.SWORD)
		var second_bow := GuidedRun.make_starter(false)
		second_bow.apply_pupation_training(WeaponSchool.Id.BOW)
		roster = [bow, second_bow, second_melee, starter]
	return roster


func _on_simulation_ended(won: bool) -> void:
	_simulation_done = true
	_simulation_won = won


func _restore_settings_file() -> void:
	if _settings_existed:
		var file := FileAccess.open("user://settings.cfg", FileAccess.WRITE)
		file.store_buffer(_settings_bytes)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
