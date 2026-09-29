extends RefCounted

const TRAINING_SCENE := preload("res://assets/base/pupation/pupation_confirm_dialog.tscn")
const SCHOOL_SCENE := preload("res://assets/base/pupation/school_training_detail_card.tscn")
const COMPOST_SCENE := preload("res://assets/base/pupation/compost_confirm_dialog.tscn")


## Run from a live Base fixture; temporary Seal/Troop fixtures are restored after checking.
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

	failures += await _training_seal_checks(host)
	await _unit_training_cards(host)
	failures += await _compost_checks(host)
	print("PREVIEW_CHECKS failures=", failures)
	return failures


static func _unit_training_cards(host: Control) -> void:
	if not OS.get_cmdline_user_args().has("--visual"):
		return
	var scene := preload("res://assets/base/unit_detail_card/unit_detail_card.tscn")
	var cards: Array[UnitDetailCard] = []
	for count in 3:
		var trainings: Array[int] = []
		for index in count:
			trainings.append(WeaponSchool.Id.BOW)
		var unit := make_unit(trainings, count > 0)
		unit.display_name = ["No Trainings", "One Training", "Two Trainings"][count]
		if count > 0:
			unit.applied_fertilizers.append(
				load("res://assets/base/nursery/fertilizers/brute_force.tres") as FertilizerData
			)
		if count == 2:
			unit.cap_mutation = load("res://assets/base/nursery/mutations/cap/inky.tres") as MutationData
			unit.body_mutation = load("res://assets/base/nursery/mutations/body/thorny.tres") as MutationData
		var card: UnitDetailCard = scene.instantiate()
		card.setup(unit, false, false)
		host.add_child(card)
		cards.append(card)
	for pass_index in 5:
		await host.get_tree().process_frame
		for card in cards:
			card.fit_to_content()
	for index in cards.size():
		var card := cards[index]
		var fit_scale := minf(1.0, (host.size.y - 48.0) / card.card_size().y)
		card.scale = Vector2.ONE * fit_scale
		var visual_size := card.card_size() * fit_scale
		card.position = Vector2(host.size.x * 0.5 + float(index - 1) * 430.0 - visual_size.x * 0.5,
			(host.size.y - visual_size.y) * 0.5)
		print("UNIT_CARD_SIZE ", index, " ", card.card_size(), " scale=", fit_scale)
	await _snapshot(host, "/tmp/usability-unit-trainings.png")
	for card in cards:
		card.queue_free()
	await host.get_tree().process_frame


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
	var action := "Train" if unit.is_adult_stage() else "Evolve"
	failures += _check((dialog.get_node("%PupateTitle") as Label).text == "%s %s" % [action, unit.display_name],
		"Life-stage action terminology")
	failures += _check(WeaponSchool.training_recipe_text(preview.weapon_trainings) == recipe,
		"Actual recipe: " + recipe)
	failures += _check(WeaponSchool.training_availability_text(unit) == availability,
		"Actual availability preserved")
	failures += _check((dialog.get_node("%LeftColumn") as Control).visible
		and (dialog.get_node("%MidColumn") as Control).visible, "Both life stages show comparison")
	failures += _check((dialog.get_node("%LeftWeaponName") as Label).text == unit.weapon.display_name,
		"Before portrait Weapon matches current Unit")
	var days := unit.effective_cocoon_days()
	failures += _check((dialog.get_node("%DurationChip") as Control).visible == (days > 0),
		"Hourglass only shown for delayed Evolution")
	failures += _check((dialog.get_node("%DurationSuffix") as Label).text
		== (WeaponSchool.day_word(days) if days > 0 else "Instant"), "Preview timing label")
	failures += _check((dialog.get_node("%RightWeaponName") as Label).text == actual.weapon.display_name,
		"Result portrait Weapon matches actual Training")
	var attack_before := SealModifiers.effective_attack_damage(unit)
	var attack_after := SealModifiers.effective_attack_damage(actual)
	var hp_before := SealModifiers.effective_max_hp(unit)
	var hp_after := SealModifiers.effective_max_hp(actual)
	failures += _check_combat_preview(dialog, "Atk", attack_before, attack_after)
	failures += _check_combat_preview(dialog, "Hp", hp_before, hp_after)
	for side in ["Left", "Right"]:
		failures += _check_portrait_alignment(dialog, side)
		var tags := dialog.get_node("%%%sWeaponTags" % side) as HFlowContainer
		var visible_tags := 0
		for tag in tags.get_children():
			if tag is Control and (tag as Control).visible:
				visible_tags += 1
		failures += _check(visible_tags >= 2, side + " Weapon shows range and scaling tags")
	failures += _check((dialog.get_node("%ConfirmButton") as Button).text
		== "%s %s" % [action, BiomassDisplay.number(WeaponSchool.COCOON_COST)], "Actual cost visible")
	var panel := dialog.get_node("Center/Panel") as Control
	print("TRAINING_PANEL_SIZE ", recipe, " ", panel.size)
	failures += _check(panel.size.y < 1000.0, "Training confirmation fits play height")
	if recipe == "Bow Training → Bow" and unit.effective_cocoon_days() == 1:
		await _snapshot(host, "/tmp/usability-training-child.png")
	elif recipe == "Sword + Mace → Warhammer" and unit.is_adult_stage():
		await _snapshot(host, "/tmp/usability-training-adult.png")
		await _snapshot_close_hover(host, dialog, "/tmp/usability-training-close-hover.png")
	elif recipe == "Sword + Sword → Great Sword" and unit.is_adult_stage():
		await _snapshot(host, "/tmp/usability-training-aoe.png")
	dialog.queue_free()
	await host.get_tree().process_frame
	return failures


