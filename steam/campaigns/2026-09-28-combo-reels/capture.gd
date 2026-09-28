extends Node

## Offline social capture using the production combat scene and training resolver.
const OUTPUT := "res://steam/campaigns/2026-09-28-combo-reels"
const STAGE := preload("res://assets/combat/combat_stage/combat_stage.tscn")
const RECIPES := {
	"spore-mortar": [WeaponSchool.Id.SPEAR, WeaponSchool.Id.BOW],
	"umbrella-shield": [WeaponSchool.Id.SHIELD, WeaponSchool.Id.BOW],
	"great-horn": [WeaponSchool.Id.MACE, WeaponSchool.Id.BOW],
	"great-hammer": [WeaponSchool.Id.MACE, WeaponSchool.Id.MACE],
	"polehammer": [WeaponSchool.Id.MACE, WeaponSchool.Id.SPEAR],
}
const FONT := preload("res://assets/fonts/SpicyRice-Regular.ttf")
const SMALL_FONT := preload("res://assets/fonts/Fredoka-VariableFont_wdth,wght.ttf")
const COCOON_OPEN := preload("res://assets/base/pupation/cocoon_open.png")
const COCOON_CLOSED := preload("res://assets/base/pupation/cocoon.png")
const REVEAL_CLOUD := preload("res://assets/vfx/spore_cloud/spore_cloud.tscn")
const REVEAL_SPARKS := preload("res://assets/vfx/hit_burst/hit_burst.tscn")
const SIZE := Vector2i(1080, 1920)
const FPS := 60
const LENGTH := 16 * FPS
const VERSION := 7
const UNIT_SCALE := 1.65
const ARMY_ENEMY_SPAWN_OFFSET := 480.0
const FLOOR_SCREEN_Y := 1240.0
const COCOON_POSITION := Vector2(680, 1072)
const ENTRY_START_FRAME := 21
const ENTRY_END_FRAME := 51
const REVEAL_FRAME := 150
const LANDING_FRAME := 186
const REVEAL_HOP_HEIGHT := 240.0

var _slug := "spore-mortar"
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
var _title: Label
var _cta: Control
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
var _first_army_hit_frame := -1
var _first_army_melee_frame := -1


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
	seed(28092026)
	GameState.combat_fast_forward = 1
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


func _icon(school: int, x: float) -> void:
	var icon := TextureRect.new()
	icon.texture = WeaponSchool.load_weapon(WeaponSchool.base_weapon_path(school)).icon
	icon.position = Vector2(x, 0)
	icon.size = Vector2(180, 180)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_recipe.add_child(icon)
	_recipe.add_child(_label(WeaponSchool.display_name(school), Rect2(x - 5, 185, 190, 54), 38, SMALL_FONT))


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	_output.add_child(layer)
	_overlay = Control.new()
	_overlay.size = Vector2(SIZE)
	layer.add_child(_overlay)
	_overlay.add_child(_label("Auto Shrooms", Rect2(70, 175, 940, 130), 104))
	_overlay.add_child(_label("Weapon combos", Rect2(100, 310, 880, 85), 52, SMALL_FONT))
	_recipe = Control.new()
	# Five evenly spaced visual centers, symmetric about x=540.
	_recipe.position = Vector2(142, 455)
	_recipe.size = Vector2(796, 245)
	_overlay.add_child(_recipe)
	var schools: Array = RECIPES[_slug]
	_icon(int(schools[0]), 0)
	_icon(int(schools[1]), 308)
	_recipe.add_child(_label("+", Rect2(204, 40, 80, 100), 74, SMALL_FONT))
	_recipe.add_child(_label("=", Rect2(512, 40, 80, 100), 74, SMALL_FONT))
	_question = _label("?", Rect2(616, 0, 180, 180), 146)
	_question.add_theme_color_override("font_color", Color("f6cd5a"))
	_recipe.add_child(_question)
	_result_icon = TextureRect.new()
	_result_icon.position = Vector2(616, 0)
	_result_icon.size = Vector2(180, 180)
	_result_icon.pivot_offset = _result_icon.size * 0.5
	_result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_result_icon.hide()
	_recipe.add_child(_result_icon)
	_title = _label("", Rect2(80, 480, 920, 130), 82)
	_title.hide()
	_overlay.add_child(_title)
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
	_cta = Control.new()
	_cta.position = Vector2(100, 1510)
	_cta.size = Vector2(880, 160)
	_cta.add_child(_label("Wishlist on Steam", Rect2(0, 0, 880, 120), 80, SMALL_FONT))
	_cta.hide()
	_overlay.add_child(_cta)


