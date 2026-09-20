extends Node

## Offline capture director. Production scenes, attainable setups, no preference writes.
const OUTPUT := "res://steam/store assets/2026-09-20-store-refresh"
const BASE := "res://assets/base/base.tscn"
var scenario := "probe"
var _pointer: Sprite2D
var _pointer_pos := Vector2(1760, 940)
var _pressed := false
var _frame := 0
var _events: Array[Dictionary] = []
var _lossless: FileAccess
var _lossless_frames := 0
var _lossless_busy := false
var _lossless_size := Vector2i(2560, 1440)
var _lineage_parent: RosterUnitData
var _capture_probe := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("scenario="):
			scenario = arg.trim_prefix("scenario=")
		elif arg == "capture_probe":
			_capture_probe = true
		elif arg.begins_with("raw_capture="):
			_lossless = FileAccess.open(arg.trim_prefix("raw_capture="), FileAccess.WRITE)
			assert(_lossless != null)
	if _lossless != null:
		RenderingServer.frame_post_draw.connect(_record_lossless_frame)
	_run.call_deferred()


func _record_lossless_frame() -> void:
	assert(not _lossless_busy, "Capture must not re-enter during GPU readback")
	_lossless_busy = true
	var frame := get_viewport().get_texture().get_image()
	if _lossless_frames == 0:
		print("CAPTURE native RGB ", _lossless_size)
	# macOS settles from the initial 1080p window to the 1440p backing viewport.
	# Normalize only those startup frames; subsequent pixels retain native detail.
	if frame.get_size() != _lossless_size:
		frame.resize(_lossless_size.x, _lossless_size.y, Image.INTERPOLATE_LANCZOS)
	frame.convert(Image.FORMAT_RGB8)
	_lossless.store_buffer(frame.get_data())
	_lossless_frames += 1
	_lossless_busy = false


func _process(_delta: float) -> void:
	_frame += 1


func _frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func _mark(label: String) -> void:
	_events.append({"frame": _frame, "seconds": float(_frame) / 60.0, "action": label})
	print("EVENT ", _frame, " ", label)


func _shot(name: String) -> void:
	if _lossless != null or _capture_probe:
		# The existing stills are already lossless. Avoid nested GPU readbacks.
		await get_tree().process_frame
		return
	var was_visible := _pointer.visible
	_pointer.hide()
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUTPUT + "/sources/stills/" + name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	_pointer.visible = was_visible
	print("CAPTURE ", name)


func _setup_pointer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_pointer = Sprite2D.new()
	_pointer.texture = load("res://assets/ui/cursors/hand_point.svg")
	_pointer.centered = false
	_pointer.offset = Vector2(-22, -12)
	_pointer.position = _pointer_pos
	layer.add_child(_pointer)
	_pointer.hide()


func _center(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)


func _motion(to: Vector2, frames: int = 36) -> void:
	_pointer.show()
	var start := _pointer_pos
	for i in frames:
		var t := smoothstep(0.0, 1.0, float(i + 1) / float(frames))
		var next := start.lerp(to, t)
		var event := InputEventMouseMotion.new()
		event.position = next
		event.global_position = next
		event.relative = next - _pointer_pos
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if _pressed else 0
		get_viewport().push_input(event, true)
		_pointer_pos = next
		_pointer.position = next
		await get_tree().process_frame


func _button(down: bool) -> void:
	_pressed = down
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = _pointer_pos
	event.global_position = _pointer_pos
	_pointer.texture = load("res://assets/ui/cursors/hand_point_pressed.svg" if down else "res://assets/ui/cursors/hand_point.svg")
	get_viewport().push_input(event, true)


func _click(control: Control) -> void:
	await _motion(_center(control))
	_button(true)
	await _frames(7)
	_button(false)
	await _frames(5)


func _drag(from: Control, to: Control) -> void:
	await _motion(_center(from), 25)
	_button(true)
	await _frames(6)
	await _motion(_center(to), 64)
	await _frames(8)
	_button(false)
	await _frames(12)


