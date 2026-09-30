extends Node

## Offline social capture using the production combat scene and training resolver.
const OUTPUT := "res://steam/campaigns/2026-09-30-great-sword"
const STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const RECIPES := {
	"great-sword": [WeaponSchool.Id.SWORD, WeaponSchool.Id.SWORD],
}
const SEED := 30092026
const PAPER := preload("res://assets/asset_packs/Cila - Paper UI stylized/Paper style 1/paper 12.png")
const SINGLE_START_GAP := 306.0
const SINGLE_ENEMY_SPACING := 54.0
const ARMY_START_GAP := 306.0
const ARMY_CHILD_SLOTS := [1, 4, 7]
const OUTRO_SEQUENCE := [0, 4, 1, 2, 3, 0, 2, 4, 3, 1]
const FONT := preload("res://assets/fonts/SpicyRice-Regular.ttf")
const SMALL_FONT := preload("res://assets/fonts/Fredoka-VariableFont_wdth,wght.ttf")
const COCOON_OPEN := preload("res://assets/base/pupation/cocoon_open.png")
const COCOON_CLOSED := preload("res://assets/base/pupation/cocoon.png")
const REVEAL_CLOUD := preload("res://assets/vfx/spore_cloud/spore_cloud.tscn")
const REVEAL_SPARKS := preload("res://assets/vfx/hit_burst/hit_burst.tscn")
const SIZE := Vector2i(1080, 1920)
const FPS := 60
const LENGTH := 20 * FPS
const VERSION := 3
const UNIT_SCALE := 1.65
const FLOOR_SCREEN_Y := 1240.0
const COCOON_POSITION := Vector2(680, 1072)
const ENTRY_START_FRAME := 21
const ENTRY_END_FRAME := 51
const REVEAL_FRAME := 150
const LANDING_FRAME := 186
const REVEAL_HOP_HEIGHT := 240.0
const FADE_START_FRAME := 930
const FADE_END_FRAME := 1020
const PROMPT_START_FRAME := 1029
const PROMPT_END_FRAME := 1053


class CaptureTroop extends Troop:
	var capture_spacing := HOME_SLOT_SPACING

	func get_home_slot_spacing() -> float:
		return capture_spacing

var _slug := "great-sword"
var _frame := -30
var _probe := false
var _output: SubViewport
var _stage: Node2D
var _camera: Camera2D
var _intro_forest: Sprite2D
var _overlay: Control
var _recipe: Control
var _question: Label
var _result_icon: TextureRect
var _result_label: Label
var _title: Label
var _combat_fade: ColorRect
var _outro_prompt: Label
var _training: Node2D
var _hero_actor: UnitAppearance
var _hero_shadow: Polygon2D
var _cocoon: Sprite2D
var _cocoon_school: Sprite2D
var _shell_pieces: Array[Sprite2D] = []
var _reveal_flash: ColorRect
var _small_font: FontVariation
var _hero: RosterUnitData
var _raw: FileAccess
var _raw_frames := 0
var _events: Array[Dictionary] = []
var _finished := false
var _processed_frame := -999
var _shot := "recipe"
var _capture_busy := false
var _army_active := false
var _subtitle: Label
var _input_icons: Array[TextureRect] = []
var _input_labels: Array[Label] = []
var _input_schools: Array[int] = []
var _previous_phases: Dictionary = {}
var _previous_damage: Dictionary = {}
var _previous_enemy_damage: Dictionary = {}
var _previous_enemy_hp: Dictionary = {}
var _swing_counts: Dictionary = {}
var _single_swing_targets: Dictionary = {}
var _aoe_swings: Array[Dictionary] = []
var _shot_metrics: Dictionary = {}
var _visibility_failures: Array[Dictionary] = []
var _battle_kind := ""
var _first_action_frame := -1
var _first_effect_frame := -1
var _first_melee_frame := -1


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("weapon="):
			_slug = arg.trim_prefix("weapon=")
		elif arg == "probe":
			_probe = true
		elif arg.begins_with("raw_capture="):
			_raw = FileAccess.open(arg.trim_prefix("raw_capture="), FileAccess.WRITE)
			assert(_raw != null)
	assert(RECIPES.has(_slug))
	_small_font = FontVariation.new()
	_small_font.base_font = SMALL_FONT
	_small_font.variation_opentype = {2003265652: 600}
	seed(SEED)
	GameState.run_seed = SEED
	GameState.combat_fast_forward = 1
	_events.append({
		"frame": 0, "action": "gameplay_source",
		"unit_script_sha256": FileAccess.get_sha256("res://assets/units/unit.gd"),
		"knockback_recovery_seconds": Unit.KNOCKBACK_RECOVERY_TIME
	})
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	for bus in [&"Master", &"SFX", &"Music"]:
		var index := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_mute(index, false)
		AudioServer.set_bus_volume_db(index, 0.0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(540, 960)
	get_window().content_scale_size = SIZE
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_output = SubViewport.new()
	_output.size = SIZE
	_output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_output.world_2d = World2D.new()
	add_child(_output)
	var preview := TextureRect.new()
	preview.texture = _output.get_texture()
	preview.size = Vector2(SIZE)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview)
	_build_background()
	_build_overlay()
	RenderingServer.frame_post_draw.connect(_record)
	process_priority = 100


