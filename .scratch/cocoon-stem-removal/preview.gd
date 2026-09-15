extends Node2D

const FONT := preload("res://assets/fonts/SpicyRice-Regular.ttf")
const HERE := "res://.scratch/cocoon-stem-removal/"
const SLOT := preload("res://assets/base/pupation/cocoon_slot.tscn")


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


func _panel(at: Vector2, extent: Vector2, color: Color) -> void:
	var panel := Polygon2D.new()
	panel.position = at
	panel.color = color
	panel.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(extent.x, 0), extent, Vector2(0, extent.y),
	])
	add_child(panel)


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("e9e3d2"))
	_label("Stemless cocoons", Vector2(0, 25), 1920, 52)
	_label("Rounded tops · matched width and baseline · unchanged 512 × 512 canvases", Vector2(0, 103), 1920, 28)
	var slot := SLOT.instantiate()
	var actual_image: TextureRect = slot.get_node("Margin/VBox/CocoonImage")
	assert(actual_image.custom_minimum_size == Vector2(128, 128))
	for index in 4:
		var x := float(24 + index * 474)
		var name := "cocoon" if index < 2 else "cocoon_open"
		var is_before := index % 2 == 0
		var texture: Texture2D
		if is_before:
			texture = ImageTexture.create_from_image(Image.load_from_file(HERE + "before/" + name + ".png"))
		else:
			texture = load("res://assets/base/pupation/" + name + ".png")
		_panel(Vector2(x, 177), Vector2(450, 493), Color("d9d4bf"))
		_label(("Closed" if index < 2 else "Open") + (" · before" if is_before else " · after"), Vector2(x, 197), 450, 32)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.position = Vector2(x + 225, 455)
		sprite.scale = Vector2.ONE * 0.72
		add_child(sprite)
		_panel(Vector2(x, 791), Vector2(450, 210), Color("253a35"))
		var native_image := actual_image.duplicate() as TextureRect
		native_image.texture = texture
		native_image.set_anchors_preset(Control.PRESET_TOP_LEFT)
		native_image.position = Vector2(x + 161, 826)
		native_image.size = Vector2(128, 128)
		add_child(native_image)
	_label("Actual cocoon-slot image size · 128 × 128", Vector2(0, 719), 1920, 32)
	slot.free()
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(HERE + "preview.png")
	print("STEMLESS COCOON PREVIEW: ", error_string(error))
	get_tree().quit(0 if error == OK else 1)