func _make_unit(index: int, schools: Array, mutation: String = "", child: bool = false, fertilizer_name: String = "") -> RosterUnitData:
	var nursery := NurseryData.new()
	nursery.seed_if_empty()
	nursery.plant_spore(0, nursery.make_fresh_common_spore())
	var fert_names := ["reinforced_chitin", "finesse", "brute_force"]
	var fertilizer: String = fertilizer_name if not fertilizer_name.is_empty() else fert_names[index % 3]
	nursery.apply_fertilizer_to_plot(0, load("res://assets/base/nursery/fertilizers/" + fertilizer + ".tres"))
	if not mutation.is_empty():
		(nursery.plots[0] as NurseryPlotData).apply_mutation(load("res://assets/base/nursery/mutations/" + mutation + ".tres"))
	nursery.advance_day()
	nursery.advance_day()
	var unit := nursery.harvest(0)[0]
	var names := ["Darwin", "Curie", "Mendel", "Hooke", "Linnaeus", "Pasteur", "Rosalind", "Haeckel", "Wallace", "Lamarck", "Franklin", "Fleming", "Koch"]
	unit.lineage_name = names[index % names.size()]
	unit.display_name = unit.lineage_name
	for school in schools:
		unit.apply_pupation_training(int(school))
	if child:
		var lineage := NurseryData.new()
		lineage.seed_if_empty()
		lineage.plant_spore(0, SporeData.from_fallen_unit(unit))
		lineage.advance_day()
		unit = lineage.harvest(0)[0]
	return unit


func _roster_record(label: String) -> void:
	var roster: Array = []
	var children := 0
	var classes := [0, 0, 0]
	var previous := 2
	var great_sword := false
	var great_horn := false
	for i in GameState.troop.squad.size():
		var unit: RosterUnitData = GameState.troop.squad[i]
		if unit == null:
			continue
		assert(not unit.weapon.display_name.to_lower().contains("mortar"), "Mortar units are excluded")
		var role := int(unit.weapon.formation_line)
		assert(role <= previous, "Range classes must run Ranged/Mid/Melee from rear to front")
		previous = role
		classes[role] += 1
		if not unit.is_adult_stage():
			children += 1
		great_sword = great_sword or unit.weapon.display_name == "Great Sword"
		great_horn = great_horn or unit.weapon.display_name == "Great Horn"
		roster.append({"slot": i, "name": unit.display_name, "stage": "Adult" if unit.is_adult_stage() else "Child", "weapon": unit.weapon.display_name, "range_class": WeaponData.FORMATION_LINE_LABELS[role], "body_mutation": unit.body_mutation.display_name if unit.body_mutation != null else "", "cap_mutation": unit.cap_mutation.display_name if unit.cap_mutation != null else ""})
	assert(children == 3, "Capture Squad needs three Children")
	assert(classes == [4, 3, 3], "Capture Squad needs four Melee, three Mid, three Ranged")
	assert(great_sword and great_horn, "Both featured Great weapons must be present")
	assert(GameState.troop.squad[9].weapon.display_name == "Great Shield", "Frontline shield required")
	_events.append({"roster_label": label, "children": children, "adults": roster.size() - children, "class_counts_melee_mid_ranged": classes, "order": "rear to front", "roster": roster})


