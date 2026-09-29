extends RefCounted

const TRAINING_SCENE := preload("res://assets/base/pupation/pupation_confirm_dialog.tscn")
const SCHOOL_SCENE := preload("res://assets/base/pupation/school_training_detail_card.tscn")
const COMPOST_SCENE := preload("res://assets/base/pupation/compost_confirm_dialog.tscn")
const TRAINING_EQUATION_SCRIPT := preload("res://assets/ui/training_equation/training_equation.gd")
const SLOT_TEXTURE := preload("res://assets/asset_packs/Cila - Paper UI stylized/square/square border 14.png")
const CHANGED_SLOT_TEXTURE := preload("res://assets/asset_packs/Cila - Paper UI stylized/square/square border 13.png")
const TAG_CHIP_SCENE := preload("res://assets/ui/tag_chip/tag_chip.tscn")


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
			"Bow Training → Bow", expected, [0], ["Melee", "Scaling"], ["Ranged", "Scaling"])
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
		"Sword + Mace → Warhammer", "Ready immediately · Stats unchanged", [1], [], ["Blunt"])
	failures += _check(adult.effective_cocoon_days() == 0, "Adult overrides Child wait")
	failures += await _training_dialog(host, adult, WeaponSchool.Id.SWORD,
		"Sword + Sword → Great Sword", "Ready immediately · Stats unchanged", [1], [], ["AOE"])
	var dual := make_unit([WeaponSchool.Id.SWORD, WeaponSchool.Id.BOW], true)
	failures += await _training_dialog(host, dual, WeaponSchool.Id.MACE,
		"Bow + Mace → Great Horn", "Ready immediately · Stats unchanged", [0, 1],
		["Ranged", "Scaling"], ["Mid Range", "Scaling", "Blunt"])
	failures += _check(WeaponSchool.training_replacement_text(dual, WeaponSchool.Id.MACE)
		== "Replaces oldest Training: Sword. Keeps Bow and adds Mace.", "Oldest replacement named")
	failures += await _training_dialog(host, dual, WeaponSchool.Id.SWORD,
		"Bow + Sword → Crossbow", "Ready immediately · Stats unchanged", [0, 1], [], [])
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
		"Returns after the next Battle · Becomes an Adult", [0, 1],
		["Ranged", "Scaling"], ["Mid Range", "Scaling", "Blunt"])
	failures += await _training_equation_reuse(host)
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
	failures += await _unit_training_cards(host)
	failures += await _compost_checks(host)
	print("PREVIEW_CHECKS failures=", failures)
	return failures


static func _unit_training_cards(host: Control) -> int:
	var failures := 0
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
		var equation := card._content.get_node("%TrainingsList").get_child(0) as HBoxContainer
		failures += _check_training_equation(equation, card.unit_data, "Unit detail %d" % index)
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
	return failures