func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -30
	_output.add_child(layer)
	var ground := ColorRect.new()
	ground.color = Color("000c07")
	ground.size = Vector2(SIZE)
	layer.add_child(ground)
	_intro_forest = Sprite2D.new()
	_intro_forest.texture = load("res://assets/base/background/bg_battlegrounds.png")
	_intro_forest.centered = false
	_intro_forest.position = Vector2(-900, 62)
	_intro_forest.scale = Vector2(0.75, 0.75)
	layer.add_child(_intro_forest)


func _label(text: String, rect: Rect2, points: int, font: Font = FONT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _small_font if font == SMALL_FONT else font)
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", Color("fff3d0"))
	label.add_theme_color_override("font_outline_color", Color("13251b"))
	label.add_theme_constant_override("outline_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _ink_label(text: String, rect: Rect2, points: int, font: Font = FONT) -> Label:
	var label := _label(text, rect, points, font)
	label.add_theme_color_override("font_color", Color("243128"))
	label.add_theme_constant_override("outline_size", 0)
	return label


func _icon(school: int, x: float) -> void:
	var icon := TextureRect.new()
	icon.texture = WeaponSchool.load_weapon(WeaponSchool.base_weapon_path(school)).icon
	icon.position = Vector2(x, 0)
	icon.size = Vector2(180, 180)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_recipe.add_child(icon)
	var school_label := _ink_label(WeaponSchool.display_name(school), Rect2(x - 5, 185, 190, 54), 38, SMALL_FONT)
	_recipe.add_child(school_label)
	_input_icons.append(icon)
	_input_labels.append(school_label)
	_input_schools.append(school)


func _build_overlay() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 40
	_output.add_child(fade_layer)
	_combat_fade = ColorRect.new()
	_combat_fade.size = Vector2(SIZE)
	_combat_fade.color = Color.BLACK
	_combat_fade.modulate.a = 0.0
	_combat_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_combat_fade)
	var layer := CanvasLayer.new()
	layer.layer = 50
	_output.add_child(layer)
	_overlay = Control.new()
	_overlay.size = Vector2(SIZE)
	layer.add_child(_overlay)
	_overlay.add_child(_label("Auto Shrooms", Rect2(70, 215, 940, 130), 104))
	_subtitle = _label("Weapon combos", Rect2(100, 350, 880, 85), 52, SMALL_FONT)
	_overlay.add_child(_subtitle)
	_recipe = Control.new()
	# Five evenly spaced visual centers, symmetric about x=540.
	_recipe.position = Vector2(142, 478)
	_recipe.size = Vector2(796, 245)
	_overlay.add_child(_recipe)
	var backing := TextureRect.new()
	backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backing.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	backing.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recipe.add_child(backing)
	backing.texture = PAPER
	backing.position = Vector2(-52, -26)
	backing.size = Vector2(900, 283)
	var paper_rect := backing.get_global_rect()
	_events.append({
		"frame": 0, "action": "equation_paper_layout",
		"x": paper_rect.position.x, "y": paper_rect.position.y,
		"width": paper_rect.size.x, "height": paper_rect.size.y,
		"source_width": PAPER.get_width(), "source_height": PAPER.get_height(),
		"filter": "linear", "stretch_mode": "keep_aspect_centered"
	})
	assert(paper_rect.size.is_equal_approx(Vector2(900, 283)))
	var schools: Array = RECIPES[_slug]
	_icon(int(schools[0]), 0)
	_icon(int(schools[1]), 308)
	_recipe.add_child(_ink_label("+", Rect2(204, 40, 80, 100), 74, SMALL_FONT))
	_recipe.add_child(_ink_label("=", Rect2(512, 40, 80, 100), 74, SMALL_FONT))
	_question = _ink_label("?", Rect2(616, 0, 180, 180), 146)
	_recipe.add_child(_question)
	_result_icon = TextureRect.new()
	_result_icon.position = Vector2(616, 0)
	_result_icon.size = Vector2(180, 180)
	_result_icon.pivot_offset = _result_icon.size * 0.5
	_result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_result_icon.hide()
	_recipe.add_child(_result_icon)
	_result_label = _ink_label("", Rect2(606, 185, 200, 54), 34, SMALL_FONT)
	_result_label.hide()
	_recipe.add_child(_result_label)
	_title = _label("", Rect2(80, 480, 920, 130), 82)
	_title.hide()
	_overlay.add_child(_title)
	_outro_prompt = _label("Which combo next?", Rect2(95, 1040, 890, 160), 80)
	_outro_prompt.modulate.a = 0.0
	_outro_prompt.hide()
	_overlay.add_child(_outro_prompt)
	_reveal_flash = ColorRect.new()
	_reveal_flash.size = Vector2(SIZE)
	_reveal_flash.color = Color(1.0, 0.91, 0.68, 0.0)
	_reveal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_flash.z_index = -2
	_overlay.add_child(_reveal_flash)
	_training = Node2D.new()
	_overlay.add_child(_training)
	_cocoon = Sprite2D.new()
	_cocoon.texture = COCOON_OPEN
	_cocoon.position = COCOON_POSITION
	_cocoon.scale = Vector2.ONE * (336.0 / COCOON_OPEN.get_height())
	_training.add_child(_cocoon)
	_cocoon_school = Sprite2D.new()
	_cocoon_school.texture = WeaponSchool.load_weapon(WeaponSchool.base_weapon_path(int(schools[1]))).icon
	_cocoon_school.position = Vector2(COCOON_POSITION.x, 855)
	var school_size := _cocoon_school.texture.get_size()
	_cocoon_school.scale = Vector2.ONE * (100.0 / maxf(school_size.x, school_size.y))
	_training.add_child(_cocoon_school)
	_hero = _make_unit(0, [])
	assert(not _hero.is_adult_stage())
	_hero_actor = UnitAppearance.compose_player(false)
	_training.add_child(_hero_actor)
	_hero_actor.scale = Vector2.ONE * UNIT_SCALE
	_hero_actor.position = Vector2(265, FLOOR_SCREEN_Y)
	_hero_actor.mount_weapon_appearance(WeaponSchool.load_weapon(WeaponSchool.base_weapon_path(int(schools[0]))))
	_hero_actor.play_idle(false)
	_events.append({"frame": 0, "action": "cocoon_entry", "life_stage": "child", "held_school": int(schools[0]), "unit_scale": UNIT_SCALE})