func _seed_state() -> void:
	seed(2092026)
	GameState.run_started = true
	GameState.current_day = 7
	GameState.run_seed = 2092026
	GameState.clear_pending_seal_choice()
	GameState.biomass.amount = 28
	GameState.show_start_combat_hint = false
	GameState.show_plot_plant_hint = false
	GameState.show_plot_harvest_hint = false
	GameState.combat_fast_forward = 1
	GameState.troop.unlock_all_squad_slots()
	if scenario == "lineage_sword":
		_seed_lineage_sword_state()
		return
	# Rear-to-front: three Ranged, three Mid, four Melee. Children inherit actual Trainings.
	var schools := [[3, 3], [0, 3], [3], [4, 3], [2], [2, 2], [0], [0, 0], [0, 1], [1, 1]]
	var mutations := ["", "", "cap/inky", "", "", "", "cap/boom", "body/thorny", "", "body/rubber"]
	var units: Array[RosterUnitData] = []
	for i in schools.size():
		units.append(_make_unit(i, schools[i], mutations[i], i in [1, 4, 6]))
	GameState.troop.seed_if_empty(units)
	GameState.troop.bench[0] = _make_unit(10, [3] if scenario == "formation" else [4])
	if scenario == "training":
		# A normally attainable Child inherits its parent's Sword Training.
		GameState.troop.bench[0] = _make_unit(10, [WeaponSchool.Id.SWORD], "", true)
	GameState.troop.bench[1] = _make_unit(11, [])
	_roster_record("initial")
	GameState.pupation.try_place(_make_unit(12, []), WeaponSchool.Id.MACE)
	GameState.nursery.seed_if_empty()
	GameState.nursery.unlocked_plot_count = 4
	for i in range(1, 4):
		GameState.nursery.plant_spore(i, GameState.nursery.make_fresh_common_spore())
	var plots := GameState.nursery.plots
	(plots[1] as NurseryPlotData).tick_day()
	(plots[2] as NurseryPlotData).tick_day()
	(plots[2] as NurseryPlotData).tick_day()
	(plots[3] as NurseryPlotData).apply_mutation(load("res://assets/base/nursery/mutations/cap/boom.tres"))
	GameState.nursery.add_death_spore(_make_unit(0, [0], "body/rubber"))
	GameState.nursery.add_fertilizer(load("res://assets/base/nursery/fertilizers/reinforced_chitin.tres"))
	GameState.nursery.add_mutation(load("res://assets/base/nursery/mutations/cap/bank.tres"))
	_choose_enemies(7, 200)


func _seed_lineage_sword_state() -> void:
	# A small, attainable cast for the requested lineage demonstration.
	# Triploid Cells supplies the Sword Adult's low Constitution through real growth.
	var units: Array[RosterUnitData] = [
		_make_unit(0, [3]),
		_make_unit(1, [3], "", true),
		_make_unit(9, [0], "body/rubber", false, "triploid_cells"),
	]
	GameState.troop.seed_if_empty(units)
	_lineage_parent = units[2]
	GameState.nursery.seed_if_empty()
	GameState.nursery.unlocked_plot_count = 4
	GameState.nursery.stock.clear()
	GameState.nursery.first_lineage_spore = null
	GameState.current_day = 1
	# Select an authored Day 2 composition: one frontliner, two supporting throwers.
	var found := false
	for candidate in range(1, 2000):
		GameState.run_seed = candidate
		var specs := EnemyComposer.specs_for_day(2)
		var counts := {}
		for spec in specs:
			var name := spec.unit_data.display_name
			counts[name] = int(counts.get(name, 0)) + 1
		if counts.get("Solar Sword", 0) == 1 and counts.get("Rose Thorn", 0) == 2 and specs.size() == 3:
			GameState.upcoming_enemy_formation = specs
			_events.append({"setup_day": 2, "run_seed": candidate, "enemies": counts, "casting": "dedicated Sword lineage battle"})
			found = true
			break
	assert(found, "Need a real three-Unit Day 2 enemy composition")
	var roster: Array = []
	for i in units.size():
		var unit := units[i]
		roster.append({"slot": i, "name": unit.display_name, "stage": "Adult" if unit.is_adult_stage() else "Child", "weapon": unit.weapon.display_name, "range_class": WeaponData.FORMATION_LINE_LABELS[int(unit.weapon.formation_line)], "body_mutation": unit.body_mutation.display_name if unit.body_mutation != null else "", "cap_mutation": unit.cap_mutation.display_name if unit.cap_mutation != null else ""})
	assert(units[0].weapon.display_name == "Bow" and units[1].weapon.display_name == "Bow")
	assert(_lineage_parent.is_adult_stage() and _lineage_parent.weapon.display_name == "Sword")
	_events.append({"roster_label": "dedicated_lineage", "children": 1, "adults": 2, "class_counts_melee_mid_ranged": [1, 0, 2], "order": "rear to front", "roster": roster})


