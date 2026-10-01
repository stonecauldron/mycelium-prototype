extends "res://.scratch/shared-usability/cocoon_drag_preview_checks.gd"

var _checks_count := 0

func _run() -> void:
	Analytics.ga = null
	GameState.reset_run()
	GameState.pending_seal_choice = false
	GameState.current_day = 2
	GameState.biomass.amount = 50
	GameState.troop.seed_if_empty(StarterPackages.build_units(&"great_sword_spear"))
	GameState.troop.squad.fill(null)
	GameState.troop.bench.fill(null)
	child = CHECKS.make_unit([], false)
	adult = CHECKS.make_unit([WeaponSchool.Id.SWORD], true)
	GameState.troop.squad[0] = child
	GameState.troop.bench[0] = adult
	base = preload("res://assets/base/base.tscn").instantiate()
	get_tree().root.add_child(base)
	get_tree().current_scene = base
	host = base.get_node("HudLayer/HudRoot") as Control
	colony = base.get_node("%ColonyScreen") as TroopSelectionScreen
	await get_tree().create_timer(1.3).timeout
	await _move(Vector2(4,4))
	await _weapon_details()
	var dialog := preload("res://assets/base/pupation/pupation_confirm_dialog.tscn").instantiate() as PupationConfirmDialog
	dialog.setup(child, WeaponSchool.Id.BOW)
	host.add_child(dialog)
	await _settle()
	_check_speed(dialog._comparison, "1.5s", "1.15s", "−0.35s", 1, "faster Child")
	await _snapshot("speed-faster-child")
	dialog.setup(adult, WeaponSchool.Id.MACE)
	await _settle()
	_check_speed(dialog._comparison, "0.75s", "1.75s", "+1s", -1, "slower Adult")
	await _snapshot("speed-slower-adult")
	var spear := CHECKS.make_unit([WeaponSchool.Id.SPEAR], true)
	dialog.setup(spear, WeaponSchool.Id.SHIELD)
	await _settle()
	_check_speed(dialog._comparison, "1s", "1s", "", 0, "unchanged after reused comparison")
	adult.attack_rate_multiplier = 2.0
	GameState.seals.add(load("res://assets/base/seals/wooden_clock.tres") as SealData)
	dialog.setup(adult, WeaponSchool.Id.MACE)
	await _settle()
	_check_speed(dialog._comparison, "0.31s", "0.73s", "+0.42s", -1, "Amok and Wooden Clock")
	_expect(is_equal_approx(dialog._comparison._preview_unit.attack_rate_multiplier, 2.0), "preview preserves Amok rate")
	_expect(is_equal_approx(AttackSpeedDisplay.for_unit(adult), 0.75 / 2.4), "persistent seconds match combat rate formula")
	await _snapshot("speed-persistent-rate")
	dialog.queue_free()
	GameState.seals = SealsCollection.new()
	adult.attack_rate_multiplier = 1.0
	await _settle()
	var bow := _slot(WeaponSchool.Id.BOW)
	await _start_drag(child, "squad")
	await _hover(bow)
	_expect(is_instance_valid(bow._drag_preview_tip), "actual Cocoon drag shows speed preview")
	if is_instance_valid(bow._drag_preview_tip):
		var comparison := bow._drag_preview_tip._comparison
		_check_speed(comparison, "1.5s", "1.15s", "−0.35s", 1, "result-only hover")
		_expect(comparison.result_only and not (comparison.get_node("%LeftColumn") as Control).visible, "passive preview remains result-only")
		_expect(comparison._right_speed_chip.is_visible_in_tree(), "passive speed chip is visible")
		await _snapshot("speed-result-only-hover")
	await _cancel_drag()
	_expect(GameState.biomass.amount == 50 and child.weapon_trainings.is_empty(), "inspection leaves gameplay unchanged")
	print("ATTACK_SPEED_UI_CHECKS checks=", _checks_count, " failures=", failures)
	DetailTooltipPopup.dismiss_current()
	base.queue_free()
	await _settle()
	get_tree().quit(failures)

