extends Node2D

const HERE := "res://.scratch/arrow-readability/"
const FONT := preload("res://assets/fonts/SpicyRice-Regular.ttf")
const BACKGROUND := preload("res://assets/base/background/bg_battlegrounds.png")
const ARROW := preload("res://assets/weapons/bow/arrow.png")
const WEAPONS: Array[String] = ["bow", "crossbow", "great_bow"]
const SCENES: Array[String] = ["arrow_projectile", "crossbow_projectile", "great_bow_projectile"]


func _ready() -> void:
	call_deferred("_run")


func _label(value: String, at: Vector2, width: float, font_size: int) -> void:
	var label := Label.new()
	label.position = at
	label.size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("293c39"))
	label.text = value
	add_child(label)


func _sprite(texture: Texture2D, at: Vector2, factor: float, angle: float = 0.0) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.scale = Vector2.ONE * factor
	sprite.rotation = deg_to_rad(angle)
	add_child(sprite)
	return sprite


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("e9e3d2"))
	_label("Arrow readability", Vector2(0, 16), 1920, 49)
	_label("Game scale · bow, crossbow and great bow · matching battlefield and surrounding sprites", Vector2(0, 79), 1920, 25)
	_label("Before · 512 × 512", Vector2(30, 132), 910, 30)
	_label("After · 64 × 24", Vector2(980, 132), 910, 30)
	var old_texture := ImageTexture.create_from_image(Image.load_from_file(HERE + "before/arrow.png"))
	for row in WEAPONS.size():
		for side in 2:
			var origin := Vector2(30 + side * 950, 185 + row * 240)
			var atlas := AtlasTexture.new()
			atlas.atlas = BACKGROUND
			atlas.region = Rect2(600, 400 + row * 480, 1820, 440)
			_sprite(atlas, origin + Vector2(455, 110), 0.5)
			var appearance := UnitAppearance.compose_player(true)
			appearance.position = origin + Vector2(115, 205)
			add_child(appearance)
			appearance.mount_weapon_appearance(load("res://assets/weapons/%s/%s.tres" % [WEAPONS[row], WEAPONS[row]]))
			appearance.play_idle(false)
			appearance.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			appearance.animation_player.advance(0.0)
			var enemy_data := load("res://assets/units/enemies/solar_sword/solar_sword_unit.tres") as EnemyUnitData
			var enemy := enemy_data.instantiate_appearance()
			enemy.position = origin + Vector2(800, 205)
			add_child(enemy)
			enemy.play_idle(false)
			enemy.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			enemy.animation_player.advance(0.0)
			for index in 3:
				var at := origin + Vector2(335 + index * 155, 130)
				var angle := float(-35 + index * 35)
				if side == 0:
					_sprite(old_texture, at, 0.1, angle)
				else:
					var projectile: Area2D = load("res://assets/weapons/%s/%s.tscn" % [WEAPONS[row], SCENES[row]]).instantiate()
					projectile.process_mode = Node.PROCESS_MODE_DISABLED
					projectile.monitoring = false
					projectile.monitorable = false
					projectile.position = at
					projectile.rotation = deg_to_rad(angle)
					var visual: Sprite2D = projectile.get_node("Visual")
					assert(visual.texture.get_size() == Vector2(64, 24))
					assert(visual.scale.is_equal_approx(Vector2(0.8, 0.8)))
					add_child(projectile)
	_label("4× enlarged · simplified shapes and consistent outline weight", Vector2(0, 920), 1920, 26)
	_sprite(old_texture, Vector2(485, 1005), 0.4)
	_sprite(ARROW, Vector2(1435, 1005), 3.2)
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(HERE + "preview.png")
	print("ARROW READABILITY PREVIEW: ", error_string(error), " · three projectile scenes checked")
	get_tree().quit(0 if error == OK else 1)
