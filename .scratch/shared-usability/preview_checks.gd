extends RefCounted

const TRAINING_SCENE := preload("res://assets/base/pupation/pupation_confirm_dialog.tscn")
const SCHOOL_SCENE := preload("res://assets/base/pupation/school_training_detail_card.tscn")
const COMPOST_SCENE := preload("res://assets/base/pupation/compost_confirm_dialog.tscn")


## Run from a live Base fixture with autoloads available. Does not mutate GameState.
static func run(host: Control) -> int:
	var failures := 0
	for days in [0, 1, 2]:
		var child := make_unit([], false)
		child.cocoon_duration_days = days
		var expected: String = [
			"Ready immediately · Becomes an Adult",
			"Returns after the next Battle · Becomes an Adult",
			"Returns after 2 Battles · Becomes an Adult",
		][days]
		failures += _check(WeaponSchool.training_availability_text(child) == expected,
			"Child availability for %d days" % days)
		failures += await _training_dialog(host, child, WeaponSchool.Id.BOW,
			"Bow Training → Bow", expected)
		if days > 0:
			var cocoon := PupationData.new()
			failures += _check(cocoon.try_place(child, WeaponSchool.Id.BOW), "Child enters Cocoon")
			for tick in range(days):
				var emerged := cocoon.advance_day()
				failures += _check(emerged.size() == (1 if tick == days - 1 else 0),
					"Child return matches %d-day preview, tick %d" % [days, tick + 1])

	var adult := make_unit([WeaponSchool.Id.SWORD], true)
	adult.cocoon_duration_days = 2
	failures += await _training_dialog(host, adult, WeaponSchool.Id.MACE,
		"Sword + Mace → Warhammer", "Ready immediately · Stats unchanged")
	failures += _check(adult.effective_cocoon_days() == 0, "Adult overrides Child wait")
	failures += await _training_dialog(host, adult, WeaponSchool.Id.SWORD,
		"Sword + Sword → Great Sword", "Ready immediately · Stats unchanged")
	var dual := make_unit([WeaponSchool.Id.SWORD, WeaponSchool.Id.BOW], true)
	failures += await _training_dialog(host, dual, WeaponSchool.Id.MACE,
		"Bow + Mace → Great Horn", "Ready immediately · Stats unchanged")
	failures += _check(WeaponSchool.training_replacement_text(dual, WeaponSchool.Id.MACE)
		== "Replaces oldest Training: Sword. Keeps Bow and adds Mace.", "Oldest replacement named")
	failures += await _training_dialog(host, dual, WeaponSchool.Id.SWORD,
		"Bow + Sword → Crossbow", "Ready immediately · Stats unchanged")
	failures += _check(WeaponSchool.training_replacement_text(dual, WeaponSchool.Id.SWORD)
		== "Trains Sword again, replacing its oldest Training. Keeps Bow.", "Oldest renewal named")

	# Exercise generation scaling, doubled Training gains, pending adulthood bonus,
	# and Stat clamps through the actual action as well as the preview.
	var descendant := make_unit([WeaponSchool.Id.SWORD, WeaponSchool.Id.BOW], false)
	descendant.generation = 3
	descendant.stats.strength = 98
	descendant.stats.dex = 1
	descendant.stats.con = 96
	descendant.pupation_stat_multiplier = 2
	descendant.pending_adult_stat_bonus = 7
	failures += await _training_dialog(host, descendant, WeaponSchool.Id.MACE,
		"Bow + Mace → Great Horn",
		"Returns after the next Battle · Becomes an Adult")
	for school in WeaponSchool.DISPLAY_ORDER:
		var card: SchoolTrainingDetailCard = SCHOOL_SCENE.instantiate()
		card.setup(school)
		host.add_child(card)
		# Match DetailTooltipPopup's settling passes for wrapping text.
		for pass_index in 5:
			await host.get_tree().process_frame
			card.fit_to_content()
		print("SCHOOL_CARD_SIZE ", school, " ", card.card_size())
		card.position = (host.size - card.card_size()) * 0.5
		failures += _check(card.card_size().y < 1000.0, "School hover fits play height")
		if school == WeaponSchool.Id.SWORD:
			await _snapshot(host, "/tmp/usability-training-school.png")
		card.queue_free()
		await host.get_tree().process_frame

	failures += await _compost_checks(host)
	print("PREVIEW_CHECKS failures=", failures)
	return failures


