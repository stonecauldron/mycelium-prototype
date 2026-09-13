extends Control

## Visual verification using production scenes. Saves captures to /private/tmp.
var _stage: Control
var _unit: RosterUnitData


func _ready() -> void:
	_run.call_deferred()


func _mount(path: String, at: Vector2 = Vector2.ZERO) -> Control:
	var node := load(path).instantiate() as Control
	_stage.add_child(node)
	node.position = at
	node.set_meta("preview_position", at)
	return node


func _clear() -> void:
	if is_instance_valid(_stage):
		remove_child(_stage)
		_stage.queue_free()
		await get_tree().process_frame
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)


func _capture(name: String) -> void:
	for i in 10:
		await get_tree().process_frame
	for child in _stage.get_children():
		if child is Control and child.has_meta("preview_position"):
			child.position = child.get_meta("preview_position")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/private/tmp/biomass-" + name + ".png")
	print("Captured ", name)


func _run() -> void:
	Engine.max_fps = 60
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1920, 1080)
	RenderingServer.set_default_clear_color(Color(0.72, 0.73, 0.68))
	GameState.run_started = true
	GameState.current_day = 2
	GameState.clear_pending_seal_choice()
	GameState.biomass.amount = 10000
	var units := StarterPackages.build_units(&"great_hammer")
	_unit = units[1]
	_unit.cap_mutation = load("res://assets/base/nursery/mutations/cap/bank.tres") as MutationData
	_unit.biomass_bank = 10000
	GameState.troop.seed_if_empty(units)
	await _clear()
	for i in 4:
		var hud := _mount("res://assets/ui/biomass_chip/biomass_chip.tscn", Vector2(30 + i * 260, 20))
		hud.get_node("%BiomassAmount").text = BiomassDisplay.number([0, 3, 1000, 10000][i])
	var bank := _unit.cap_mutation
	var offer := _mount("res://assets/base/shop/shop_offer_card.tscn") as ShopOfferCard
	offer.setup("Mutation", bank.title_text(), 4, {"mutation": bank}, load("res://assets/base/nursery/mutations/mutation_icon.png"), 0, false, bank.tint, bank.subtitle_text())
	offer.set_meta("preview_position", Vector2(30, 160))
	var fert := load("res://assets/base/nursery/fertilizers/brute_force.tres") as FertilizerData
	var fert_offer := _mount("res://assets/base/shop/shop_offer_card.tscn") as ShopOfferCard
	fert_offer.setup("Fertilizer", fert.display_name, 2, {"fertilizer": fert}, null, 1, false, fert.tint, fert.subtitle_text())
	fert_offer.set_meta("preview_position", Vector2(340, 160))
	for i in 2:
		var seal := _mount("res://assets/base/seals/seal_card.tscn", Vector2(660 + i * 380, 160)) as SealCard
		seal.setup(load("res://assets/base/seals/" + ["phosphorus_mining", "golden_mould"][i] + ".tres"))
		seal.size = Vector2(350, 540)
		seal.set_selected(i == 1)
	var detail := _mount("res://assets/base/nursery/mutation_detail_card/mutation_detail_card.tscn", Vector2(1440, 160)) as MutationDetailCard
	detail.setup(bank)
	var weapon := _mount("res://assets/base/weapon_detail_card/weapon_detail_card.tscn", Vector2(1440, 660)) as WeaponDetailCard
	weapon.setup(load("res://assets/weapons/sickle/sickle.tres"), false)
	for i in 3:
		var label := StatDisplay.make_rich_label("Gain 10000 biomass after a battle.", 24, StatDisplay.INK, 180 + 30 * i)
		_stage.add_child(label)
		label.position = Vector2(30 + i * 280, 770)
		label.size.x = 180 + 30 * i
	await _capture("cards")
	await _clear()
	var card := _mount("res://assets/base/unit_card/unit_card.tscn") as UnitCard
	card.setup(_unit)
	card.set_meta("preview_position", Vector2(70, 100))
	var unit_detail := _mount("res://assets/base/unit_detail_card/unit_detail_card.tscn", Vector2(300, 50)) as UnitDetailCard
	unit_detail.setup(_unit, false, false)
	var spore := _mount("res://assets/base/spore_detail_card/spore_detail_card.tscn", Vector2(900, 50)) as SporeDetailCard
	spore.setup(load("res://assets/base/nursery/common_spore.tres") as SporeData)
	var bin := _mount("res://assets/base/composting_bin/composting_bin.tscn", Vector2(1550, 600))
	var tip := bin._make_custom_tooltip("") as Control
	_stage.add_child(tip)
	tip.set_process(false)
	tip.set_meta("preview_position", Vector2(1450, 100))
	await _capture("details")
	await _clear()
	var sell := _mount("res://assets/base/shop/sell_overlay/sell_overlay.tscn") as ShopSellOverlay
	sell.show_amount(2)
	var popup: BiomassNumber = load("res://assets/vfx/biomass_number/biomass_number.tscn").instantiate()
	_stage.add_child(popup)
	popup.position = Vector2(950, 750)
	popup.display(10)
	await _capture("gains")
	await _clear()
	var seal_dialog: SealChoiceDialog = load("res://assets/base/seals/seal_choice_dialog.tscn").instantiate()
	var seals: Array[SealData] = []
	for path in ["phosphorus_mining", "radioactivity", "rotten_thumb"]:
		seals.append(load("res://assets/base/seals/" + path + ".tres") as SealData)
	seal_dialog.setup(seals)
	_stage.add_child(seal_dialog)
	await _capture("seal-choice")
	await _clear()
	var overlay := FlagSealsOverlay.new()
	var owned_tip := overlay._make_seal_block(seals[0])
	_stage.add_child(owned_tip)
	owned_tip.position = Vector2(100, 100)
	owned_tip.size.x = 280
	overlay.free()
	await _capture("owned-seal")
	await _clear()
	var compost := _mount("res://assets/base/pupation/compost_confirm_dialog.tscn") as CompostConfirmDialog
	compost.setup(_unit)
	await _capture("compost")
	await _clear()
	var training := _mount("res://assets/base/pupation/pupation_confirm_dialog.tscn") as PupationConfirmDialog
	training.setup(_unit, WeaponSchool.Id.SWORD)
	await _capture("training")
	await _clear()
	DaySummaryFeed.add_biomass_earned(10000)
	_unit.last_death_biomass_yield = 10000
	DaySummaryFeed.add_fallen_unit(_unit)
	_mount("res://assets/day_summary/day_summary.tscn")
	await _capture("summary")
	await _clear()
	var base: Node = load("res://assets/base/base.tscn").instantiate()
	_stage.add_child(base)
	await _capture("base")
	base._select_tab(1, true)
	await _capture("nursery")
	await _clear()
	var combat: Node = load("res://assets/combat/combat_stage/combat_stage.tscn").instantiate()
	_stage.add_child(combat)
	await _capture("combat")
	await _clear()
	get_tree().quit()