static func _training_dialog(
	host: Control, unit: RosterUnitData, school: int, recipe: String, availability: String,
	changed_slots: Array[int], before_changed_tags: Array[String], after_changed_tags: Array[String]
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
	failures += _check_weapon_equation(dialog.get_node("%LeftWeaponRow") as PupationWeaponHoverRow, unit, "Before")
	var days := unit.effective_cocoon_days()
	failures += _check((dialog.get_node("%DurationChip") as Control).visible == (days > 0),
		"Hourglass only shown for delayed Evolution")
	failures += _check((dialog.get_node("%DurationSuffix") as Label).text
		== (WeaponSchool.day_word(days) if days > 0 else "Instant"), "Preview timing label")
	failures += _check_weapon_equation(dialog.get_node("%RightWeaponRow") as PupationWeaponHoverRow,
		actual, "After", changed_slots)
	var attack_before := SealModifiers.effective_attack_damage(unit)
	var attack_after := SealModifiers.effective_attack_damage(actual)
	var hp_before := SealModifiers.effective_max_hp(unit)
	var hp_after := SealModifiers.effective_max_hp(actual)
	failures += _check_combat_preview(dialog, "Atk", attack_before, attack_after)
	failures += _check_combat_preview(dialog, "Hp", hp_before, hp_after)
	for side in ["Left", "Right"]:
		failures += _check_portrait_alignment(dialog, side)
	failures += _check_weapon_tag_comparison(dialog, unit.weapon, actual.weapon,
		before_changed_tags, after_changed_tags)
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
		failures += await _check_weapon_hover(host, dialog.get_node("%LeftWeaponRow") as PupationWeaponHoverRow)
		failures += await _check_weapon_hover(host, dialog.get_node("%RightWeaponRow") as PupationWeaponHoverRow)
	elif recipe == "Sword + Sword → Great Sword" and unit.is_adult_stage():
		await _snapshot(host, "/tmp/usability-training-aoe.png")
	elif recipe == "Bow + Mace → Great Horn" and unit.is_adult_stage():
		await _snapshot(host, "/tmp/usability-training-replacement.png")
	dialog.queue_free()
	await host.get_tree().process_frame
	return failures


static func _check_weapon_equation(
	row: PupationWeaponHoverRow, unit: RosterUnitData, label: String, changed_slots: Array[int] = []
) -> int:
	var failures := _check(row.weapon != null and row.weapon.display_name == unit.weapon.display_name,
		label + " Weapon hover matches actual Unit")
	var equation := row.get_node_or_null("TrainingEquation") as HBoxContainer
	failures += _check_training_equation(equation, unit, label, changed_slots)
	if equation != null:
		failures += _check(row.get_global_rect().grow(1.0).encloses(equation.get_global_rect()),
			label + " Training equation fits its comparison row")
	return failures


static func _check_training_equation(
	equation: HBoxContainer, unit: RosterUnitData, label: String, changed_slots: Array[int] = []
) -> int:
	var failures := _check(equation != null, label + " Training equation exists")
	if equation == null:
		return failures
	failures += _check(equation.get_script() == TRAINING_EQUATION_SCRIPT, label + " uses the shared equation renderer")
	var separators: Array[String] = []
	for child in equation.get_children():
		if child is Label:
			separators.append((child as Label).text)
	failures += _check(separators == ["+", "="], label + " shows a two-slot equation")
	for index in 2:
		var slot := equation.get_node_or_null("TrainingSlot%d" % (index + 1)) as PanelContainer
		failures += _check(slot != null and slot.visible, label + " Training slot is visible")
		if slot == null:
			continue
		var paper := slot.get_theme_stylebox("panel") as StyleBoxTexture
		var expected_texture := CHANGED_SLOT_TEXTURE if changed_slots.has(index) else SLOT_TEXTURE
		failures += _check(paper != null and paper.texture != null
			and paper.texture.resource_path == expected_texture.resource_path,
			"%s slot %d uses the %s paper border" % [label, index + 1,
				"blue changed" if changed_slots.has(index) else "green unchanged"])
		failures += _check(slot.custom_minimum_size == Vector2(64, 64) and slot.get_child_count() == 1,
			label + " Training slot keeps the Unit card's paper frame")
		if slot.get_child_count() != 1:
			continue
		var content := slot.get_child(0)
		if index >= unit.weapon_trainings.size():
			failures += _check(content is Label and (content as Label).text == "Empty",
				label + " unused Training slot is explicitly Empty")
		else:
			var weapon := WeaponSchool.load_weapon(WeaponSchool.base_weapon_path(unit.weapon_trainings[index]))
			failures += _check_equation_icon(content, weapon, label + " ordered Training %d" % index)
	var result := equation.get_node_or_null("ResultWeapon")
	failures += _check_equation_icon(result, unit.weapon, label + " resulting Weapon")
	return failures


static func _check_equation_icon(node: Node, weapon: WeaponData, label: String) -> int:
	var icon := node as TextureRect
	return _check(icon != null and icon.visible and icon.custom_minimum_size == Vector2(48, 48)
		and icon.texture != null and weapon != null and weapon.icon != null
		and icon.texture.resource_path == weapon.icon.resource_path, label + " icon matches gameplay")


static func _check_weapon_tag_comparison(
	dialog: Control, before: WeaponData, after: WeaponData,
	before_changed: Array[String], after_changed: Array[String]
) -> int:
	return _check_weapon_tags(dialog.get_node("%LeftWeaponTags") as HFlowContainer, before, before_changed) \
		+ _check_weapon_tags(dialog.get_node("%RightWeaponTags") as HFlowContainer, after, after_changed)


static func _check_weapon_tags(row: HFlowContainer, weapon: WeaponData, changed: Array[String]) -> int:
	var range_label := "Mid Range" if weapon.formation_line == WeaponData.FormationLine.MID \
		else str(WeaponData.FORMATION_LINE_LABELS[weapon.formation_line])
	var labels: Array[String] = [range_label, "Scaling"]
	if weapon.damage_type == WeaponData.DamageType.BLUNT:
		labels.append("Blunt")
	if weapon.targeting_mode == WeaponData.TargetingMode.AOE:
		labels.append("AOE")
	var failures := _check(row.get_child_count() == labels.size(), str(row.name) + " has the exact Weapon tags")
	var default_tag: TagChip = TAG_CHIP_SCENE.instantiate()
	var default_panel := default_tag.get_theme_stylebox("panel")
	default_tag.free()
	for index in mini(row.get_child_count(), labels.size()):
		var tag := row.get_child(index) as TagChip
		var label := "%s %s" % [row.name, labels[index]]
		failures += _check(tag != null and tag.visible, label + " tag is visible")
		if tag == null:
			continue
		failures += _check((tag.get_node("%Label") as Label).text == labels[index], label + " caption preserved")
		var paper := tag.get_theme_stylebox("panel")
		if changed.has(labels[index]):
			var changed_paper := paper as StyleBoxTexture
			failures += _check(changed_paper != null and changed_paper.texture == CHANGED_SLOT_TEXTURE,
				label + " change uses the blue paper border")
		else:
			failures += _check(paper == default_panel, label + " unchanged tag keeps its default style")
		failures += _check(row.get_global_rect().grow(1.0).encloses(tag.get_global_rect()), label + " fits its row")
		var icons: Array[Texture2D] = []
		if index == 1:
			icons = StatDisplay.textures_for_damage_stat(weapon.damage_stat)
		for icon_index in 2:
			var icon := tag.get_node("%IconA" if icon_index == 0 else "%IconB") as TextureRect
			failures += _check(icon.visible == (icon_index < icons.size()), label + " keeps the expected icon count")
			if icon_index < icons.size():
				failures += _check(icon.texture == icons[icon_index], label + " keeps the actual scaling icon")
		failures += _check((tag.get_node("%Glue") as Label).visible == (icons.size() == 2),
			label + " scaling icon separator is correct")
	return failures


static func _training_equation_reuse(host: Control) -> int:
	var failures := 0
	var dialog: PupationConfirmDialog = TRAINING_SCENE.instantiate()
	host.add_child(dialog)
	var units: Array[RosterUnitData] = [
		make_unit([WeaponSchool.Id.SWORD, WeaponSchool.Id.BOW], true),
		make_unit([], false),
		make_unit([WeaponSchool.Id.BOW], true),
		make_unit([WeaponSchool.Id.SWORD, WeaponSchool.Id.SWORD], true),
		make_unit([WeaponSchool.Id.MACE, WeaponSchool.Id.SWORD], true),
		make_unit([WeaponSchool.Id.BOW, WeaponSchool.Id.BOW], true),
	]
	# Bow Training also removes AOE from Great Sword and Blunt from Warhammer.
	var changed_slots: Array[Array] = [[0], [0], [1], [1], [0, 1], []]
	var before_changed_tags: Array[Array] = [
		["Scaling"], ["Melee", "Scaling"], [], ["Melee", "AOE"], ["Melee", "Blunt"], [],
	]
	var after_changed_tags: Array[Array] = [
		["Scaling"], ["Ranged", "Scaling"], [], ["Ranged"], ["Ranged"], [],
	]
	for index in units.size():
		var unit := units[index]
		dialog.setup(unit, WeaponSchool.Id.BOW)
		for frame in 4:
			await host.get_tree().process_frame
		var actual := unit.duplicate(true) as RosterUnitData
		actual.apply_pupation_training(WeaponSchool.Id.BOW)
		failures += _check_weapon_equation(dialog.get_node("%LeftWeaponRow") as PupationWeaponHoverRow, unit, "Reused before")
		var expected_changes: Array[int] = []
		expected_changes.assign(changed_slots[index])
		failures += _check_weapon_equation(dialog.get_node("%RightWeaponRow") as PupationWeaponHoverRow,
			actual, "Reused after %d" % index, expected_changes)
		var before_changes: Array[String] = []
		var after_changes: Array[String] = []
		before_changes.assign(before_changed_tags[index])
		after_changes.assign(after_changed_tags[index])
		failures += _check_weapon_tag_comparison(dialog, unit.weapon, actual.weapon,
			before_changes, after_changes)
		failures += _check((dialog.get_node("Center/Panel") as Control).size.y < 1000.0,
			"Reused Training confirmation fits play height")
		if expected_changes.is_empty():
			await _snapshot(host, "/tmp/usability-training-unchanged.png")
		elif unit.weapon.targeting_mode == WeaponData.TargetingMode.AOE:
			await _snapshot(host, "/tmp/usability-training-removed-aoe.png")
		elif unit.weapon.damage_type == WeaponData.DamageType.BLUNT:
			await _snapshot(host, "/tmp/usability-training-removed-blunt.png")
	dialog.queue_free()
	await host.get_tree().process_frame
	return failures


static func _check_weapon_hover(host: Control, row: PupationWeaponHoverRow) -> int:
	var result := row.get_node("TrainingEquation/ResultWeapon") as Control
	var point := result.get_global_transform_with_canvas() * (result.size * 0.5)
	await _move_pointer(host, point)
	var failures := _check(host.get_viewport().gui_get_hovered_control() == row,
		"Training equation preserves the containing Weapon hover")
	var overlay := DetailTooltipPopup._instance
	var tip := overlay._tip as WeaponDetailCard if is_instance_valid(overlay) else null
	failures += _check(is_instance_valid(tip) and tip.is_visible_in_tree() and tip.weapon_data == row.weapon,
		"Training result icon opens its actual Weapon detail")
	await _snapshot(host, "/tmp/usability-training-equation-hover-%s.png" % row.name)
	await _move_pointer(host, Vector2(4, 4))
	return failures


static func _move_pointer(host: Control, point: Vector2) -> void:
	host.get_viewport().warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = host.get_viewport().get_final_transform() * point
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await host.get_tree().create_timer(0.4).timeout


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
	var weapon_row := dialog.get_node("%%%sWeaponRow" % side) as Control
	var first_slot := weapon_row.get_node("TrainingEquation/TrainingSlot1") as Control
	var result_weapon := weapon_row.get_node("TrainingEquation/ResultWeapon") as Control
	var equation_center := (first_slot.get_global_rect().position.x
		+ result_weapon.get_global_rect().end.x) * 0.5
	failures += _check(absf(equation_center - weapon_row.get_global_rect().get_center().x) <= 1.0,
		side + " visible Training equation is centered in its row")
	failures += _check(absf(equation_center - body_center) <= 2.0,
		side + " visible Training equation is centered below the Unit body")
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