static func _training_dialog(
	host: Control, unit: RosterUnitData, school: int, recipe: String, availability: String
) -> int:
	var failures := 0
	var original_stats := _stats(unit)
	var original_trainings := unit.weapon_trainings.duplicate()
	var preview := WeaponSchool.preview_emerged_unit(unit, school)
	var actual := unit.duplicate(true) as RosterUnitData
	failures += _check(actual.apply_pupation_training(school), "Training action accepted")
	failures += _check(preview.weapon.display_name == actual.weapon.display_name,
		"Preview Weapon matches Training action")
	failures += _check(preview.weapon_trainings == actual.weapon_trainings,
		"Preview Training order matches action")
	failures += _check(_stats(preview) == _stats(actual), "Preview Stats match Training action")
	failures += _check(actual.is_adult_stage() and preview.is_adult_stage(), "Preview/action Adult stage")
	if unit.is_adult_stage():
		failures += _check(_stats(actual) == original_stats, "Adult Stats unchanged")
	failures += _check(_stats(unit) == original_stats and unit.weapon_trainings == original_trainings,
		"Preview leaves source untouched")
	var dialog: PupationConfirmDialog = TRAINING_SCENE.instantiate()
	dialog.setup(unit, school)
	host.add_child(dialog)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	failures += _check((dialog.get_node("%PupateTitle") as Label).text == "Train %s" % unit.display_name,
		"Train action terminology")
	failures += _check((dialog.get_node("%RecipeLabel") as Label).text == recipe,
		"Actual recipe visible: " + recipe)
	failures += _check((dialog.get_node("%AvailabilityLabel") as Label).text == availability,
		"Actual availability visible")
	failures += _check((dialog.get_node("%RightWeaponName") as Label).text == actual.weapon.display_name,
		"Result portrait Weapon matches actual Training")
	failures += _check((dialog.get_node("%ConfirmButton") as Button).text
		== "Train %s" % BiomassDisplay.number(WeaponSchool.COCOON_COST), "Actual cost visible")
	var panel := dialog.get_node("Center/Panel") as Control
	print("TRAINING_PANEL_SIZE ", recipe, " ", panel.size)
	failures += _check(panel.size.y < 1000.0, "Training confirmation fits play height")
	if recipe == "Bow Training → Bow" and unit.effective_cocoon_days() == 1:
		await _snapshot(host, "/tmp/usability-training-child.png")
	elif recipe == "Sword + Mace → Warhammer" and unit.is_adult_stage():
		await _snapshot(host, "/tmp/usability-training-adult.png")
	dialog.queue_free()
	await host.get_tree().process_frame
	return failures