func _make_unit(index: int, schools: Array) -> RosterUnitData:
	var nursery := NurseryData.new()
	nursery.seed_if_empty()
	nursery.plant_spore(0, nursery.make_fresh_common_spore())
	nursery.apply_fertilizer_to_plot(0, load("res://assets/base/nursery/fertilizers/reinforced_chitin.tres"))
	nursery.advance_day()
	nursery.advance_day()
	var unit: RosterUnitData = nursery.harvest(0)[0]
	unit.lineage_name = "Darwin" if index == 0 else "Curie"
	unit.display_name = unit.lineage_name
	for school in schools:
		assert(unit.apply_pupation_training(int(school)))
	return unit


func _enemies(army: bool) -> Array[RosterUnitData]:
	var result: Array[RosterUnitData] = []
	var kind := "solar_sword"
	if _slug == "umbrella-shield":
		kind = "rose_thorn"
	elif _slug == "spore-mortar" and not army:
		kind = "peashooter"
	var count := 18 if army else 3
	if _slug == "umbrella-shield":
		count = 12 if army else 2
	var data := load("res://assets/units/enemies/%s/%s_unit.tres" % [kind, kind]) as EnemyUnitData
	for i in count:
		result.append(RosterUnitData.create_enemy(data.display_name, data.make_stats(), data))
	return result


func _start_battle(army: bool) -> void:
	if is_instance_valid(_stage):
		_output.remove_child(_stage)
		_stage.free()
	seed(28092026 + (100 if army else 0))
	_stage = STAGE.instantiate()
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
		roster.append(_make_unit(i, RECIPES[_slug]))
	var enemies := _enemies(army)
	_stage.start_battle(roster, enemies)
	_army_active = army
	if army:
		# Move the formation anchor with its units before the first combat tick.
		var offset := Vector2(ARMY_ENEMY_SPAWN_OFFSET, 0.0)
		var troop: Troop = _stage.enemy_troop
		troop.reset_for_scenario(troop.get_formation_anchor_global() + offset)
		for unit in troop.get_units():
			unit.global_position += offset
		_stage._right_edge.global_position.x += offset.x
		_events.append({"frame": _frame, "action": "enemy_spawn_offset", "world_pixels": offset.x})
	_stage.get_node("RunMenu").hide()
	_stage.get_node("World/CombatBarks").end_battle()
	_stage.get_node("World/CombatBarks").set_process(false)
	_stage.player_troop.flag_bearer.hide()
	_events.append({"frame": _frame, "action": "army" if army else "close", "players": roster.size(), "enemies": enemies.size(), "weapon": roster[0].weapon.display_name})
	_cut_camera("army_launch" if army else "single_wide")
	print("CAPTURE ", _slug, " ", "army" if army else "close", " ", roster.size(), " vs ", enemies.size())


