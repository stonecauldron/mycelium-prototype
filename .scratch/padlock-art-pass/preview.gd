extends Node2D

const FONT := preload("res://assets/fonts/SpicyRice-Regular.ttf")
const HERE := "res://.scratch/padlock-art-pass/"
const ICON := preload("res://assets/base/shop/padlock_locked.png")
const CONSUMERS: Array[Dictionary] = [
	{"scene": "res://assets/base/shop/shop_offer_card.tscn", "node": "LockIcon", "size": 56, "label": "Shop · 56 px"},
	{"scene": "res://assets/base/drop_slot/drop_slot.tscn", "node": "Margin/Stack/LockIcon", "size": 96, "label": "Squad slot · 96 px"},
	{"scene": "res://assets/base/plot_tile/plot_tile.tscn", "node": "Content/LockIcon", "size": 96, "label": "Nursery plot · 96 px"},
]


func _ready() -> void:
	call_deferred("_run")


func _label(value: String, at: Vector2, width: float, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.position = at
	label.size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
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
	_label("Padlock art pass", Vector2(0, 32), 1920, 52, Color("293c39"))
	_label("Same icon bounds · transparent arch · matte shading", Vector2(0, 108), 1920, 28, Color("67705a"))
	var old_texture := ImageTexture.create_from_image(Image.load_from_file(HERE + "before/padlock_locked.png"))
	for index in 3:
		var x := float(190 + index * 520)
		_panel(Vector2(x, 186), Vector2(500, 490), Color("253a35") if index == 2 else Color("d9d4bf"))
		var sprite := Sprite2D.new()
		sprite.texture = old_texture if index == 0 else ICON
		sprite.position = Vector2(x + 250, 454)
		sprite.scale = Vector2.ONE * 0.9
		add_child(sprite)
		_label("Original" if index == 0 else "Updated", Vector2(x, 205), 500, 32, Color("e9e3d2") if index == 2 else Color("293c39"))
	_label("Icons from their actual UI scenes, at authored sizes", Vector2(0, 712), 1920, 31, Color("293c39"))
	for index in CONSUMERS.size():
		var consumer: Dictionary = CONSUMERS[index]
		var scene: Node = load(consumer.scene).instantiate()
		var original_icon: TextureRect = scene.get_node(consumer.node)
		assert(original_icon.texture == ICON)
		assert(original_icon.custom_minimum_size == Vector2.ONE * consumer.size)
		var x := float(190 + index * 520)
		for variant in 2:
			var icon := original_icon.duplicate() as TextureRect
			icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
			icon.position = Vector2(x + 126 + variant * 246, 882) - Vector2.ONE * consumer.size * 0.5
			icon.size = Vector2.ONE * consumer.size
			icon.visible = true
			_panel(Vector2(x + variant * 250, 800), Vector2(246, 162), Color("253a35") if variant == 1 else Color("d9d4bf"))
			add_child(icon)
		_label(consumer.label, Vector2(x, 984), 500, 26, Color("293c39"))
		scene.free()
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(HERE + "preview.png")
	print("PADLOCK PREVIEW: ", error_string(error), " · three UI consumers verified")
	get_tree().quit(0 if error == OK else 1)