func _weapon_details() -> void:
	var cards: Array[WeaponDetailCard] = []
	var weapons: Array[WeaponData] = [WeaponSchool.sickle(), WeaponSchool.resolve_weapon([WeaponSchool.Id.BOW])]
	for i in range(2):
		var card := preload("res://assets/base/weapon_detail_card/weapon_detail_card.tscn").instantiate() as WeaponDetailCard
		card.setup(weapons[i], false)
		host.add_child(card)
		cards.append(card)
	await _settle()
	for i in range(2):
		var card := cards[i]
		card.fit_to_content()
		card.position = Vector2(500.0 + float(i) * 450.0, 140.0)
	await _settle()
	for i in range(2):
		var card := cards[i]
		var speed := card.get_node("%SpeedChip") as StatChip
		var value := speed.get_node("%Value") as Label
		var damage := card.get_node("%DmgLabel") as Label
		_expect(value.text == ["1.5s", "1.15s"][i], "weapon detail retains exact seconds " + weapons[i].display_name)
		_expect(damage.text == "Base Damage: %d" % weapons[i].base_damage, "weapon detail Base Damage copy")
		_expect(_bounds(value).end.x <= _bounds(damage).position.x, "detail speed text precedes damage without overlap")
		_expect(speed.icon == AttackSpeedDisplay.ICON, "detail uses stopwatch artwork")
		print("DETAIL_GEOMETRY ", weapons[i].display_name, " chip=", _bounds(speed), " value=", _bounds(value), " icon=", _bounds(speed.get_node("%Icon")), " damage=", _bounds(damage), " card=", _bounds(card))
	await _snapshot("speed-weapon-details")
	for card in cards:
		card.queue_free()
	await _settle()

func _check_speed(comparison: TrainingComparison, before: String, after: String, delta_text: String, direction: int, label: String) -> void:
	var left := comparison.get_node("%LeftSpeedChip") as StatChip
	var right := comparison.get_node("%RightSpeedChip") as StatChip
	var delta := comparison.get_node("%RightSpeedDelta") as Label
	var left_value := left.get_node("%Value") as Label
	var right_value := right.get_node("%Value") as Label
	_expect(left_value.text == before and right_value.text == after and delta.text == delta_text, label + " explicit seconds/delta")
	_expect(left_value.get_theme_color("font_color") == Color.WHITE and left.chip_size == Vector2(40,40), label + " baseline neutral")
	_expect(right.icon == AttackSpeedDisplay.ICON and left.icon == AttackSpeedDisplay.ICON, label + " stopwatch texture")
	if direction == 0:
		_expect(right.chip_size == Vector2(40,40) and right.value_font_size == 20 and right_value.get_theme_color("font_color") == Color.WHITE, label + " clears prior emphasis/color")
	else:
		var color := StatDisplay.GAIN_COLOR if direction > 0 else StatDisplay.LOSS_COLOR
		_expect(delta.get_theme_color("font_color") == color, label + " correct faster/slower color")
		_expect(right.chip_size == Vector2(52,52) and right.value_font_size == 26 and delta.get_theme_font_size("font_size") == 24, label + " 130% emphasis")
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_expect(viewport_rect.encloses(_bounds(right_value)) and viewport_rect.encloses(_bounds(delta)), label + " visible value/delta fit viewport")
	print("SPEED_GEOMETRY ", label, " left=", _bounds(left), " left_value=", _bounds(left_value), " right=", _bounds(right), " right_value=", _bounds(right_value), " right_group=", _bounds(right.get_parent()), " delta=", _bounds(delta), " comparison=", _bounds(comparison))

func _bounds(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _expect(ok: bool, label: String) -> void:
	_checks_count += 1
	if not ok:
		failures += 1
	print("PASS " if ok else "FAIL ", label)