func _lineage_sword_battle() -> void:
	var enemy: Array[RosterUnitData] = []
	var stats_rng := RandomNumberGenerator.new()
	stats_rng.seed = 2092026
	for spec in GameState.upcoming_enemy_formation:
		enemy.append(RosterUnitData.create_enemy(spec.unit_data.display_name, spec.unit_data.make_stats(stats_rng), spec.unit_data))
	BattleLaunch.set_enemy_roster(enemy)
	var stage := await _scene("res://assets/combat/combat_stage/combat_stage.tscn")
	for unit: Unit in stage.get_node("World/PlayerTroop/Units").get_children():
		unit.died.connect(_record_player_death)
	for i in 4800:
		await _frames(1)
		var current := get_tree().current_scene
		if current == null:
			continue
		if current.scene_file_path.contains("day_summary"):
			_mark("dedicated_battle_won")
			await _frames(90)
			return
		if current.scene_file_path.contains("game_over"):
			break
	assert(false, "The dedicated lineage battle must finish with surviving ranged support")


func _choose_enemies(day: int, first_seed: int) -> void:
	var best_score := -1.0
	var best_seed := first_seed
	for s in range(first_seed, first_seed + 120):
		GameState.run_seed = s
		var specs := EnemyComposer.specs_for_day(day)
		var types := {}
		for spec in specs:
			types[spec.unit_data.display_name] = true
		var score := float(specs.size()) + float(types.size() * 3)
		if types.size() < 2:
			score -= 12.0
		if score > best_score:
			best_score = score
			best_seed = s
	GameState.run_seed = best_seed
	GameState.current_day = day - 1
	GameState.upcoming_enemy_formation = EnemyComposer.specs_for_day(day)
	var types := {}
	for spec in GameState.upcoming_enemy_formation:
		var key := spec.unit_data.display_name
		types[key] = int(types.get(key, 0)) + 1
	print("ARMY day=", day, " seed=", best_seed, " types=", types)
	_events.append({"setup_day": day, "run_seed": best_seed, "enemies": types})


func _scene(path: String) -> Node:
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	return get_tree().current_scene


func _nursery_take() -> void:
	GameState.current_day = 6
	GameState.clear_upcoming_enemy_formation()
	var base := await _scene(BASE)
	base._select_tab(1, true)
	await _frames(75)
	await _shot("03-nursery")
	var nursery: NurseryScreen = base.get_node("%NurseryScreen")
	var tile: PlotTile = nursery._tiles[0]
	await _click(tile.get_node("%PlantButton"))
	assert(not (GameState.nursery.plots[0] as NurseryPlotData).is_empty(), "Plant input must succeed")
	_mark("planted")
	await _motion(Vector2(1080, 950), 24)
	await _frames(85)
	_mark("two_days_later")
	GameState.current_day += 2
	GameState.nursery.advance_day()
	GameState.nursery.advance_day()
	nursery._refresh()
	base._refresh_hud()
	await _frames(35)
	await _click(tile.get_node("%PlotVisualArea"))
	assert((GameState.nursery.plots[0] as NurseryPlotData).is_empty(), "Harvest input must succeed")
	_mark("harvested")
	await _motion(Vector2(1800, 930), 25)
	await _frames(155)
	await _shot("nursery-harvest-result")
	await _frames(45)