func _make_unit(index: int, schools: Array) -> RosterUnitData:
	var previous_run_seed := GameState.run_seed
	GameState.run_seed = SEED + index
	var nursery := NurseryData.new()
	nursery.seed_if_empty()
	nursery.plant_spore(0, nursery.make_fresh_common_spore())
	nursery.apply_fertilizer_to_plot(0, load("res://assets/base/nursery/fertilizers/reinforced_chitin.tres"))
	nursery.advance_day()
	nursery.advance_day()
	var unit: RosterUnitData = nursery.harvest(0)[0]
	GameState.run_seed = previous_run_seed
	unit.lineage_name = "Darwin" if index == 0 else "Curie"
	unit.display_name = unit.lineage_name
	for school in schools:
		assert(unit.apply_pupation_training(int(school)))
	return unit


func _make_inherited_child(index: int) -> RosterUnitData:
	var parent := _make_unit(index, RECIPES[_slug])
	var spore := SporeData.from_fallen_unit(parent)
	var previous_run_seed := GameState.run_seed
	GameState.run_seed = SEED + 1000 + index
	var nursery := NurseryData.new()
	nursery.seed_if_empty()
	assert(nursery.plant_spore(0, spore))
	nursery.advance_day()
	var children := nursery.harvest(0)
	GameState.run_seed = previous_run_seed
	assert(children.size() == 1)
	var child: RosterUnitData = children[0]
	assert(not child.is_adult_stage())
	assert(child.weapon_trainings == parent.weapon_trainings)
	assert(child.weapon.resource_path == parent.weapon.resource_path)
	return child


func _enemies(army: bool) -> Array[RosterUnitData]:
	var result: Array[RosterUnitData] = []
	var path := "res://assets/units/enemies/solar_sword/solar_sword_unit.tres" if army else "res://assets/units/enemies/rose_thorn/rose_thorn_unit.tres"
	var data := load(path) as EnemyUnitData
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + (100 if army else 0)
	for i in (18 if army else 3):
		result.append(RosterUnitData.create_enemy(data.display_name, data.make_stats(rng), data))
	return result


