extends Node

## Offline capture director. Production scenes, attainable setups, no preference writes.
const OUTPUT := "res://steam/store assets/2026-09-20-media"
const BASE := "res://assets/base/base.tscn"
var scenario := "probe"
var _pointer: Sprite2D
var _pointer_pos := Vector2(1760, 940)
var _pressed := false
var _frame := 0
var _events: Array[Dictionary] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("scenario="):
			scenario = arg.trim_prefix("scenario=")
	_run.call_deferred()


func _process(_delta: float) -> void:
	_frame += 1


func _frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func _mark(label: String) -> void:
	_events.append({"frame": _frame, "seconds": float(_frame) / 60.0, "action": label})
	print("EVENT ", _frame, " ", label)


func _shot(name: String) -> void:
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


func _make_unit(index: int, schools: Array, mutation: String = "") -> RosterUnitData:
	var nursery := NurseryData.new()
	nursery.seed_if_empty()
	nursery.plant_spore(0, nursery.make_fresh_common_spore())
	var fert_names := ["reinforced_chitin", "finesse", "brute_force"]
	nursery.apply_fertilizer_to_plot(0, load("res://assets/base/nursery/fertilizers/" + fert_names[index % 3] + ".tres"))
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
	return unit


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
	var schools := [[3, 3], [2, 3], [3, 0], [3], [2, 2], [2], [4], [0], [1, 1], [0, 1]]
	var units: Array[RosterUnitData] = []
	for i in schools.size():
		var mutation := ""
		if i == 2:
			mutation = "cap/inky"
		elif i == 6:
			mutation = "cap/boom"
		elif i == 8:
			mutation = "body/thorny"
		units.append(_make_unit(i, schools[i], mutation))
	GameState.troop.seed_if_empty(units)
	GameState.troop.bench[0] = _make_unit(10, [2])
	GameState.troop.bench[1] = _make_unit(11, [])
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
	_choose_enemies(8, 200)


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
	GameState.current_day = 7
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
	await _shot("02-war-chamber")
	var colony: TroopSelectionScreen = base.get_node("%ColonyScreen")
	var source: DropSlot = colony._bench_slots[0]
	var unit: RosterUnitData = GameState.troop.bench[0]
	var destination: Control
	for cocoon: CocoonSlot in colony._cocoon_slots:
		if cocoon.school == WeaponSchool.Id.BOW:
			destination = cocoon
	await _drag(source.get_node("%CardHost").get_child(0), destination)
	assert(colony._pupation_dialog != null, "Actual drag must open Training preview")
	_mark("training_preview")
	await _motion(Vector2(1810, 920), 24)
	await _frames(80)
	await _shot("06-training-combo")
	var dialog := colony._pupation_dialog
	await _click(dialog.get_node("%ConfirmButton"))
	assert(GameState.pupation.get_occupant(WeaponSchool.Id.BOW) == unit, "Training confirmation must succeed")
	_mark("training_started")
	await _motion(Vector2(1770, 940), 24)
	await _frames(70)
	_mark("one_day_later")
	GameState.current_day += 1
	GameState.emerge_pupations()
	colony.on_screen_shown()
	base._refresh_hud()
	await _frames(40)
	assert(unit.weapon_trainings.size() == 2, "Second Training must grant combo weapon")
	# Hover the emerged unit's actual card for its game-authored detail tooltip.
	var slot_index := GameState.troop.bench.find(unit)
	if slot_index >= 0:
		await _motion(_center(colony._bench_slots[slot_index]), 30)
	await _frames(155)
	await _shot("training-result")
	await _motion(Vector2(1770, 940), 24)
	await _frames(40)


func _formation_take() -> void:
	var base := await _scene(BASE)
	await _frames(75)
	var colony: TroopSelectionScreen = base.get_node("%ColonyScreen")
	var first: RosterUnitData = GameState.troop.squad[1]
	await _drag(colony._squad_slots[1].get_node("%CardHost").get_child(0), colony._squad_slots[4])
	assert(GameState.troop.squad[4] == first, "Formation swap must succeed")
	_mark("squad_swap")
	await _motion(Vector2(1730, 940), 20)
	await _frames(65)
	var reserve: RosterUnitData = GameState.troop.bench[0]
	await _drag(colony._bench_slots[0].get_node("%CardHost").get_child(0), colony._squad_slots[2])
	assert(GameState.troop.squad[2] == reserve, "Bench exchange must succeed")
	_mark("bench_exchange")
	await _motion(Vector2(1730, 940), 24)
	await _frames(110)
	await _shot("formation-result")
	await _frames(40)


func _battle_take() -> void:
	var day := 9
	var seed_start := 900
	if scenario == "battle_b":
		seed_start = 1700
	elif scenario == "battle_elite":
		day = 10
		seed_start = 500
	_choose_enemies(day, seed_start)
	var enemy: Array[RosterUnitData] = []
	for spec in GameState.upcoming_enemy_formation:
		enemy.append(RosterUnitData.create_enemy(spec.unit_data.display_name, spec.unit_data.make_stats(), spec.unit_data))
	BattleLaunch.set_enemy_roster(enemy)
	await _scene("res://assets/combat/combat_stage/combat_stage.tscn")
	await _frames(30)
	await _shot(scenario + "-approach")
	for second in range(1, 25):
		await _frames(60)
		if second in [2, 4, 6, 8, 10, 14, 18, 22, 24]:
			await _shot(scenario + "-%02d" % second)
		if get_tree().current_scene.scene_file_path.contains("day_summary"):
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
		"training": await _training_take()
		"formation": await _formation_take()
		"battle_a", "battle_b", "battle_elite": await _battle_take()
		_:
			await _scene(BASE)
			await _frames(90)
			await _shot("probe")
			Audio.play_ui_cue(Sfx.Cue.HARVEST)
			await _frames(90)
	var file := FileAccess.open(OUTPUT + "/sources/takes/" + scenario + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_events, "\t"))
	get_tree().quit()