func _training_take() -> void:
	var base := await _scene(BASE)
	await _frames(90)
	await _shot("training-sword-child")
	var colony: TroopSelectionScreen = base.get_node("%ColonyScreen")
	var source: DropSlot = colony._bench_slots[0]
	var unit: RosterUnitData = GameState.troop.bench[0]
	assert(not unit.is_adult_stage() and unit.weapon.display_name == "Sword")
	var initial_day := GameState.current_day
	_mark("sword_child_ready")
	var destination: Control
	for cocoon: CocoonSlot in colony._cocoon_slots:
		if cocoon.school == WeaponSchool.Id.SWORD:
			destination = cocoon
	await _drag(source.get_node("%CardHost").get_child(0), destination)
	assert(colony._pupation_dialog != null, "Actual drag must open Training preview")
	var dialog := colony._pupation_dialog
	assert(dialog._preview_unit.weapon.display_name == "Great Sword", "Sword Child must preview a Great Sword")
	_mark("training_preview")
	await _motion(Vector2(1810, 920), 24)
	await _frames(140)
	await _shot("training-great-sword-preview")
	await _click(dialog.get_node("%ConfirmButton"))
	assert(GameState.pupation.get_occupant(WeaponSchool.Id.SWORD) == unit, "Training confirmation must succeed")
	_mark("training_started")
	# Retain only a brief confirmation handle; never advance time or show emergence.
	await _frames(18)
	assert(GameState.current_day == initial_day and not unit.is_adult_stage())
	assert(unit.weapon.display_name == "Sword" and unit.weapon_trainings.size() == 1)
	_events.append({"training_verified": true, "name": unit.display_name,
		"initial_stage": "Child", "initial_weapon": "Sword", "school": "Sword",
		"preview_weapon": "Great Sword", "confirmed": true, "day_advanced": false,
		"emergence_shown": false, "final_location": "Sword Cocoon"})


func _gardening_take() -> void:
	GameState.current_day = 6
	GameState.clear_upcoming_enemy_formation()
	GameState.nursery.stock.clear()
	GameState.nursery.first_lineage_spore = null
	var fertilizer: FertilizerData = load("res://assets/base/nursery/fertilizers/reinforced_chitin.tres")
	var mutation: MutationData = load("res://assets/base/nursery/mutations/cap/inky.tres")
	GameState.nursery.add_fertilizer(fertilizer)
	GameState.nursery.add_mutation(mutation)
	var base := await _scene(BASE)
	base._select_tab(1, true)
	await _frames(75)
	var nursery: NurseryScreen = base.get_node("%NurseryScreen")
	var tile: PlotTile = nursery._tiles[0]
	var plot: NurseryPlotData = GameState.nursery.plots[0]
	_mark("plant_start")
	await _click(tile.get_node("%PlantButton"))
	assert(plot.get_state() == NurseryPlotData.State.GROWING)
	_mark("planted")
	await _motion(Vector2(1080, 940), 20)
	await _frames(35)
	_mark("fertilize_start")
	await _drag(nursery._stock_slots[0].get_node("%CardHost").get_child(0), tile.get_node("%PlotVisualArea"))
	assert(plot.stack_fertilizers().has(fertilizer), "Fertilizer drag must apply to the growing Plot")
	assert(GameState.nursery.stock.get_at(0) == null)
	_mark("fertilized")
	await _motion(Vector2(1080, 940), 20)
	await _frames(40)
	_mark("mutate_start")
	await _drag(nursery._stock_slots[1].get_node("%CardHost").get_child(0), tile.get_node("%PlotVisualArea"))
	assert(plot.cap_mutation == mutation, "Mutation drag must apply to the same growing Plot")
	assert(GameState.nursery.stock.get_at(1) == null)
	_mark("mutated")
	await _motion(Vector2(1080, 940), 20)
	await _frames(45)
	_mark("two_days_later")
	GameState.current_day += 2
	GameState.nursery.advance_day()
	GameState.nursery.advance_day()
	nursery._refresh()
	base._refresh_hud()
	await _frames(35)
	_mark("harvest_start")
	await _click(tile.get_node("%PlotVisualArea"))
	assert(plot.is_empty() and nursery._hatch_toasts.size() == 1)
	var child: RosterUnitData = nursery._hatch_toasts[0].unit_data
	assert(child.cap_mutation.display_name == mutation.display_name)
	assert(child.applied_fertilizers.size() == 1)
	assert(child.applied_fertilizers[0].display_name == fertilizer.display_name)
	_mark("harvested")
	_events.append({"gardening_verified": true, "fertilizer": fertilizer.display_name, "mutation": mutation.display_name, "child": child.display_name})
	await _motion(Vector2(1800, 930), 25)
	await _frames(180)
	_mark("gardening_result")