func _start_battle(army: bool) -> void:
	if is_instance_valid(_stage):
		_output.remove_child(_stage)
		_stage.free()
	seed(SEED + (100 if army else 0))
	_stage = STAGE.instantiate()
	_stage.sandboxed = true
	if not army:
		# Capture-only formation spacing; the authored AI and combat remain unchanged.
		var captured_troop := _stage.get_node("World/EnemyTroop") as Troop
		var march_speed := captured_troop.march_speed
		captured_troop.set_script(CaptureTroop)
		captured_troop.is_enemy = true
		captured_troop.march_speed = march_speed
		captured_troop.set("capture_spacing", SINGLE_ENEMY_SPACING)
	_output.add_child(_stage)
	_stage.get_node("HUD").hide()
	_stage.get_node("RunMenu").hide()
	_stage.get_node("BackdropLayer").hide()
	_intro_forest.hide()
	_stage.get_node("World/CombatBarks").hide()
	_camera = _stage.get_node("World/MainCamera")
	_camera.set_process(false)
	_camera.set_physics_process(false)
	_camera.enabled = false
	_camera.position_smoothing_enabled = false
	_camera.drag_horizontal_enabled = false
	_camera.limit_left = -100000
	_camera.limit_right = 100000
	_camera.limit_top = -100000
	_camera.limit_bottom = 100000
	_camera.offset = Vector2.ZERO
	var roster: Array[RosterUnitData] = []
	for i in (9 if army else 1):
		roster.append(_make_inherited_child(i) if army and ARMY_CHILD_SLOTS.has(i) else _make_unit(i, RECIPES[_slug]))
	var enemies := _enemies(army)
	_stage.start_battle(roster, enemies)
	_army_active = army
	_battle_kind = "army" if army else "single"
	_previous_phases.clear()
	_previous_damage.clear()
	_previous_enemy_damage.clear()
	_previous_enemy_hp.clear()
	_swing_counts.clear()
	_single_swing_targets.clear()
	_first_action_frame = -1
	_first_effect_frame = -1
	_first_melee_frame = -1
	var friend: Unit = _stage.player_troop.get_frontmost_living_unit()
	var enemy: Unit = _stage.enemy_troop.get_frontmost_living_unit()
	var gap := ARMY_START_GAP if army else SINGLE_START_GAP
	var offset := Vector2(friend.global_position.x + gap - enemy.global_position.x, 0)
	var troop: Troop = _stage.enemy_troop
	troop.reset_for_scenario(troop.get_formation_anchor_global() + offset)
	for unit in troop.get_units():
		unit.global_position += offset
		_previous_enemy_damage[unit.get_instance_id()] = unit.damage_taken
		_previous_enemy_hp[unit.get_instance_id()] = unit.current_hp
	_stage._right_edge.global_position.x += offset.x
	_stage.get_node("RunMenu").hide()
	_stage.get_node("World/CombatBarks").end_battle()
	_stage.get_node("World/CombatBarks").set_process(false)
	_stage.player_troop.flag_bearer.hide()
	var profile: CombatProfile = friend.combat
	var player_specs: Array[Dictionary] = []
	var child_count := 0
	var player_actors: Array[Unit] = _stage.player_troop.get_units()
	for i in roster.size():
		var data := roster[i]
		var actor := player_actors[i]
		if not data.is_adult_stage():
			child_count += 1
		assert(data.weapon.resource_path == _hero.weapon.resource_path)
		player_specs.append({
			"slot": i, "life_stage": "adult" if data.is_adult_stage() else "child",
			"life_stage_id": data.life_stage_id, "generation": data.generation,
			"weapon": data.weapon.display_name, "trainings": data.weapon_trainings.duplicate(),
			"strength": data.stats.strength, "dex": data.stats.dex, "con": data.stats.con,
			"appearance_scene": actor._appearance.scene_file_path,
			"unit_scale_x": actor.scale.x, "unit_scale_y": actor.scale.y,
			"appearance_scale_x": actor._appearance.scale.x, "appearance_scale_y": actor._appearance.scale.y,
			"source": "trained_adult" if data.is_adult_stage() else "native_lineage_spore_harvest"
		})
	assert(child_count == (3 if army else 0))
	var enemy_stats: Array[Dictionary] = []
	for unit in enemies:
		enemy_stats.append({"strength": unit.stats.strength, "dex": unit.stats.dex, "con": unit.stats.con})
	_events.append({
		"frame": _frame, "action": _battle_kind, "players": roster.size(),
		"player_adults": roster.size() - child_count, "player_children": child_count,
		"player_specs": player_specs,
		"enemies": enemies.size(), "enemy_type": "solar_sword" if army else "rose_thorn", "enemy_stats": enemy_stats,
		"enemy_home_slot_spacing": troop.get_home_slot_spacing(),
		"weapon": roster[0].weapon.display_name, "seed": SEED + (100 if army else 0),
		"nearest_front_gap": enemy.global_position.distance_to(friend.global_position),
		"enemy_spawn_offset": offset.x,
		"profile": {
			"attack_style": profile.attack_style, "engagement_stance": profile.engagement_stance,
			"melee_range": profile.melee_range, "melee_engage_range": friend._get_melee_engage_range(),
			"projectile_range": profile.projectile_range, "skirmish_distance": profile.skirmish_distance,
			"targeting_mode": profile.targeting_mode, "attack_interval": profile.attack_interval,
			"knockback_force": profile.knockback_force
		}
	})
	_cut_camera("army_launch" if army else "single_wide")
	print("CAPTURE ", _slug, " ", _battle_kind, " ", roster.size(), " vs ", enemies.size())