func _observe_army_engagement() -> void:
	if not _army_active:
		return
	var clearance := INF
	for enemy: Unit in _stage.enemy_troop.get_living_units():
		for friend: Unit in _stage.player_troop.get_living_units():
			var distance := absf(enemy.global_position.x - friend.global_position.x)
			clearance = minf(clearance, distance - enemy._get_melee_range())
	if _first_army_melee_frame < 0 and clearance <= 0.0:
		_first_army_melee_frame = _frame
		_events.append({"frame": _frame, "action": "first_melee_range", "melee_clearance": clearance})
	if _first_army_hit_frame < 0:
		var damage := 0
		for unit: Unit in _stage.player_troop.get_units():
			damage += unit.damage_dealt
		if damage > 0:
			_first_army_hit_frame = _frame
			_events.append({"frame": _frame, "action": "first_mortar_damage", "melee_clearance": clearance, "damage_dealt": damage})


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
				# Leave room for the ranged line to retreat during this fixed shot.
				var movement_room := movement_speed * float(LENGTH - _frame) / FPS
				bounds.position.x -= movement_room
				bounds.size.x += movement_room
			zoom = minf(UNIT_SCALE, (SIZE.x - 160.0) / bounds.size.x)
			target_x = bounds.get_center().x
		"army_launch":
			var bounds := _army_bounds(friends)
			# Nine occupied slots advance farther while finding firing positions.
			bounds.size.x += movement_speed * float(678 - _frame) / FPS
			zoom = minf(UNIT_SCALE, (SIZE.x - 160.0) / bounds.size.x)
			target_x = bounds.get_center().x
		"army_impact":
			target_x = enemy_front + 140.0
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
		var bounds: Rect2 = unit._appearance.get_global_transform_with_canvas() * unit._appearance.visual_rect_local(true)
		if bounds.position.x >= 0.0 and bounds.end.x <= SIZE.x:
			count += 1
	return count


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
	_events.append({"frame": _frame, "action": "cocoon_reveal", "weapon": _hero.weapon.display_name, "unit_scale": UNIT_SCALE, "complete_equation": true, "sound": "train", "shell_pieces": _shell_pieces.size(), "hop_height": REVEAL_HOP_HEIGHT, "apex_hold_seconds": 0.1})


func _process(_delta: float) -> void:
	if _finished or _processed_frame == _frame:
		return
	_processed_frame = _frame
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
		_cta.show()
	if is_instance_valid(_stage):
		_observe_army_engagement()
		for effect in _stage.get_node("World").get_children():
			if effect is CombatCallout:
				effect.hide()
	if _frame >= 0 and _frame % FPS == 0 and is_instance_valid(_stage):
		var living: Array[Unit] = _stage.player_troop.get_living_units()
		var foes: Array[Unit] = _stage.enemy_troop.get_living_units()
		var damage := 0
		for unit: Unit in _stage.player_troop.get_units():
			damage += unit.damage_dealt
		_events.append({"frame": _frame, "alive": living.size(), "enemies_alive": foes.size(), "fully_visible_players": _fully_visible(living), "fully_visible_enemies": _fully_visible(foes), "damage_dealt": damage, "zoom": _camera.zoom.x, "camera_x": _camera.position.x, "shot": _shot})
	if _frame >= LENGTH:
		_finished = true
		_finish.call_deferred()


func _record() -> void:
	if _finished:
		return
	assert(not _capture_busy, "GPU readback must not re-enter")
	_capture_busy = true
	if _frame >= 0:
		var snapshot := _probe and _frame in [0, 21, 30, 40, 51, 60, 95, 130, 142, 149, 150, 153, 156, 162, 165, 174, 185, 186, 192, 205, 220, 300, 340, 470, 500, 570, 620, 690, 740, 830, 870, 950]
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
	file.store_string(JSON.stringify({"weapon": _slug, "version": VERSION, "fps": FPS, "frames": _raw_frames, "width": SIZE.x, "height": SIZE.y, "unit_scale": UNIT_SCALE, "equation_center_x": _recipe.position.x + _recipe.size.x * 0.5, "audio_preroll_frames": 30, "events": _events}, "\t"))
	print("CAPTURE complete ", _slug, " frames=", _raw_frames)
	get_tree().quit()