func _lineage_take() -> void:
	# Follow an actual fallen Adult and the exact spore emitted by combat.
	if scenario != "lineage_sword":
		_lineage_parent = GameState.troop.squad[9]
	assert(_lineage_parent.is_adult_stage())
	GameState.nursery.stock.clear()
	GameState.nursery.first_lineage_spore = null
	if scenario == "lineage_sword":
		await _lineage_sword_battle()
	else:
		await _battle_take()
	assert(get_tree().current_scene.scene_file_path.contains("day_summary"), "Lineage capture must finish a real victory")
	assert(_lineage_parent.emitted_death_spore, "Featured Adult must die naturally in the recorded battle")
	if _capture_probe:
		_mark("dedicated_lineage_probe_passed")
		return
	var spore: SporeData
	for item in GameState.nursery.stock.slots:
		if item is SporeData and (item as SporeData).lineage_name == _lineage_parent.lineage_name:
			spore = item as SporeData
	assert(spore != null and spore.parent_generation == _lineage_parent.generation)
	await _click(get_tree().current_scene.get_node("%ContinueButton"))
	for i in 240:
		if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == BASE:
			break
		await _frames(1)
	assert(get_tree().current_scene.scene_file_path == BASE)
	var base := get_tree().current_scene
	base._select_tab(1, true)
	await _frames(90)
	# Day 2 grants a Seal before Nursery interactions can proceed. Complete the
	# real modal off-cut, then return to the lineage action.
	if GameState.pending_seal_choice:
		var colony: TroopSelectionScreen = base.get_node("%ColonyScreen")
		var dialog: SealChoiceDialog = colony._seal_dialog
		assert(dialog != null)
		await _click(dialog.get_node("%CardsRow").get_child(0))
		await _click(dialog.get_node("%ConfirmButton"))
		assert(not GameState.pending_seal_choice, "Seal UI must be completed before planting")
		_mark("seal_choice_completed")
		base._select_tab(1, true)
		await _frames(60)
	var nursery: NurseryScreen = base.get_node("%NurseryScreen")
	var slot_index := GameState.nursery.stock.slots.find(spore)
	var card: Control = nursery._stock_slots[slot_index].get_node("%CardHost").get_child(0)
	_mark("lineage_spore_visible")
	await _motion(_center(card), 30)
	await _frames(105)
	_mark("lineage_plant_start")
	await _drag(card, nursery._tiles[0].get_node("%PlotVisualArea"))
	var plot: NurseryPlotData = GameState.nursery.plots[0]
	assert(plot.planted_spore == spore and GameState.nursery.stock.slots.find(spore) == -1)
	_mark("lineage_planted")
	await _motion(Vector2(1080, 940), 20)
	await _frames(65)
	_mark("one_day_later")
	GameState.current_day += 1
	GameState.nursery.advance_day()
	nursery._refresh()
	base._refresh_hud()
	await _frames(40)
	_mark("lineage_harvest_start")
	await _click(nursery._tiles[0].get_node("%PlotVisualArea"))
	assert(plot.is_empty() and nursery._hatch_toasts.size() == 1)
	var child: RosterUnitData = nursery._hatch_toasts[0].unit_data
	assert(child.lineage_name == _lineage_parent.lineage_name)
	assert(child.generation == _lineage_parent.generation + 1)
	assert(child.display_name == UnitNames.format_unit_name(child.lineage_name, child.generation))
	assert(child.weapon_trainings == _lineage_parent.weapon_trainings)
	assert(child.body_mutation.display_name == _lineage_parent.body_mutation.display_name)
	_mark("lineage_harvested:" + child.display_name)
	_events.append({"lineage_verified": true, "parent": _lineage_parent.display_name, "parent_generation": _lineage_parent.generation, "spore": spore.display_name, "descendant": child.display_name, "descendant_generation": child.generation, "inherited_weapon": child.weapon.display_name, "inherited_body_mutation": child.body_mutation.display_name})
	await _motion(Vector2(1800, 930), 25)
	await _frames(210)
	_mark("lineage_result")