static func _compost_checks(host: Control) -> int:
	var failures := 0
	var child := make_unit([], false)
	var child_dialog: CompostConfirmDialog = COMPOST_SCENE.instantiate()
	child_dialog.setup(child)
	host.add_child(child_dialog)
	await host.get_tree().process_frame
	failures += _check(not bool(GameState.preview_compost_outcome(child).get("emits_spore")),
		"Child Compost creates no spore")
	failures += _check(not (child_dialog.get_node("%LineagePreview") as Control).visible,
		"Child Compost hides descendant preview")
	failures += _check((child_dialog.get_node("%OutcomeSpore") as Label).text.contains("Only Adults"),
		"Child Compost explains no spore")
	child_dialog.queue_free()
	await host.get_tree().process_frame

	var parent := make_unit([WeaponSchool.Id.SWORD, WeaponSchool.Id.MACE], true)
	parent.generation = 2
	parent.body_mutation = load("res://assets/base/nursery/mutations/body/thorny.tres") as MutationData
	parent.cap_mutation = load("res://assets/base/nursery/mutations/cap/inky.tres") as MutationData
	parent.applied_fertilizers.append(
		load("res://assets/base/nursery/fertilizers/cocooning.tres") as FertilizerData
	)
	var spore := SporeData.from_fallen_unit(parent)
	var nursery := NurseryData.new()
	var harvested := nursery._make_harvest_units(spore, [], 0, spore.body_mutation, spore.cap_mutation)
	var descendant := harvested[0]
	failures += _check(not descendant.is_adult_stage(), "Lineage harvest is a Child")
	failures += _check(descendant.generation == 3 and descendant.power_tier == parent.power_tier,
		"Generation advances, Tier preserved")
	failures += _check(descendant.weapon_trainings == parent.weapon_trainings
		and descendant.weapon.display_name == parent.weapon.display_name, "Trainings and Weapon inherited")
	failures += _check(descendant.body_mutation.title_text() == parent.body_mutation.title_text()
		and descendant.cap_mutation.title_text() == parent.cap_mutation.title_text(), "Both Mutations inherited")
	failures += _check(descendant.applied_fertilizers.is_empty(), "Fertilizer items not inherited")
	for stat in ["strength", "dex", "con"]:
		failures += _check(absi(int(descendant.stats.get(stat)) - int(parent.stats.get(stat))) <= 1,
			"Lineage Stat rolls around saved parent: " + stat)
	var dialog: CompostConfirmDialog = COMPOST_SCENE.instantiate()
	dialog.setup(parent)
	host.add_child(dialog)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	failures += _check((dialog.get_node("%OutcomeSpore") as Label).text.contains(spore.display_name),
		"Actual lineage spore named")
	failures += _check((dialog.get_node("%DescendantTitle") as Label).text
		== "After harvest: %s · Child" % descendant.display_name, "Actual descendant name/stage preview")
	failures += _check((dialog.get_node("%GrowthTime") as Label).text
		== "Growth Time: %d %s" % [spore.days_to_mature_effective(),
			WeaponSchool.day_word(spore.days_to_mature_effective())], "Effective Growth Time preview")
	var mutations := (dialog.get_node("%InheritedMutations") as Label).text
	failures += _check(mutations.contains(parent.body_mutation.title_text())
		and mutations.contains(parent.cap_mutation.title_text()), "Both Mutation previews visible")
	failures += _check((dialog.get_node("%InheritedTrainings") as Label).text.contains("Sword + Mace → Warhammer"),
		"Actual inherited recipe visible")
	failures += _check((dialog.get_node("%InheritedStats") as Label).tooltip_text.contains("Fertilizer items do not carry"),
		"Fertilizer inheritance detail accessible")
	failures += _check((dialog.get_node("Center/Panel") as Control).size.y < 1000.0,
		"Compost confirmation fits play height")
	await _snapshot(host, "/tmp/usability-compost-adult.png")
	if OS.get_cmdline_user_args().has("--visual"):
		var detail := dialog.get_node("%InheritedStats") as Control
		var motion := InputEventMouseMotion.new()
		motion.position = detail.get_global_transform_with_canvas() * (detail.size * 0.5)
		host.get_viewport().push_input(motion, true)
		await host.get_tree().create_timer(0.4).timeout
		failures += _check(host.get_viewport().gui_get_hovered_control() == detail,
			"Compost Stat detail is hoverable")
		await _snapshot(host, "/tmp/usability-compost-detail.png")
	dialog.queue_free()
	await host.get_tree().process_frame
	return failures


static func _snapshot(host: Control, path: String) -> void:
	if not OS.get_cmdline_user_args().has("--visual"):
		return
	for frame in 4:
		await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := host.get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		var result := image.save_png(path)
		print("PREVIEW_SCREENSHOT ", path, " result=", result)


static func make_unit(trainings: Array[int], adult: bool) -> RosterUnitData:
	var unit := RosterUnitData.new()
	unit.display_name = "Preview Fern"
	unit.lineage_name = "Preview Fern"
	unit.stats = UnitStatsData.new()
	unit.stats.strength = 10
	unit.stats.dex = 10
	unit.stats.con = 10
	unit.weapon_trainings = trainings.duplicate()
	unit.is_imago = adult
	unit.life_stage_id = RosterUnitData.STAGE_IMAGO if adult else RosterUnitData.STAGE_JUVENILE
	unit.sync_weapon_from_trainings()
	return unit


static func _stats(unit: RosterUnitData) -> Vector3i:
	return Vector3i(unit.stats.strength, unit.stats.dex, unit.stats.con)


static func _check(condition: bool, description: String) -> int:
	if condition:
		return 0
	push_error("PREVIEW_CHECK failed: " + description)
	return 1
