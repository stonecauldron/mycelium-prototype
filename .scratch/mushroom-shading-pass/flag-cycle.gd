extends Node2D

const FONT := preload("res://assets/fonts/SpicyRice-Regular.ttf")
const VISUAL := preload("res://assets/combat/flag_bearer/flag_bearer_visual.tscn")
const BEFORE := "res://.scratch/mushroom-shading-pass/flag-consistency-before/"
var players: Array[AnimationPlayer] = []

func _ready() -> void:
	call_deferred("_run")

func _label(text: String, at: Vector2, width: float, font_size: int = 38) -> void:
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
	_label("Flag bearer shading", Vector2(0, 35), 1920, 58)
	for version in 2:
		var x := 570.0 + version * 780.0
		_label("Before" if version == 0 else "After", Vector2(x - 250, 960), 500)
		var flag := VISUAL.instantiate() as Node2D
		add_child(flag)
		flag.position = Vector2(x, 930)
		flag.scale = Vector2(2.5, 2.5)
		var player := flag.get_node("AnimationPlayer") as AnimationPlayer
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		players.append(player)
		if version == 0:
			var old := _old_texture("flag.png")
			(flag.get_node("Shroom") as Sprite2D).texture = old
			(flag.get_node("Shroom/Flag") as Sprite2D).texture = old
			var walk := flag.get_node("Shroom/WalkFrames") as AnimatedSprite2D
			walk.sprite_frames = walk.sprite_frames.duplicate(true)
			for frame in 4:
				var tex := walk.sprite_frames.get_frame_texture(&"walk", frame).duplicate() as AtlasTexture
				tex.atlas = _old_texture("flag_bearer_walk.png")
				walk.sprite_frames.set_frame(&"walk", frame, tex)
	for frame in 5:
		for player in players:
			player.play("idle" if frame == 0 else "walk")
			player.seek(0.0 if frame == 0 else (frame - 1) * 0.18, true)
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png("res://.scratch/mushroom-shading-pass/flag-cycle-frames/%02d.png" % frame)
		assert(error == OK)
	print("FLAG SHADING CYCLE: OK")
	get_tree().quit()