func _observe_battle() -> void:
	var friends: Array[Unit] = _stage.player_troop.get_living_units()
	var foes: Array[Unit] = _stage.enemy_troop.get_living_units()
	var damage_this_frame := 0
	var damaged_enemies: Array[int] = []
	for enemy: Unit in _stage.enemy_troop.get_units():
		var id := enemy.get_instance_id()
		var taken := enemy.damage_taken - int(_previous_enemy_damage.get(id, 0))
		var previous_hp := int(_previous_enemy_hp.get(id, enemy.current_hp))
		if taken > 0:
			damaged_enemies.append(enemy.squad_index)
			_events.append({
				"frame": _frame, "action": "enemy_damage", "battle": _battle_kind,
				"shot": _shot, "enemy": enemy.squad_index, "damage": taken,
				"previous_hp": previous_hp, "hp": enemy.current_hp,
				"visible": _unit_fully_visible(enemy)
			})
		_previous_enemy_damage[id] = enemy.damage_taken
		_previous_enemy_hp[id] = enemy.current_hp
	var clearance := INF
	for enemy in foes:
		for friend in friends:
			clearance = minf(clearance, enemy.global_position.distance_to(friend.global_position) - enemy._get_melee_range())
	if _first_melee_frame < 0 and clearance <= 0.0:
		_first_melee_frame = _frame
		_events.append({"frame": _frame, "action": "first_melee_range", "battle": _battle_kind, "melee_clearance": clearance})
	for unit: Unit in _stage.player_troop.get_units():
		var id := unit.get_instance_id()
		var phase: int = unit._combat_phase
		var visible := _unit_fully_visible(unit)
		if phase == Unit.CombatPhase.ATTACKING and int(_previous_phases.get(id, -1)) != phase:
			_swing_counts[id] = int(_swing_counts.get(id, 0)) + 1
			if _first_action_frame < 0:
				_first_action_frame = _frame
			_events.append({
				"frame": _frame, "action": "player_swing", "battle": _battle_kind,
				"shot": _shot, "unit": unit.squad_index, "visible": visible,
				"swing": _swing_counts[id],
				"x": unit.global_position.x, "y": unit.global_position.y
			})
		var dealt := unit.damage_dealt - int(_previous_damage.get(id, 0))
		if dealt > 0:
			if _first_effect_frame < 0:
				_first_effect_frame = _frame
			damage_this_frame += dealt
			_events.append({
				"frame": _frame, "action": "player_hit", "battle": _battle_kind,
				"shot": _shot, "unit": unit.squad_index, "visible": visible,
				"damage": dealt, "melee_clearance": clearance,
				"swing": int(_swing_counts.get(id, 0)),
				"enemies_damaged_this_frame": damaged_enemies.duplicate()
			})
			if not _army_active:
				var swing := int(_swing_counts.get(id, 0))
				var targets: Array = _single_swing_targets.get(swing, [])
				for enemy_index in damaged_enemies:
					if not targets.has(enemy_index):
						targets.append(enemy_index)
				_single_swing_targets[swing] = targets
				if targets.size() >= 2:
					var evidence := {
						"frame": _frame, "action": "single_aoe_swing", "swing": swing,
						"unit": unit.squad_index, "distinct_enemies": targets.duplicate(),
						"enemy_count": targets.size(), "damage_this_frame": dealt
					}
					_aoe_swings.append(evidence)
					_events.append(evidence)
		_previous_phases[id] = phase
		_previous_damage[id] = unit.damage_dealt
	var metric: Dictionary = _shot_metrics.get(_shot, {
		"frames": 0, "damage": 0, "min_players_alive": friends.size(),
		"min_enemies_alive": foes.size(), "frames_all_players_visible": 0,
		"frames_all_enemies_visible": 0, "first_action_frame": -1, "first_effect_frame": -1
	})
	metric.frames += 1
	metric.damage += damage_this_frame
	metric.min_players_alive = mini(metric.min_players_alive, friends.size())
	metric.min_enemies_alive = mini(metric.min_enemies_alive, foes.size())
	metric.first_action_frame = _first_action_frame
	metric.first_effect_frame = _first_effect_frame
	var visible_players := _fully_visible(friends)
	var visible_enemies := _fully_visible(foes)
	if visible_players == friends.size():
		metric.frames_all_players_visible += 1
	if visible_enemies == foes.size():
		metric.frames_all_enemies_visible += 1
	var player_required := _shot in ["single_wide", "army_launch", "army_wide"]
	var enemy_required := _shot in ["single_wide", "army_wide"]
	if (player_required and visible_players != friends.size()) or (enemy_required and visible_enemies != foes.size()):
		if not _visibility_failures.is_empty() and _visibility_failures[-1].shot == _shot and _visibility_failures[-1].last_frame == _frame - 1:
			_visibility_failures[-1].last_frame = _frame
			_visibility_failures[-1].frames += 1
		else:
			_visibility_failures.append({
				"shot": _shot, "first_frame": _frame, "last_frame": _frame, "frames": 1,
				"players_visible": visible_players, "players_alive": friends.size(),
				"enemies_visible": visible_enemies, "enemies_alive": foes.size()
			})
	_shot_metrics[_shot] = metric


func _cut_camera(shot: String) -> void:
	if not is_instance_valid(_stage):
		return
	var friends: Array[Unit] = _stage.player_troop.get_living_units()
	var foes: Array[Unit] = _stage.enemy_troop.get_living_units()
	if friends.is_empty():
		return
	var front := -INF
	var movement_speed := 0.0
	for unit in friends:
		front = maxf(front, unit.global_position.x)
		movement_speed = maxf(movement_speed, unit.get_move_speed())
	var enemy_front := INF
	for unit in foes:
		enemy_front = minf(enemy_front, unit.global_position.x)
	if not is_finite(enemy_front):
		enemy_front = front + 180.0
	var target_x := front + 130.0
	var zoom := UNIT_SCALE
	match shot:
		"single_wide", "army_wide":
			var bounds := _army_bounds(friends).merge(_army_bounds(foes))
			if shot == "army_wide":
				bounds = bounds.grow(170.0)
			else:
				bounds.position.x -= 110.0
				bounds.size.x += 370.0
				bounds = bounds.grow(40.0)
			zoom = minf(UNIT_SCALE, (SIZE.x - 160.0) / bounds.size.x)
			target_x = bounds.get_center().x
		"army_launch":
			var bounds := _army_bounds(friends)
			# Leave room for the actual approach through the player-side shot.
			bounds.size.x += movement_speed * float(678 - _frame) / FPS
			zoom = minf(UNIT_SCALE, (SIZE.x - 160.0) / bounds.size.x)
			target_x = bounds.get_center().x
		"army_impact":
			target_x = enemy_front + 30.0
			zoom = 1.3
	_shot = shot
	_camera.zoom = Vector2.ONE * zoom
	_camera.position = Vector2(target_x, 786.0 - (FLOOR_SCREEN_Y - SIZE.y * 0.5) / zoom)
	# Explicit viewport framing avoids inherited Camera2D drag/limit state.
	var framing := Transform2D.IDENTITY.scaled(Vector2.ONE * zoom)
	framing.origin = Vector2(SIZE) * 0.5 - _camera.position * zoom
	_output.canvas_transform = framing
	var background: Sprite2D = _stage.get_node("World/Background/Segment0/Background")
	var background_scale := background.get_global_transform_with_canvas().get_scale().x
	_events.append({"frame": _frame, "action": "cut", "shot": shot, "camera_x": target_x, "zoom": zoom, "background_screen_scale": background_scale, "screen_fixed_forest_visible": _intro_forest.visible})


func _army_bounds(units: Array[Unit]) -> Rect2:
	var bounds := Rect2()
	for index in units.size():
		var appearance: UnitAppearance = units[index]._appearance
		var unit_rect := appearance.global_transform * appearance.visual_rect_local(true)
		bounds = unit_rect if index == 0 else bounds.merge(unit_rect)
	return bounds


