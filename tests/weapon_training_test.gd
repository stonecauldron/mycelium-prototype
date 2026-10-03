extends Node

## Run: godot --headless --path . res://tests/weapon_training_test.tscn


func _ready() -> void:
	var saved_troop := GameState.troop
	var saved_pupation := GameState.pupation
	var saved_biomass := GameState.biomass
	var saved_guided := GameState.is_guided_run
	var saved_analytics := Analytics.ga
	Analytics.ga = null
	GameState.is_guided_run = false
	var failures := _regression_sequence()
	for older in WeaponSchool.COUNT:
		for newer in WeaponSchool.COUNT:
			for school in WeaponSchool.COUNT:
				failures += _adult_training_case(older, newer, school)
	for school in WeaponSchool.COUNT:
		failures += _child_evolution_case(school, 0)
		failures += _child_evolution_case(school, 1)
	GameState.troop = saved_troop
	GameState.pupation = saved_pupation
	GameState.biomass = saved_biomass
	GameState.is_guided_run = saved_guided
	Analytics.ga = saved_analytics
	print("Weapon training checks: regression sequence, 125 Adult combinations, 10 Child Evolutions; failures=", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _regression_sequence() -> int:
	var sword := WeaponSchool.Id.SWORD
	var mace := WeaponSchool.Id.MACE
	var unit := _make_unit([sword, sword], true)
	_set_fixture(unit, false)
	var failures := _check(unit.weapon.display_name == "Great Sword", "Regression starts with Great Sword")
	failures += _check(GameState.try_cocoon_for_pupation(unit, mace), "Regression accepts Mace")
	failures += _check(unit.weapon.display_name == "Warhammer" and unit.weapon_trainings == [sword, mace],
		"Regression changes Great Sword to Warhammer")
	failures += _check(GameState.try_cocoon_for_pupation(unit, sword), "Regression accepts Sword")
	failures += _check(unit.weapon.display_name == "Great Sword" and unit.weapon_trainings == [sword, sword],
		"Regression changes Warhammer back to Great Sword")
	failures += _check(GameState.biomass.amount == 30 - 2 * WeaponSchool.COCOON_COST,
		"Regression spends exactly two Training costs")
	return failures


func _adult_training_case(older: int, newer: int, school: int) -> int:
	var unit := _make_unit([older, newer], true)
	var on_bench := school % 2 == 0
	_set_fixture(unit, on_bench)
	var original_trainings := unit.weapon_trainings.duplicate()
	var original_weapon := unit.weapon
	var original_stats := _stats(unit)
	# Retraining the older school of a mixed pair must return to that school's
	# doubled weapon; all other training keeps the newer school (ordinary FIFO).
	var kept_school := older if school == older and older != newer else newer
	var expected: Array[int] = [kept_school, school]
	var expected_path := WeaponSchool.combo_weapon_path(kept_school, school)
	var allowed := not (older == newer and newer == school)
	var label := "%s + %s, train %s" % [
		WeaponSchool.display_name(older), WeaponSchool.display_name(newer), WeaponSchool.display_name(school)
	]
	var next := WeaponSchool.trainings_after_training(unit.weapon_trainings, school)
	var preview := WeaponSchool.preview_emerged_unit(unit, school)
	var failures := _check(next == expected, label + ": correct replacement")
	failures += _check(preview.weapon_trainings == expected and preview.weapon.resource_path == expected_path,
		label + ": preview gives expected Weapon and Trainings")
	failures += _check(WeaponSchool.preview_weapon_after_training(unit.weapon_trainings, school).resource_path
		== expected_path, label + ": Weapon-only preview agrees")
	failures += _check(unit.weapon_trainings == original_trainings and unit.weapon == original_weapon
		and _stats(unit) == original_stats, label + ": previews do not mutate source")
	failures += _check(_stats(preview) == original_stats, label + ": preview preserves Adult Stats")
	failures += _check(unit.check_training_eligibility(school).allowed == allowed
		and GameState.can_cocoon_for_pupation(unit, school) == allowed,
		label + ": eligibility rejects only unavoidable unchanged Weapon")
	failures += _check(GameState.try_cocoon_for_pupation(unit, school) == allowed,
		label + ": paid action agrees with eligibility")
	failures += _check(GameState.biomass.amount == 30 - (WeaponSchool.COCOON_COST if allowed else 0),
		label + ": unchanged Weapon never spends Biomass")
	failures += _check(unit.weapon_trainings == expected and unit.weapon.resource_path == expected_path,
		label + ": paid action matches preview")
	failures += _check(_stats(unit) == original_stats, label + ": Adult Stats stay unchanged")
	failures += _check(unit.is_adult_stage() and GameState.pupation.cocooned_count() == 0,
		label + ": Adult Training stays instant")
	var row: Array = GameState.troop.bench if on_bench else GameState.troop.squad
	failures += _check(row[2] == unit and GameState.troop.living_unit_count() == 1,
		label + ": Adult retains original Troop slot")
	if allowed:
		failures += _check(unit.weapon.resource_path != original_weapon.resource_path,
			label + ": every accepted Adult Training changes Weapon")
	else:
		failures += _check(unit.check_training_eligibility(school).reason == ActionReasons.TRAINING_UNCHANGED,
			label + ": unavoidable no-op has specific rejection reason")
		failures += _check(not unit.apply_pupation_training(school)
			and unit.weapon_trainings == original_trainings and _stats(unit) == original_stats,
			label + ": direct no-op also rejects without mutation")
	return failures


func _child_evolution_case(school: int, wait_days: int) -> int:
	var child := _make_unit([school, school], false)
	child.cocoon_duration_days = wait_days
	_set_fixture(child, false)
	GameState.troop.squad[0] = _make_unit([], true)
	var original_stats := _stats(child)
	var original_weapon_path := child.weapon.resource_path
	var preview := WeaponSchool.preview_emerged_unit(child, school)
	var label := "%s + %s Child, %d-day Evolution" % [
		WeaponSchool.display_name(school), WeaponSchool.display_name(school), wait_days
	]
	var failures := _check(not child.is_adult_stage() and _stats(child) == original_stats,
		label + ": preview leaves Child unchanged")
	failures += _check(GameState.try_cocoon_for_pupation(child, school),
		label + ": unchanged Weapon still allows Child Evolution")
	failures += _check(GameState.biomass.amount == 30 - WeaponSchool.COCOON_COST,
		label + ": Evolution spends one cost")
	if wait_days > 0:
		failures += _check(GameState.pupation.get_occupant(school) == child
			and GameState.troop.squad[2] == null and not child.is_adult_stage(),
			label + ": delayed Evolution waits in Cocoon")
		var emerged := GameState.pupation.advance_day()
		failures += _check(emerged.size() == 1 and emerged[0].get("unit") == child,
			label + ": Child emerges after one Battle")
	else:
		failures += _check(GameState.troop.squad[2] == child and GameState.pupation.cocooned_count() == 0,
			label + ": instant Evolution retains Troop slot")
	failures += _check(child.is_adult_stage() and child.weapon_trainings == [school, school]
		and child.weapon.resource_path == original_weapon_path,
		label + ": Child becomes Adult with original Weapon")
	failures += _check(_stats(child) == _stats(preview) and _stats(child) != original_stats,
		label + ": Evolution Stat gains agree with preview")
	return failures


func _set_fixture(unit: RosterUnitData, on_bench: bool) -> void:
	GameState.troop = TroopData.new()
	GameState.pupation = PupationData.new()
	GameState.biomass = BiomassData.new()
	GameState.biomass.amount = 30
	var row: Array = GameState.troop.bench if on_bench else GameState.troop.squad
	row[2] = unit


func _make_unit(trainings: Array[int], adult: bool) -> RosterUnitData:
	var unit := RosterUnitData.new()
	unit.display_name = "Training Fern"
	unit.stats = UnitStatsData.new()
	unit.stats.strength = 10
	unit.stats.dex = 10
	unit.stats.con = 10
	unit.weapon_trainings = trainings.duplicate()
	unit.is_imago = adult
	unit.life_stage_id = RosterUnitData.STAGE_IMAGO if adult else RosterUnitData.STAGE_JUVENILE
	unit.sync_weapon_from_trainings()
	return unit


func _stats(unit: RosterUnitData) -> Vector3i:
	return Vector3i(unit.stats.strength, unit.stats.dex, unit.stats.con)


func _check(condition: bool, description: String) -> int:
	if condition:
		return 0
	push_error("Weapon training check failed: " + description)
	return 1
