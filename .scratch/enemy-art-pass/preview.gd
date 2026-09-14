extends Node2D

const FONT := preload("res://assets/fonts/SpicyRice-Regular.ttf")
const ENEMIES: Array[String] = [
	"solar_sword", "rose_thorn", "peashooter", "stump", "solar_cleaver",
	"durian", "log", "canopy", "seed_lobber", "acorn_knight",
]


func _ready() -> void:
	call_deferred("_run")


func _label(text: String, at: Vector2, width: float, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.position = at
	label.size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text = text
	add_child(label)


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("ebe4d3"))
	_label("Enemy art pass", Vector2(0, 22), 1920, 48, Color("293c39"))
	_label("Original / updated • same in-game scale", Vector2(0, 82), 1920, 23, Color("69715a"))
	for index in ENEMIES.size():
		var enemy_id := ENEMIES[index]
		var column := index % 5
		var row := floori(float(index) / 5.0)
		var origin := Vector2(12 + column * 380, 142 + row * 452)
		var panel := Polygon2D.new()
		panel.position = origin
		panel.polygon = PackedVector2Array([Vector2.ZERO, Vector2(364, 0), Vector2(364, 432), Vector2(0, 432)])
		panel.color = Color("e1dcc8")
		add_child(panel)
		var data := load("res://assets/units/enemies/%s/%s_unit.tres" % [enemy_id, enemy_id]) as EnemyUnitData
		_label(data.display_name, origin + Vector2(0, 12), 364, 30, Color("293c39"))
		var appearance := data.instantiate_appearance()
		add_child(appearance)
		appearance.position = origin + Vector2(265, 260)
		appearance.play_idle(false)
		appearance.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		appearance.animation_player.advance(0.0)
		var before_path := "/tmp/mycelium-enemy-art-before/%s.png" % enemy_id
		if FileAccess.file_exists(before_path):
			var before := Sprite2D.new()
			before.texture = ImageTexture.create_from_image(Image.load_from_file(before_path))
			before.position = origin + Vector2(95, 260) + appearance.sprite.position
			before.scale = appearance.sprite.scale
			before.offset = appearance.sprite.offset
			add_child(before)
		_label("Original", origin + Vector2(0, 276), 182, 20, Color("69715a"))
		_label("Updated", origin + Vector2(182, 276), 182, 20, Color("293c39"))
		var equipped := data.instantiate_appearance()
		add_child(equipped)
		equipped.position = origin + Vector2(182, 406)
		equipped.scale = Vector2(-0.6, 0.6)
		if data.show_held_weapon:
			equipped.mount_weapon_appearance(data.held_weapon)
		equipped.play_walk(false)
		equipped.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		equipped.animation_player.advance(0.18)
		_label("Scout scale · equipped", origin + Vector2(0, 405), 364, 17, Color("69715a"))
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output := get_viewport().get_texture().get_image()
	var error := output.save_png("res://.scratch/enemy-art-pass/preview.png")
	print("ENEMY ART PREVIEW: ", error_string(error))
	if not "--keep-open" in OS.get_cmdline_user_args():
		get_tree().quit(0 if error == OK else 1)