static func _check_portrait_alignment(dialog: Control, side: String) -> int:
	var portrait := dialog.get_node("%%%sPortrait" % side) as Control
	var appearance: UnitAppearance = null
	for child in portrait.get_children():
		if child is UnitAppearance:
			appearance = child as UnitAppearance
			break
	if appearance == null:
		return _check(false, side + " comparison portrait exists")
	var attack := dialog.get_node("%%%sAtkChip" % side) as StatChip
	var health := dialog.get_node("%%%sHpChip" % side) as StatChip
	var chips_center := (attack.get_global_rect().get_center().x
		+ health.get_global_rect().get_center().x) * 0.5
	var body := appearance.transform * appearance.visual_rect_local(false)
	var body_center := portrait.global_position.x + body.get_center().x
	var failures := _check(absf(body_center - chips_center) <= 2.0,
		side + " Unit body is centered above combat chips")
	var full_art := appearance.transform * appearance.visual_rect_local(true)
	failures += _check(full_art.position.x >= -2.0 and full_art.end.x <= portrait.size.x + 2.0,
		side + " held Weapon remains inside portrait")
	return failures


static func _check_combat_preview(dialog: Control, chip_name: String, before: int, after: int) -> int:
	var failures := 0
	var left := dialog.get_node("%%Left%sChip" % chip_name) as StatChip
	var right := dialog.get_node("%%Right%sChip" % chip_name) as StatChip
	var delta_label := dialog.get_node("%%Right%sDelta" % chip_name) as Label
	var delta := after - before
	failures += _check((left.get_node("%Value") as Label).text == str(before),
		chip_name + " before value matches gameplay")
	failures += _check((right.get_node("%Value") as Label).text == str(after),
		chip_name + " after value matches gameplay")
	failures += _check(delta_label.text == ("%+d" % delta if delta != 0 else ""),
		chip_name + " signed change matches gameplay")
	if delta != 0:
		var expected_color := StatDisplay.GAIN_COLOR if delta > 0 else StatDisplay.LOSS_COLOR
		failures += _check(delta_label.get_theme_color("font_color") == expected_color,
			chip_name + " change uses gain/loss color")
	return failures


static func _training_seal_checks(host: Control) -> int:
	var failures := 0
	var saved_troop := GameState.troop
	var saved_seals := GameState.seals
	GameState.seals = SealsCollection.new()
	for seal_name in ["favourite_child", "bulwark", "ranger", "neotonia"]:
		GameState.seals.add(load("res://assets/base/seals/%s.tres" % seal_name) as SealData)
	for scenario in ["squad", "bench", "instant_child"]:
		var unit := make_unit([WeaponSchool.Id.SWORD], scenario != "instant_child")
		unit.favourite_child_buff = true
		unit.cocoon_duration_days = 0
		GameState.troop = TroopData.new()
		var slots: Array = GameState.troop.bench if scenario == "bench" else GameState.troop.squad
		slots[0] = unit
		var attack_before := SealModifiers.effective_attack_damage(unit)
		var hp_before := SealModifiers.effective_max_hp(unit)
		var actual := unit.duplicate(true) as RosterUnitData
		actual.apply_pupation_training(WeaponSchool.Id.MACE)
		slots[0] = actual
		var attack_after := SealModifiers.effective_attack_damage(actual)
		var hp_after := SealModifiers.effective_max_hp(actual)
		slots[0] = unit
		var dialog: PupationConfirmDialog = TRAINING_SCENE.instantiate()
		dialog.setup(unit, WeaponSchool.Id.MACE)
		host.add_child(dialog)
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		failures += _check_combat_preview(dialog, "Atk", attack_before, attack_after)
		failures += _check_combat_preview(dialog, "Hp", hp_before, hp_after)
		failures += _check(slots[0] == unit and unit.weapon_trainings == [WeaponSchool.Id.SWORD],
			"Seal comparison preserves live Unit and Formation: " + scenario)
		if scenario == "squad":
			await _snapshot(host, "/tmp/usability-training-seals.png")
		dialog.queue_free()
		await host.get_tree().process_frame
	GameState.troop = saved_troop
	GameState.seals = saved_seals
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
	failures += _check((child_dialog.get_node("%OutcomeSpore") as Label).text.contains("Only Adults"),
		"Child Compost explains no spore")
	await _snapshot(host, "/tmp/usability-compost-child.png")
	child_dialog.queue_free()
	await host.get_tree().process_frame

	var parent := make_unit([WeaponSchool.Id.SWORD, WeaponSchool.Id.MACE], true)
	parent.generation = 2
	parent.lineage_name = "Van Leeuwenhoek"
	parent.display_name = UnitNames.format_unit_name(parent.lineage_name, parent.generation)
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
	failures += _check((dialog.get_node("%OutcomeSpore") as Label).text == spore.display_name,
		"Actual lineage spore named")
	failures += _check((dialog.get_node("Center/Panel") as Control).size.y < 1000.0,
		"Compost confirmation fits play height")
	await _snapshot(host, "/tmp/usability-compost-adult.png")
	await _snapshot_close_hover(host, dialog, "/tmp/usability-compost-close-hover.png")
	dialog.queue_free()
	await host.get_tree().process_frame
	return failures


static func _snapshot_close_hover(host: Control, dialog: Control, path: String) -> void:
	if not OS.get_cmdline_user_args().has("--visual"):
		return
	var close_button := dialog.get_node("%CloseButton") as Button
	var motion := InputEventMouseMotion.new()
	motion.position = close_button.get_global_transform_with_canvas() * (close_button.size * 0.5)
	host.get_viewport().push_input(motion, true)
	await _snapshot(host, path)
	motion = InputEventMouseMotion.new()
	motion.position = Vector2.ZERO
	host.get_viewport().push_input(motion, true)


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