func _fully_visible(units: Array[Unit]) -> int:
	var count := 0
	for unit in units:
		if _unit_fully_visible(unit):
			count += 1
	return count


func _unit_fully_visible(unit: Unit) -> bool:
	var bounds: Rect2 = unit._appearance.get_global_transform_with_canvas() * unit._appearance.visual_rect_local(true)
	return Rect2(Vector2.ZERO, Vector2(SIZE)).encloses(bounds)


func _animate_outro() -> void:
	var age := _frame - 14 * FPS
	for slot in 2:
		var step := floori(float(age + slot * 5) / 9.0)
		var school: int = OUTRO_SEQUENCE[(step + slot * 3) % OUTRO_SEQUENCE.size()]
		if _input_schools[slot] == school:
			continue
		_input_schools[slot] = school
		_input_icons[slot].texture = WeaponSchool.load_weapon(WeaponSchool.base_weapon_path(school)).icon
		_input_labels[slot].text = WeaponSchool.display_name(school)
		var output_path := WeaponSchool.combo_weapon_path(_input_schools[0], _input_schools[1])
		assert(not output_path.is_empty() and output_path != WeaponSchool.base_weapon_path(-1))
		_events.append({
			"frame": _frame, "action": "outro_input", "slot": slot, "school": school,
			"pair": _input_schools.duplicate(), "valid_result": output_path,
			"result_visible": false
		})
	if _frame >= FADE_START_FRAME:
		_combat_fade.modulate.a = smoothstep(FADE_START_FRAME, FADE_END_FRAME, _frame)
	if _frame == FADE_START_FRAME:
		_events.append({"frame": _frame, "action": "combat_fade_started", "end_frame": FADE_END_FRAME})
	if _frame == FADE_END_FRAME:
		_stage.hide()
		_stage.process_mode = Node.PROCESS_MODE_DISABLED
		_events.append({"frame": _frame, "action": "combat_black", "fade_alpha": _combat_fade.modulate.a, "combat_processing": false})
	if _frame >= PROMPT_START_FRAME:
		var progress := smoothstep(PROMPT_START_FRAME, PROMPT_END_FRAME, _frame)
		_outro_prompt.show()
		_outro_prompt.modulate.a = progress
		_outro_prompt.position.y = 1040.0 + (1.0 - progress) * 24.0
	if _frame == PROMPT_START_FRAME:
		_events.append({"frame": _frame, "action": "closing_question_started", "text": _outro_prompt.text, "combat_fade_alpha": _combat_fade.modulate.a, "y_start": 1064, "y_end": 1040, "animation_end_frame": PROMPT_END_FRAME})
	if _frame == PROMPT_END_FRAME:
		_events.append({"frame": _frame, "action": "closing_question_settled", "text": _outro_prompt.text, "alpha": _outro_prompt.modulate.a, "y": _outro_prompt.position.y})


func _animate_training() -> void:
	var seconds := maxf(float(_frame) / FPS, 0.0)
	if _frame == ENTRY_START_FRAME:
		_hero_actor.play_walk(false, 2.1)
		_events.append({"frame": _frame, "action": "walk_started", "animation_speed": 2.1})
	if _frame >= ENTRY_START_FRAME and _frame < ENTRY_END_FRAME:
		var progress := float(_frame - ENTRY_START_FRAME) / (ENTRY_END_FRAME - ENTRY_START_FRAME)
		_hero_actor.position.x = lerpf(265.0, COCOON_POSITION.x, progress)
		_hero_actor.modulate.a = 1.0 - smoothstep(0.85, 1.0, progress)
	if _frame == ENTRY_END_FRAME:
		_hero_actor.hide()
		_cocoon.texture = COCOON_CLOSED
		Audio.play_ui_cue(Sfx.Cue.UI_CLOSE)
		_events.append({"frame": _frame, "action": "cocoon_closed"})
	if _frame >= ENTRY_END_FRAME and _frame < REVEAL_FRAME:
		var tension := float(_frame - ENTRY_END_FRAME) / (REVEAL_FRAME - ENTRY_END_FRAME)
		var charge := smoothstep(2.15, 2.5, seconds)
		var shell_scale := Vector2(1.0 + charge * 0.2, 1.0 - charge * 0.2)
		_cocoon.scale = shell_scale * (336.0 / COCOON_CLOSED.get_height())
		_cocoon.position = COCOON_POSITION + Vector2(
			sin(seconds * 72.0) * tension * (8.0 + charge * 7.0),
			168.0 * (1.0 - shell_scale.y)
		)
		_cocoon.rotation = sin(seconds * 53.0) * tension * 0.075
		_cocoon.modulate = Color.WHITE.lerp(Color(1.8, 1.55, 0.9), tension)
		_intro_forest.modulate = Color.WHITE.lerp(Color(0.55, 0.62, 0.57), charge)
	if _frame in [102, 123, 138]:
		Audio.play_ui_cue(Sfx.Cue.UI_TICK)
	if _frame == REVEAL_FRAME:
		_reveal()
	if _frame >= REVEAL_FRAME:
		_animate_emergence()
	assert(_hero_actor.scale.is_equal_approx(Vector2.ONE * UNIT_SCALE))


