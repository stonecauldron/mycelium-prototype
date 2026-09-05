extends Node2D

const FONT := preload("res://assets/fonts/SpicyRice-Regular.ttf")
const FLAG_SCENE := preload("res://assets/combat/flag_bearer/flag_bearer.tscn")
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
	_label("Flag bearer — footsteps, bounce and banner sway", Vector2(160, 28), 1600, 38)
	var labels: Array[String] = ["Idle", "Left contact", "Right foot lifted", "Right contact", "Left foot lifted", "Walking loop"]
	for column in labels.size():
		_label(labels[column], Vector2(column * 320, 105))
	for mirrored in [false, true]:
		for column in labels.size():
			var flag := FLAG_SCENE.instantiate() as FlagBearer
			flag.flag_faces_left = mirrored
			flag.flag_color = Color("b7b08d") if mirrored else Color.WHITE
			add_child(flag)
			flag.set_physics_process(false)
			flag.position = Vector2(column * 320 + 155, 960 if mirrored else 520)
			flag.scale = Vector2(1.25, 1.25)
			var player := flag.get_node("Visual/AnimationPlayer") as AnimationPlayer
			var shroom := flag.get_node("Visual/Shroom") as Sprite2D
			var frames := shroom.get_node("WalkFrames") as AnimatedSprite2D
			var banner := shroom.get_node("Flag") as Sprite2D
			var collider := flag.get_node("CollisionShape2D") as CollisionShape2D
			var collision_transform := collider.transform
			var banner_position := banner.position
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			flag._play_idle_animation(false)
			player.seek(0.0, true)
			_check(not frames.visible and shroom.self_modulate.a == 1.0, "Idle shows original body")
			flag._play_walk_animation()
			player.advance(0.0)
			_check(frames.visible and shroom.self_modulate.a == 0.0, "Walk switches to frame art")
			var start_position := shroom.position
			var start_scale := shroom.scale
			player.advance(0.09)
			_check(is_equal_approx(banner.rotation, 0.1), "Original banner sway is retained")
			player.advance(0.1)
			_check(frames.frame == 1 and shroom.position.y < start_position.y, "Passing pose overlaps the rising bounce")
			var phase := player.current_animation_position
			flag._play_walk_animation()
			_check(is_equal_approx(player.current_animation_position, phase), "Repeated walk request preserves phase")
			player.advance(0.18)
			_check(frames.frame == 2, "Opposite contact pose plays")
			player.advance(0.18)
			_check(frames.frame == 3, "Opposite passing pose plays")
			player.advance(0.17)
			_check(frames.frame == 0, "Stride loops")
			_check(shroom.position.is_equal_approx(start_position) and shroom.scale.is_equal_approx(start_scale), "Original bounce and squash loop")
			_check(is_zero_approx(banner.rotation) and banner.position == banner_position, "Banner stays attached through the stride")
			_check(collider.transform == collision_transform, "Visual animation leaves the collider unchanged")
			flag.reset_combat_state()
			player.advance(0.0)
			_check(not frames.visible and frames.frame == 0 and shroom.self_modulate.a == 1.0, "Combat reset restores original idle art")
			_check(shroom.modulate == flag.flag_color and banner.modulate == Color.WHITE, "Team tint is applied once")
			player.seek(0.0, true)
			if column > 0:
				flag._play_walk_animation()
				player.seek(float(column - 1) * 0.18 if column < 5 else 0.09, true)
			if column == 5:
				player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	_label("Original colors", Vector2(60, 535), 1800, 27)
	_label("Mirrored + team tint", Vector2(60, 975), 1800, 27)
	for i in 5:
		await get_tree().process_frame
	if "--screenshot" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var output := get_viewport().get_texture().get_image()
		_check(output.save_png("res://.scratch/walk-frame-animation/flag-preview.png") == OK, "Preview saved")
		var magenta_pixels := 0
		for y in range(0, output.get_height(), 2):
			for x in range(0, output.get_width(), 2):
				var pixel := output.get_pixel(x, y)
				if minf(pixel.r, pixel.b) - pixel.g > 0.3:
					magenta_pixels += 1
		_check(magenta_pixels == 0, "Transparent walk sheet has no magenta background")
	print("FLAG WALK FRAMES: %d checks, %d failures" % [_checks, _failures])
	if not "--keep-open" in OS.get_cmdline_user_args():
		get_tree().quit(0 if _failures == 0 else 1)
