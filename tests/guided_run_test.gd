extends Node

## Public Run lifecycle checks. Run: godot --headless --path . res://tests/guided_run_test.tscn
var _failures: int = 0
var _checks: int = 0
var _settings_existed: bool = false
var _settings_bytes := PackedByteArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	Analytics.ga = null
	_settings_existed = FileAccess.file_exists(SettingsServer.PATH)
	if _settings_existed:
		_settings_bytes = FileAccess.get_file_as_bytes(SettingsServer.PATH)
	_test_mode_and_unlocks()
	_test_late_nursery_and_offers()
	_test_battle_and_preparation_restore()
	_test_compost_and_lineage_restore()
	_test_seal_restore()
	_test_terminal_preference()
	if _settings_existed:
		var file := FileAccess.open(SettingsServer.PATH, FileAccess.WRITE)
		file.store_buffer(_settings_bytes)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SettingsServer.PATH))
	print("Guided Run checks: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_mode_and_unlocks() -> void:
	SettingsServer.set_guided_run_enabled(false)
	GameState.reset_run()
	_expect(not GameState.is_guided_run, "New Run respects an immediate opt-out")
	SettingsServer.set_guided_run_enabled(true)
	GameState.reset_run()
	_expect(GameState.is_guided_run, "New Run uses the selected guided mode")
	GameState.reset_run(true)
	_expect(GameState.get_run_length() == 15, "Guided Run lasts 15 Days")
	_expect(GameState.troop.living_unit_count() == 1, "Opening has one fixed Adult")
	_expect(GameState.troop.get_squad_roster()[0].weapon_trainings == [WeaponSchool.Id.SWORD], "Opening Adult has Sword only")
	_expect(GameState.troop.get_squad_roster()[0].generation == 2, "Starter Adult uses normal Generation II")
	_expect(not GameState.pending_seal_choice, "Opening has no Seal gate")
	_expect(not GameState.is_nursery_unlocked(), "Nursery initially hidden")
	_expect(not GameState.try_plant_fresh_common(0), "Hidden Nursery rejects planting")
	_expect(not GameState.is_school_available(WeaponSchool.Id.SWORD), "No Training school on Day 1")
	for day in range(2, 16):
		GameState.debug_advance_day()
		_expect(GameState.get_upcoming_day() == day, "Day advances without tutorial actions: %d" % day)
		_expect(GameState.is_school_available(WeaponSchool.Id.BOW), "Bow stays available from Day 2")
		_expect(GameState.is_school_available(WeaponSchool.Id.SWORD) == (day >= 3), "Sword schedule")
		_expect(GameState.is_school_available(WeaponSchool.Id.MACE) == (day >= 5), "Mace schedule")
		_expect(not GameState.is_school_available(WeaponSchool.Id.SHIELD), "Shield stays hidden")
		_expect(GameState.is_feature_available(&"progression") == (day >= 4), "Progression schedule")
		_expect(GameState.is_nursery_unlocked() == (day >= 6), "Nursery schedule")
		_expect(GameState.is_feature_available(&"shop") == (day >= 7), "Shop schedule")
		_expect(GameState.is_feature_available(&"mutations") == (day >= 8), "Mutation schedule")
		_expect(GameState.troop.can_unlock_squad_slot() == (day >= 9), "Squad capacity schedule")
		_expect(GameState.is_feature_available(&"compost") == (day >= 11), "Compost schedule")
		_expect(GameState.is_seal_choice_day(day) == (day in [11, 12, 15]), "Seal receiving Day %d" % day)
		_expect(not GameState.nursery.can_unlock_plot(), "One guided Plot")
		_expect(GameState.troop.living_unit_count() == 2, "Reserved Child appears exactly once")
		if day == 11:
			_expect(not GameState.has_won_run(), "Day-10 victory continues the guided Run")
	GameState.debug_advance_day()
	_expect(GameState.has_won_run(), "Day-15 victory completes the guided Run")
	GameState.reset_run(false)
	_expect(GameState.get_run_length() == 10, "Ordinary length unchanged")
	_expect(GameState.pending_seal_choice, "Ordinary opening retains Seal")
	_expect(GameState.is_school_available(WeaponSchool.Id.SHIELD), "Ordinary schools unchanged")
	GameState.debug_advance_day()
	_expect(GameState.is_nursery_unlocked(), "Ordinary Nursery still unlocks after Day 1")
	for day in range(1, 11):
		_expect(GameState.is_seal_choice_day(day) == (day in [1, 3, 6, 9]), "Ordinary receiving Day %d" % day)


func _test_late_nursery_and_offers() -> void:
	_prepare_day(9)
	GameState.biomass.add(30)
	_expect(GameState.try_plant_fresh_common(0), "Late first planting succeeds")
	var plot: NurseryPlotData = GameState.nursery.plots[0]
	_expect(plot.remaining_days() == 1, "First grow still takes one Day when planted late")
	var offer: ShopOffer = GameState.nursery.spore_shop.offers[0]
	_expect(offer.item == GuidedRun.QUICK_GROWTH, "Quick Growth remains available for late use")
	_expect(GameState.nursery.spore_shop.offers[2].item == GuidedRun.THORNY, "Thorny remains available")
	_expect(GameState.nursery.spore_shop.offers[1] == null, "Other offers remain hidden")
	GameState.nursery.replace_shop_slot(0)
	GameState.nursery.ensure_shop_offers()
	_expect(GameState.nursery.spore_shop.offers[0] == null, "Refresh never replenishes a bought offer")
	GameState.debug_advance_day()
	_expect(plot.can_harvest(), "Late first grow is ready before Battle 10")
	_expect(GameState.nursery.spore_shop.offers[0] != null, "Next Day replenishes introductory offer")
	var children := GameState.nursery.harvest(0)
	_expect(children.size() == 1 and not children[0].is_adult_stage(), "Harvest yields a Child")


func _test_battle_and_preparation_restore() -> void:
	_prepare_day(8)
	GameState.biomass.add(30)
	var starting_biomass := GameState.biomass.amount
	var child: RosterUnitData = GameState.troop.squad[1]
	var parent: RosterUnitData = GameState.troop.squad[0]
	GameState.ensure_guided_preparation_checkpoint()
	_expect(GameState.try_plant_fresh_common(0), "Preparation plants grow")
	_expect(GameState.try_cocoon_for_pupation(child, WeaponSchool.Id.BOW), "Preparation trains Child")
	var launch_balance := GameState.biomass.amount
	var enemies := GameState.make_upcoming_enemy_roster()
	var enemy_strength := enemies[0].stats.strength
	GameState.capture_guided_battle_checkpoint(enemies)
	for attempt in 3:
		GameState.nursery.add_death_spore(parent)
		GameState.troop.remove_unit(parent)
		GameState.biomass.add(90)
		GameState.debug_advance_day()
		enemies[0].stats.strength = 99
		_expect(GameState.restart_guided_battle(), "Retry remains repeatable")
		_expect(GameState.current_day == 7, "Retry restores the Battle's Day")
		_expect(GameState.biomass.amount == launch_balance, "Retry discards attempted reward")
		_expect(GameState.troop.squad[0] == parent and not parent.emitted_death_spore, "Retry restores dead parent's identity and state")
		_expect(not GameState.nursery.has_spore_in_stock(), "Retry removes attempted death spore")
		_expect(GameState.pupation.find_school_for_unit(child) == WeaponSchool.Id.BOW, "Retry undoes premature Training tick")
		_expect((GameState.nursery.plots[0] as NurseryPlotData).remaining_days() == 1, "Retry undoes grow tick")
		_expect(BattleLaunch.enemy_roster[0].stats.strength == enemy_strength, "Retry preserves exact enemy roll")
	_expect(GameState.restore_guided_preparation(), "Change preparation restores checkpoint")
	_expect(GameState.biomass.amount == starting_biomass, "Change preparation refunds that Day's spending")
	_expect(GameState.troop.squad[1] == child and not child.is_adult_stage(), "Change preparation restores untrained Child")
	_expect((GameState.nursery.plots[0] as NurseryPlotData).is_empty(), "Change preparation removes that Day's grow")
	_expect(GameState.make_upcoming_enemy_roster()[0].stats.strength == enemy_strength, "Change preparation keeps enemy roll")
	_expect(not GameState.has_guided_battle_checkpoint(), "New preparation invalidates old battle checkpoint")


func _test_compost_and_lineage_restore() -> void:
	_prepare_day(11)
	GameState.biomass.add(40)
	var parent: RosterUnitData = GameState.troop.squad[0]
	parent.body_mutation = GuidedRun.THORNY
	var starting_biomass := GameState.biomass.amount
	GameState.ensure_guided_preparation_checkpoint()
	_expect(GameState.try_cocoon_for_pupation(parent, WeaponSchool.Id.MACE), "Available Adult Training is instant")
	_expect(GameState.try_compost_unit(parent), "Optional Compost produces a lineage spore")
	var spore := GameState.nursery.stock.get_at(0) as SporeData
	_expect(spore != null and spore.weapon_trainings == [WeaponSchool.Id.SWORD, WeaponSchool.Id.MACE], "Lineage saves actual Adult Trainings")
	_expect(spore != null and spore.body_mutation != null, "Lineage saves parent Mutation")
	var after_compost := GameState.biomass.amount
	_expect(GameState.nursery.plant(0, 0), "Lineage planting consumes owned spore")
	_expect(GameState.biomass.amount == after_compost, "Lineage planting has no fresh-grow cost")
	GameState.capture_guided_battle_checkpoint(GameState.make_upcoming_enemy_roster())
	GameState.debug_advance_day()
	var descendants := GameState.nursery.harvest(0)
	_expect(descendants.size() == 1 and descendants[0].generation == parent.generation + 1, "Actual lineage grow yields next Generation")
	_expect(GameState.restart_guided_battle(), "Lineage Battle can be replayed")
	_expect(not GameState.nursery.has_spore_in_stock(), "Replay does not duplicate planted spore")
	_expect(not GameState.troop.squad.has(parent), "Replay retains accepted Compost preparation")
	_expect(GameState.restore_guided_preparation(), "Compost preparation can be changed")
	_expect(GameState.troop.squad.has(parent) and parent.weapon_trainings == [WeaponSchool.Id.SWORD], "Preparation restores parent and removes instant Training")
	_expect(GameState.biomass.amount == starting_biomass, "Preparation removes Compost payout and refunds Training")
	_expect(not GameState.nursery.has_spore_in_stock() and GameState.nursery.plots[0].is_empty(), "Preparation removes lineage spore and grow together")


func _test_seal_restore() -> void:
	_prepare_day(11)
	var offers := GameState.ensure_seal_choice_offers().duplicate()
	GameState.ensure_guided_preparation_checkpoint()
	_expect(GameState.try_add_seal(offers[0]), "Introductory Seal can be chosen")
	GameState.clear_pending_seal_choice()
	GameState.capture_guided_battle_checkpoint(GameState.make_upcoming_enemy_roster())
	_expect(GameState.restart_guided_battle() and GameState.seals.owned.size() == 1, "Battle retry retains chosen Seal once")
	_expect(GameState.restore_guided_preparation(), "Seal preparation can be restored")
	_expect(GameState.pending_seal_choice and GameState.seals.owned.is_empty(), "Preparation restores pending choice without bonus")
	_expect(GameState.ensure_seal_choice_offers() == offers, "Preparation keeps same Seal offers")
	GameState.try_add_seal(offers[0])
	GameState.clear_pending_seal_choice()
	GameState.debug_advance_day()
	GameState.ensure_guided_preparation_checkpoint()
	GameState.try_add_seal(offers[0])
	GameState.clear_pending_seal_choice()
	_expect(GameState.seals.owned.size() == 2, "Separate regular reward can stack the same Seal")
	GameState.restore_guided_preparation()
	_expect(GameState.seals.owned.size() == 1 and GameState.pending_seal_choice, "Restore keeps earlier Seal and undoes only current choice")


func _test_terminal_preference() -> void:
	SettingsServer.guided_run_enabled = true
	SettingsServer.guided_run_ended = false
	SettingsServer.guided_run_completed = false
	GameState.reset_run(true)
	GameState.ensure_guided_preparation_checkpoint()
	GameState.capture_guided_battle_checkpoint(GameState.make_upcoming_enemy_roster())
	GameState.restart_guided_battle()
	_expect(SettingsServer.guided_run_enabled and not SettingsServer.guided_run_ended, "Retry does not end first guided Run")
	GameState.finish_run()
	_expect(not SettingsServer.guided_run_enabled and SettingsServer.guided_run_ended, "First explicit end unchecks next Run")
	_expect(not SettingsServer.guided_run_completed, "Early end does not record completion")
	SettingsServer.set_guided_run_enabled(true)
	GameState.reset_run(true)
	GameState.finish_run(true)
	_expect(SettingsServer.guided_run_enabled, "Later manual replay preference survives terminal end")
	_expect(SettingsServer.guided_run_completed, "Accepted final victory records completion")
	GameState.reset_run(false)
	GameState.finish_run()
	_expect(SettingsServer.guided_run_enabled, "Ordinary end does not change guided preference")


func _prepare_day(day: int) -> void:
	GameState.reset_run(true)
	while GameState.get_upcoming_day() < day:
		GameState.debug_advance_day()


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
