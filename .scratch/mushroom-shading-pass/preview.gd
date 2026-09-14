extends Node2D

const FONT := preload("res://assets/fonts/SpicyRice-Regular.ttf")
const BEFORE := "res://.scratch/mushroom-shading-pass/before/"

func _ready() -> void:
	call_deferred("_run")

func _label(text: String, at: Vector2, width: float, font_size: int = 26) -> void:
	var label := Label.new()
	label.position = at
	label.size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("293c39"))
	label.text = text
	add_child(label)

func _old_texture(name: String) -> ImageTexture:
	return ImageTexture.create_from_image(Image.load_from_file(BEFORE + name))

func _run() -> void:
	RenderingServer.set_default_clear_color(Color("ebe4d3"))
	_label("Mushroom shading", Vector2(120, 30), 1680, 46)
	var groups: Array[String] = ["Child", "Adult", "Flag bearer"]
	for group in 3:
		_label(groups[group], Vector2(group * 640, 105), 640, 32)
		for version in 2:
			var x := float(group * 640 + 175 + version * 290)
			_label("Before" if version == 0 else "After", Vector2(x - 120, 720), 240)
			if group < 2:
				var adult := group == 1
				var appearance := UnitAppearance.compose_player(adult)
				add_child(appearance)
				appearance.position = Vector2(x, 680)
				appearance.scale = Vector2(2.7, 2.7)
				appearance.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				appearance.play_idle(false)
				appearance.animation_player.seek(0.0, true)
				if version == 0:
					var age := "imago" if adult else "child"
					appearance.sprite.texture = _old_texture("gen_%s_body.png" % age)
					var cap := appearance.get_node("Body/CapMount").get_child(0) as Sprite2D
					cap.texture = _old_texture("gen_%s_cap.png" % age)
			else:
				var flag := preload("res://assets/combat/flag_bearer/flag_bearer_visual.tscn").instantiate() as Node2D
				add_child(flag)
				flag.position = Vector2(x, 680)
				flag.scale = Vector2(1.65, 1.65)
				var player := flag.get_node("AnimationPlayer") as AnimationPlayer
				player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				player.play("idle")
				player.seek(0.0, true)
				if version == 0:
					var old := _old_texture("flag.png")
					(flag.get_node("Shroom") as Sprite2D).texture = old
					(flag.get_node("Shroom/Flag") as Sprite2D).texture = old
		for frame in 4:
			var at := Vector2(group * 640 + 112 + frame * 139, 998)
			if group < 2:
				var appearance := UnitAppearance.compose_player(group == 1)
				add_child(appearance)
				appearance.position = at
				appearance.scale = Vector2(1.25, 1.25)
				appearance.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				appearance.play_walk(false)
				appearance.animation_player.seek(frame * 0.18, true)
			else:
				var flag := preload("res://assets/combat/flag_bearer/flag_bearer_visual.tscn").instantiate() as Node2D
				add_child(flag)
				flag.position = at
				(flag.get_node("Shroom/Flag") as Sprite2D).hide()
				var player := flag.get_node("AnimationPlayer") as AnimationPlayer
				player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				player.play("walk")
				player.seek(frame * 0.18, true)
	_label("All walking frames", Vector2(120, 785), 1680, 28)
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output := get_viewport().get_texture().get_image()
	var error := output.save_png("res://.scratch/mushroom-shading-pass/comparison.png")
	print("SHADING PREVIEW: ", error_string(error))
	get_tree().quit(0 if error == OK else 1)
