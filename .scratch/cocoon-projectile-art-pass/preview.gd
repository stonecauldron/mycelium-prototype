extends Node2D

const FONT := preload("res://assets/fonts/SpicyRice-Regular.ttf")
const HERE := "res://.scratch/cocoon-projectile-art-pass/"
const ASSETS: Array[Dictionary] = [
	{"title": "Closed cocoon", "path": "assets/base/pupation/cocoon.png", "scale": 0.25},
	{"title": "Open cocoon", "path": "assets/base/pupation/cocoon_open.png", "scale": 0.25},
	{"title": "Arrow", "path": "assets/weapons/bow/arrow.png", "scale": 0.1},
	{"title": "Spore bomb", "path": "assets/weapons/mortar/spore_bomb_projectile.png", "scale": 0.35},
	{"title": "Horn notes", "path": "assets/weapons/giant_horn/horn_projectile.png", "scale": 0.35},
]
const PROJECTILES: Array[String] = [
	"res://assets/weapons/bow/arrow_projectile.tscn",
	"res://assets/weapons/crossbow/crossbow_projectile.tscn",
	"res://assets/weapons/great_bow/great_bow_projectile.tscn",
	"res://assets/weapons/mortar/mortar_projectile.tscn",
	"res://assets/weapons/giant_horn/horn_projectile.tscn",
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


func _sprite(texture: Texture2D, at: Vector2, factor: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.scale = Vector2.ONE * factor
	add_child(sprite)


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("e9e3d2"))
	_label("Cocoons & projectiles", Vector2(0, 24), 1920, 50, Color("293c39"))
	_label("Original / updated at game scale  ·  Detail on light and dark backgrounds", Vector2(0, 90), 1920, 25, Color("67705a"))
	for index in ASSETS.size():
		var asset: Dictionary = ASSETS[index]
		var path: String = asset.path
		var current: Texture2D = load("res://" + path)
		var previous := ImageTexture.create_from_image(Image.load_from_file(HERE + "before/" + path.get_file()))
		var x := float(20 + index * 380)
		_panel(Vector2(x, 150), Vector2(360, 740), Color("d9d4bf"))
		_label(asset.title, Vector2(x, 165), 360, 32, Color("293c39"))
		_sprite(previous, Vector2(x + 92, 300), asset.scale)
		_sprite(current, Vector2(x + 268, 300), asset.scale)
		_label("Original", Vector2(x, 375), 180, 21, Color("67705a"))
		_label("Updated", Vector2(x + 180, 375), 180, 21, Color("293c39"))
		_panel(Vector2(x + 12, 425), Vector2(336, 222), Color("eee9d9"))
		_panel(Vector2(x + 12, 650), Vector2(336, 222), Color("253a35"))
		var detail_scale := 0.42 if index < 2 else (0.65 if index == 2 else (1.5 if index == 3 else 0.6))
		_sprite(current, Vector2(x + 180, 536), detail_scale)
		_sprite(current, Vector2(x + 180, 761), detail_scale)
	_label("Instantiated projectile scenes at authored scales and flight rotations", Vector2(0, 909), 1920, 26, Color("293c39"))
	for index in PROJECTILES.size():
		var projectile: Area2D = load(PROJECTILES[index]).instantiate()
		projectile.process_mode = Node.PROCESS_MODE_DISABLED
		projectile.monitoring = false
		projectile.monitorable = false
		projectile.position = Vector2(195 + index * 380, 995)
		projectile.rotation = deg_to_rad(-18.0 if index < 4 else -8.0)
		add_child(projectile)
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(HERE + "preview.png")
	print("COCOON PROJECTILE PREVIEW: ", error_string(error))
	if not "--keep-open" in OS.get_cmdline_user_args():
		get_tree().quit(0 if error == OK else 1)
