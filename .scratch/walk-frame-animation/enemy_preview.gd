extends Node2D

const FONT := preload("res://assets/fonts/SpicyRice-Regular.ttf")
const ENEMIES: Array[String] = ["stump", "durian", "log", "acorn_knight"]
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(label)


func _label(text: String, at: Vector2, width: float = 270.0, font_size: int = 26) -> void:
	var label := Label.new()
	label.position = at
	label.size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("293c39"))
	label.text = text
	add_child(label)


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("ebe4d3"))
	_label("Enemy footsteps — original idle and four walk frames", Vector2(160, 25), 1600, 38)
	var labels: Array[String] = ["Idle", "Frame 1", "Frame 2", "Frame 3", "Frame 4", "Mirrored + equipped"]
	for column in labels.size():
		_label(labels[column], Vector2(165 + column * 285, 100))
	for row in ENEMIES.size():
		var enemy_id := ENEMIES[row]
		var data := load("res://assets/units/enemies/%s/%s_unit.tres" % [enemy_id, enemy_id]) as EnemyUnitData
		_label(enemy_id.capitalize(), Vector2(0, 230 + row * 240), 175, 24)
		for column in labels.size():
			var appearance := data.instantiate_appearance()
			add_child(appearance)
			appearance.position = Vector2(300 + column * 285, 320 + row * 240)
			appearance.scale = Vector2(-1.1 if column == 5 else 1.1, 1.1)
			if column == 5 and data.show_held_weapon:
				appearance.mount_weapon_appearance(data.held_weapon)
			var player := appearance.animation_player
			var sprite := appearance.sprite
			var frames := sprite.get_node("WalkFrames") as AnimatedSprite2D
			var rest_position := sprite.position
			var body_transform := appearance.body_shape.transform
			var hurtbox_transform := (appearance.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D).transform
			var mount_transform := appearance.weapon_mount.transform
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			appearance.play_idle(false)
			player.advance(0.0)
			_check(not frames.visible and sprite.self_modulate.a == 1.0, enemy_id + ": original idle art")
			_check(sprite.material == null and frames.material == null, enemy_id + ": no background shader")
			appearance.play_walk(false)
			player.advance(0.0)
			_check(frames.visible and frames.frame == 0 and sprite.self_modulate.a == 0.0, enemy_id + ": switches to walk")
			var start_position := sprite.position
			var start_scale := sprite.scale
			player.advance(0.19)
			_check(frames.frame == 1 and sprite.position.y < start_position.y, enemy_id + ": passing frame and bounce")
			var phase := player.current_animation_position
			appearance.play_walk()
			_check(is_equal_approx(phase, player.current_animation_position), enemy_id + ": repeated walk preserves phase")
			player.advance(0.18)
			_check(frames.frame == 2, enemy_id + ": opposite contact")
			player.advance(0.18)
			_check(frames.frame == 3, enemy_id + ": opposite passing pose")
			player.advance(0.17)
			_check(frames.frame == 0 and sprite.position.is_equal_approx(start_position) and sprite.scale.is_equal_approx(start_scale), enemy_id + ": full stride loops with original squash")
			_check(appearance.body_shape.transform == body_transform and (appearance.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D).transform == hurtbox_transform, enemy_id + ": collision unchanged")
			_check(appearance.weapon_mount.transform == mount_transform, enemy_id + ": weapon mount unchanged")
			appearance.play_idle(false)
			player.advance(0.0)
			_check(not frames.visible and frames.frame == 0 and sprite.self_modulate.a == 1.0 and sprite.position == rest_position, enemy_id + ": walk returns to original idle")
			if column > 0:
				appearance.play_walk(false)
				player.seek(float(column - 1) * 0.18 if column < 5 else 0.09, true)
			if column == 5:
				player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	for enemy_id in ["solar_sword", "solar_cleaver", "rose_thorn", "peashooter", "canopy", "seed_lobber"]:
		var scene := load("res://assets/units/enemies/%s/%s_appearance.tscn" % [enemy_id, enemy_id]) as PackedScene
		var appearance := scene.instantiate()
		_check(not appearance.has_node("Sprite/WalkFrames"), enemy_id + ": legless enemy unchanged")
		appearance.free()
	for i in 5:
		await get_tree().process_frame
	if "--screenshot" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var output := get_viewport().get_texture().get_image()
		_check(output.save_png("res://.scratch/walk-frame-animation/enemy-preview.png") == OK, "Preview saved")
		var magenta_pixels := 0
		for y in range(0, output.get_height(), 2):
			for x in range(0, output.get_width(), 2):
				var pixel := output.get_pixel(x, y)
				if minf(pixel.r, pixel.b) - pixel.g > 0.3:
					magenta_pixels += 1
		_check(magenta_pixels == 0, "All four sheets render without magenta")
	print("ENEMY WALK FRAMES: %d checks, %d failures" % [_checks, _failures])
	if not "--keep-open" in OS.get_cmdline_user_args():
		get_tree().quit(0 if _failures == 0 else 1)