func _formation_take() -> void:
	var base := await _scene(BASE)
	await _frames(75)
	var colony: TroopSelectionScreen = base.get_node("%ColonyScreen")
	var first: RosterUnitData = GameState.troop.squad[1]
	await _drag(colony._squad_slots[1].get_node("%CardHost").get_child(0), colony._squad_slots[2])
	assert(GameState.troop.squad[2] == first, "Formation swap must succeed")
	_mark("squad_swap")
	await _motion(Vector2(1730, 940), 20)
	await _frames(65)
	var reserve: RosterUnitData = GameState.troop.bench[0]
	await _drag(colony._bench_slots[0].get_node("%CardHost").get_child(0), colony._squad_slots[0])
	assert(GameState.troop.squad[0] == reserve, "Bench exchange must succeed")
	_mark("bench_exchange")
	await _motion(Vector2(1730, 940), 24)
	await _frames(110)
	_roster_record("formation_result")
	await _shot("formation-result")
	await _frames(40)


func _record_player_death(unit: Unit) -> void:
	var mutation := unit.roster_data.cap_mutation
	_mark("player_death:" + unit.roster_data.display_name + ":" + (mutation.display_name if mutation != null else ""))
	if unit.roster_data == _lineage_parent:
		var screen_position: Vector2 = unit.get_global_transform_with_canvas() * Vector2.ZERO
		var viewport_size := get_viewport().get_visible_rect().size
		_events.append({"lineage_death": unit.roster_data.display_name, "seconds": float(_frame) / 60.0, "screen_x_1080p": screen_position.x * 1920.0 / viewport_size.x, "screen_y_1080p": screen_position.y * 1080.0 / viewport_size.y})


func _battle_take() -> void:
	_roster_record("battle_start")
	var day := 9
	var seed_start := 900
	if scenario == "battle_b":
		seed_start = 1700
	elif scenario in ["summary", "lineage"]:
		day = 7
		seed_start = 200
	elif scenario == "battle_elite":
		day = 10
		seed_start = 500
	_choose_enemies(day, seed_start)
	var enemy: Array[RosterUnitData] = []
	for spec in GameState.upcoming_enemy_formation:
		enemy.append(RosterUnitData.create_enemy(spec.unit_data.display_name, spec.unit_data.make_stats(), spec.unit_data))
	BattleLaunch.set_enemy_roster(enemy)
	var stage := await _scene("res://assets/combat/combat_stage/combat_stage.tscn")
	for unit: Unit in stage.get_node("World/PlayerTroop/Units").get_children():
		unit.died.connect(_record_player_death)
	await _frames(30)
	await _shot(scenario + "-approach")
	for second in range(1, 86 if scenario in ["summary", "lineage"] else 25):
		await _frames(60)
		if second in [2, 4, 6, 8, 10, 14, 18, 22, 24]:
			await _shot(scenario + "-%02d" % second)
		if get_tree().current_scene != null and get_tree().current_scene.scene_file_path.contains("day_summary"):
			await _frames(60)
			await _shot("05-day-summary")
			await _frames(90)
			break


func _run() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1920, 1080)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"SFX"), false)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), 0.0)
	_setup_pointer()
	_seed_state()
	get_tree().current_scene = null
	match scenario:
		"nursery": await _nursery_take()
		"gardening": await _gardening_take()
		"lineage", "lineage_sword": await _lineage_take()
		"training": await _training_take()
		"formation": await _formation_take()
		"battle_a", "battle_b", "battle_elite", "summary": await _battle_take()
		_:
			await _scene(BASE)
			await _frames(90)
			await _shot("probe")
			Audio.play_ui_cue(Sfx.Cue.HARVEST)
			await _frames(90)
	if scenario == "summary":
		assert(get_tree().current_scene.scene_file_path.contains("day_summary"), "Summary must come from a real battle victory")
	_mark("take_complete")
	if _lossless != null:
		RenderingServer.frame_post_draw.disconnect(_record_lossless_frame)
		_lossless.close()
		_events.append({"raw_frames": _lossless_frames, "raw_format": "rgb24", "width": _lossless_size.x, "height": _lossless_size.y})
	var file := FileAccess.open(OUTPUT + "/sources/takes/" + scenario + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_events, "\t"))
	get_tree().quit()
