extends Node2D

const FONT := preload("res://assets/fonts/SpicyRice-Regular.ttf")
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(label)


func _label(text: String, at: Vector2, width: float = 300.0, font_size: int = 26) -> void:
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
	_label("Mushroom walk — sprite frames + original bounce", Vector2(210, 32), 1500, 40)
	var labels: Array[String] = ["Idle", "Left contact", "Right foot lifted", "Right contact", "Left foot lifted", "Mirrored + tinted"]
	for column in labels.size():
		_label(labels[column], Vector2(column * 320, 130))
	for adult in [true, false]:
		for column in labels.size():
			var mutation: MutationData = null
			if column == 5:
				mutation = load("res://assets/base/nursery/mutations/body/thorny.tres") as MutationData
			var appearance := UnitAppearance.compose_player(adult, mutation)
			add_child(appearance)
			appearance.position = Vector2(column * 320 + 155, 470 if adult else 810)
			appearance.scale = Vector2(-2.0 if column == 5 else 2.0, 2.0)
			appearance.mount_weapon_appearance(load("res://assets/weapons/sword_and_shield/sword_and_shield.tres") as WeaponData)
			var player := appearance.animation_player
			var frames := appearance.get_node("Body/Sprite/WalkFrames") as AnimatedSprite2D
			var collision_transform := appearance.body_shape.transform
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			appearance.play_idle(false)
			player.advance(0.0)
			_check(not frames.visible and appearance.sprite.self_modulate.a == 1.0, "Idle uses original art")
			appearance.play_walk(false)
			player.advance(0.0)
			_check(frames.visible and appearance.sprite.self_modulate.a == 0.0, "Walking shows only frame art")
			var first_position := appearance.sprite.position
			var first_scale := appearance.sprite.scale
			player.advance(0.19)
			_check(frames.frame == 1, "Walking advances to passing pose")
			_check(appearance.sprite.position.y < first_position.y, "Original bounce still rises")
			var saved_time := player.current_animation_position
			appearance.play_walk(false)
			_check(is_equal_approx(player.current_animation_position, saved_time), "Repeated walk request preserves phase")
			player.advance(0.18)
			_check(frames.frame == 2, "Opposite foot leads the second step")
			player.advance(0.18)
			_check(frames.frame == 3, "Opposite passing pose plays")
			player.advance(0.17)
			_check(frames.frame == 0, "Frame cycle loops")
			_check(appearance.sprite.position.is_equal_approx(first_position), "Bounce loops with the frame cycle")
			_check(appearance.sprite.scale.is_equal_approx(first_scale), "Squash loops with the frame cycle")
			_check(appearance.body_shape.transform == collision_transform, "Walking leaves the collider unchanged")
			appearance.play_idle(false)
			player.advance(0.0)
			_check(not frames.visible and frames.frame == 0, "Stopping resets and hides the walk frames")
			_check(appearance.sprite.self_modulate.a == 1.0, "Stopping restores original art")
			if column > 0:
				appearance.play_walk(false)
				player.seek(float(column - 1) * 0.18 if column < 5 else 0.18, true)
			if column == 5:
				player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		_label("Adults", Vector2(50, 490), 1820, 30)
	_label("Children", Vector2(50, 830), 1820, 30)
	_label("Four footstep poses • two bounces per cycle • original idle art", Vector2(200, 940), 1520, 28)
	for i in 5:
		await get_tree().process_frame
	if "--screenshot" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var output := get_viewport().get_texture().get_image()
		_check(output.save_png("res://.scratch/walk-frame-animation/preview.png") == OK, "Preview saved")
		var magenta_pixels := 0
		for y in range(0, output.get_height(), 2):
			for x in range(0, output.get_width(), 2):
				var pixel := output.get_pixel(x, y)
				if minf(pixel.r, pixel.b) - pixel.g > 0.3:
					magenta_pixels += 1
		_check(magenta_pixels == 0, "Transparent sheets render without magenta background")
	print("WALK FRAMES: %d checks, %d failures" % [_checks, _failures])
	if not "--keep-open" in OS.get_cmdline_user_args():
		get_tree().quit(0 if _failures == 0 else 1)