func _animate_emergence() -> void:
	var age := float(_frame - REVEAL_FRAME) / FPS
	# Fast lift, a short apex hold, then a weighted landing without resizing the unit.
	if age < 0.2:
		var lift := 1.0 - pow(1.0 - age / 0.2, 3.0)
		_hero_actor.position = Vector2(
			lerpf(COCOON_POSITION.x, 485.0, lift), FLOOR_SCREEN_Y - lift * REVEAL_HOP_HEIGHT
		)
		_hero_actor.rotation = lerpf(-0.16, 0.07, lift)
	elif age < 0.3:
		_hero_actor.position = Vector2(485, FLOOR_SCREEN_Y - REVEAL_HOP_HEIGHT)
		_hero_actor.rotation = 0.07
	elif _frame < LANDING_FRAME:
		var fall := clampf((age - 0.3) / 0.3, 0.0, 1.0)
		_hero_actor.position = Vector2(
			lerpf(485.0, 450.0, fall), FLOOR_SCREEN_Y - REVEAL_HOP_HEIGHT * (1.0 - fall * fall)
		)
		_hero_actor.rotation = lerpf(0.07, 0.0, fall)
	else:
		var settle := clampf((age - 0.6) / 0.18, 0.0, 1.0)
		_hero_actor.position = Vector2(450, FLOOR_SCREEN_Y - sin(settle * PI) * 18.0)
		_hero_actor.rotation = sin(settle * TAU) * 0.025 * (1.0 - settle)
	_hero_shadow.position = Vector2(_hero_actor.position.x, FLOOR_SCREEN_Y + 4.0)
	_hero_shadow.modulate.a = lerpf(1.0, 0.5, (FLOOR_SCREEN_Y - _hero_actor.position.y) / REVEAL_HOP_HEIGHT)
	if _frame == LANDING_FRAME:
		var dust: SporeCloud = REVEAL_CLOUD.instantiate()
		_training.add_child(dust)
		dust.z_index = 1
		dust.position = Vector2(450, FLOOR_SCREEN_Y - 8.0)
		dust.burst(Color("d7c985"), 1.1)
		var particles: CPUParticles2D = dust.get_node("Particles")
		particles.lifetime = 0.4
		particles.amount = 22
		particles.gravity = Vector2(0, 90)
		Audio.play_ui_cue(Sfx.Cue.GROUND)
		_events.append({"frame": _frame, "action": "reveal_landing", "sound": "ground"})
	for index in _shell_pieces.size():
		var piece := _shell_pieces[index]
		var side := -1.0 if index == 0 else 1.0
		var split := clampf(age / 0.55, 0.0, 1.0)
		piece.position = COCOON_POSITION + Vector2(
			side * (84.0 + 170.0 * (1.0 - pow(1.0 - split, 2.0))),
			-80.0 * sin(split * PI) + 110.0 * split * split
		)
		piece.rotation = side * split * 0.85
		piece.modulate.a = 1.0 - smoothstep(0.18, 0.55, age)
	_reveal_flash.color.a = 0.14 * (1.0 - smoothstep(0.0, 0.12, age))
	_intro_forest.modulate = Color(0.65, 0.7, 0.63).lerp(Color.WHITE, smoothstep(0.0, 0.45, age))
	_cocoon_school.modulate.a = 1.0 - smoothstep(0.0, 0.18, age)
	_result_icon.scale = Vector2.ONE * (1.0 + 0.3 * (1.0 - smoothstep(0.0, 0.25, age)))
	_hero_actor.modulate = Color(1.35, 1.22, 1.0).lerp(Color.WHITE, smoothstep(0.0, 0.16, age))


func _reveal() -> void:
	for school in RECIPES[_slug]:
		assert(_hero.apply_pupation_training(int(school)))
	_training.remove_child(_hero_actor)
	_hero_actor.free()
	_hero_actor = UnitAppearance.compose_player(true)
	_training.add_child(_hero_actor)
	_hero_actor.scale = Vector2.ONE * UNIT_SCALE
	_hero_actor.z_index = 5
	_hero_shadow = _hero_actor.get_node("GroundShadow")
	_hero_shadow.reparent(_training, true)
	_hero_shadow.z_index = 0
	_hero_actor.mount_weapon_appearance(_hero.weapon)
	_hero_actor.play_idle(false)
	_hero_actor.modulate = Color.WHITE
	_hero_actor.show()
	_cocoon.hide()
	for index in 2:
		var piece := Sprite2D.new()
		piece.texture = COCOON_CLOSED
		piece.region_enabled = true
		piece.region_filter_clip_enabled = true
		piece.region_rect = Rect2(index * 256, 0, 256, 512)
		piece.scale = Vector2.ONE * (336.0 / COCOON_CLOSED.get_height())
		_training.add_child(piece)
		_shell_pieces.append(piece)
	_question.hide()
	_result_icon.texture = _hero.weapon.icon
	_result_icon.show()
	_result_label.text = _hero.weapon.display_name
	_result_label.show()
	_title.text = _hero.weapon.display_name
	var cloud: SporeCloud = REVEAL_CLOUD.instantiate()
	_training.add_child(cloud)
	cloud.z_index = 1
	cloud.position = COCOON_POSITION
	cloud.burst_aoe(110.0, Color("ffe992"))
	var glow: CPUParticles2D = cloud.get_node("Particles")
	glow.lifetime = 0.55
	glow.initial_velocity_min = 170.0
	glow.initial_velocity_max = 280.0
	glow.scale_amount_min = 0.55
	glow.scale_amount_max = 1.1
	var sparks: HitBurst = REVEAL_SPARKS.instantiate()
	_training.add_child(sparks)
	sparks.z_index = 4
	sparks.position = COCOON_POSITION
	sparks.burst(Color("fff1ac"), 2.5)
	var glitter: CPUParticles2D = sparks.get_node("Particles")
	glitter.amount = 36
	glitter.lifetime = 0.45
	glitter.initial_velocity_min = 230.0
	glitter.initial_velocity_max = 450.0
	Audio.play_ui_cue(Sfx.Cue.TRAIN)
	_events.append({"frame": _frame, "action": "cocoon_reveal", "weapon": _hero.weapon.display_name, "unit_scale": UNIT_SCALE, "complete_equation": true, "result_label": _result_label.text, "sound": "train", "shell_pieces": _shell_pieces.size(), "hop_height": REVEAL_HOP_HEIGHT, "apex_hold_seconds": 0.1})


func _process(_delta: float) -> void:
	if _finished or _processed_frame == _frame:
		return
	_processed_frame = _frame
	if _frame >= LENGTH:
		_finished = true
		_finish.call_deferred()
		return
	if _frame < 4 * FPS:
		_animate_training()
	if _frame == 4 * FPS:
		_training.hide()
		_recipe.hide()
		_title.show()
		_events.append({"frame": _frame, "action": "weapon_name"})
		_start_battle(false)
	if _frame == 9 * FPS:
		_start_battle(true)
	if _frame == 678:
		_cut_camera("army_impact")
	if _frame == 810:
		_cut_camera("army_wide")
	if _frame == 14 * FPS:
		_title.hide()
		_result_icon.hide()
		_result_label.hide()
		_question.show()
		_recipe.show()
		_events.append({"frame": _frame, "action": "outro_started", "subtitle": _subtitle.text, "question_visible": false, "result_visible": false, "steam_cta_visible": false})
	if _frame >= 14 * FPS and _frame < LENGTH:
		_animate_outro()
	if is_instance_valid(_stage) and _frame < FADE_END_FRAME:
		_observe_battle()
		for effect in _stage.get_node("World").get_children():
			if effect is CombatCallout:
				effect.hide()
	if _frame >= 0 and (_frame % FPS == 0 or _frame == LENGTH - 1) and is_instance_valid(_stage):
		var living: Array[Unit] = _stage.player_troop.get_living_units()
		var foes: Array[Unit] = _stage.enemy_troop.get_living_units()
		var damage := 0
		for unit: Unit in _stage.player_troop.get_units():
			damage += unit.damage_dealt
		_events.append({"frame": _frame, "alive": living.size(), "enemies_alive": foes.size(), "fully_visible_players": _fully_visible(living), "fully_visible_enemies": _fully_visible(foes), "damage_dealt": damage, "zoom": _camera.zoom.x, "camera_x": _camera.position.x, "shot": _shot, "combat_fade_alpha": _combat_fade.modulate.a, "combat_visible": _stage.visible, "closing_question_visible": _outro_prompt.visible, "closing_question_alpha": _outro_prompt.modulate.a, "steam_cta_visible": false})


func _record() -> void:
	if _finished:
		return
	assert(not _capture_busy, "GPU readback must not re-enter")
	_capture_busy = true
	if _frame >= 0:
		var snapshot := _probe and _frame in [0, 12, 21, 40, 51, 130, 149, 150, 156, 165, 174, 186, 205, 220, 240, 270, 300, 340, 400, 470, 475, 480, 481, 486, 500, 540, 570, 600, 620, 650, 678, 690, 720, 740, 780, 810, 830, 840, 870, 900, 930, 950, 959, 975, 1000, 1019, 1020, 1029, 1041, 1053, 1080, 1140, 1199]
		if _raw != null or snapshot:
			var frame := _output.get_texture().get_image()
			frame.convert(Image.FORMAT_RGB8)
			assert(frame.get_size() == SIZE)
			if _raw != null:
				_raw.store_buffer(frame.get_data())
				_raw_frames += 1
			if snapshot:
				frame.save_png(OUTPUT + "/preview/%s-v%d-%04d.png" % [_slug, VERSION, _frame])
	_frame += 1
	_capture_busy = false


func _finish() -> void:
	RenderingServer.frame_post_draw.disconnect(_record)
	if _raw != null:
		_raw.close()
	var file := FileAccess.open(OUTPUT + "/sources/%s-v%d.json" % [_slug, VERSION], FileAccess.WRITE)
	file.store_string(JSON.stringify({"weapon": _slug, "version": VERSION, "fps": FPS, "frames": _raw_frames, "width": SIZE.x, "height": SIZE.y, "unit_scale": UNIT_SCALE, "equation_center_x": _recipe.position.x + _recipe.size.x * 0.5, "equation_paper_source": PAPER.resource_path, "equation_paper_source_size": {"width": PAPER.get_width(), "height": PAPER.get_height()}, "equation_paper_filter": "linear", "result_label": _hero.weapon.display_name, "steam_cta": false, "outro": {"cycle_start_frame": 840, "cycle_end_frame": LENGTH - 1, "fade_start_frame": FADE_START_FRAME, "black_frame": FADE_END_FRAME, "question_start_frame": PROMPT_START_FRAME, "question_settled_frame": PROMPT_END_FRAME, "subtitle": _subtitle.text}, "audio_preroll_frames": 30, "seed": SEED, "recipe": RECIPES[_slug], "featured_mechanic": "slow AOE slashing melee with knockback", "aoe_swings": _aoe_swings, "shot_metrics": _shot_metrics, "visibility_failures": _visibility_failures, "events": _events}, "\t"))
	print("CAPTURE complete ", _slug, " frames=", _raw_frames)
	get_tree().quit()
