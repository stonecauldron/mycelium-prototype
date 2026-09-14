extends Node2D

const WEAPONS: Array[String] = [
	"sword", "shield", "spear", "bow", "mace", "sickle",
	"great_sword", "great_shield", "great_spear", "great_bow", "great_hammer", "scythe",
	"sword_and_shield", "spear_and_shield", "mace_and_shield", "lance", "crossbow", "umbrella",
	"warhammer", "polehammer", "giant_horn", "mortar", "rapier", "sling",
]
const INK := Color("293c39")


func _ready() -> void:
	call_deferred("_run")


func _label(value: String, at: Vector2, width: float, font_size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	add_child(label)


func _icon(texture: Texture2D, at: Vector2, pixels: int) -> void:
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = texture
	icon.position = at
	icon.size = Vector2(pixels, pixels)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(icon)


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("ebe4d3"))
	var character := load("res://assets/units/generalist/gen_imago_body.tscn").instantiate() as Node2D
	character.position = Vector2(160, 130)
	character.scale = Vector2(0.8, 0.8)
	add_child(character)
	var cap := load("res://assets/units/generalist/gen_imago_cap.tscn").instantiate() as Sprite2D
	character.get_node("CapMount").add_child(cap)
	_label("Character reference", Vector2(236, 67), 250, 20)
	_label("Weapon icons", Vector2(0, 22), 1920, 44)
	_label("64 × 64 transparent assets · previews at 28 / 36 / 56 / 96 px", Vector2(0, 80), 1920, 24)
	for index in WEAPONS.size():
		var id := WEAPONS[index]
		var origin := Vector2(24 + (index % 6) * 316, 150 + floori(float(index) / 6.0) * 224)
		var panel := ColorRect.new()
		panel.position = origin
		panel.size = Vector2(296, 204)
		panel.color = Color("dedbc7")
		add_child(panel)
		var weapon := load("res://assets/weapons/%s/%s.tres" % [id, id]) as WeaponData
		assert(weapon != null and weapon.icon != null, "Missing icon: " + id)
		assert(weapon.icon.get_size() == Vector2(64, 64), "Icon must be 64 × 64: " + id)
		_label(weapon.display_name, origin + Vector2(0, 12), 296, 25)
		var sizes: Array[int] = [28, 36, 56, 96]
		var x := 10.0
		for pixels in sizes:
			_icon(weapon.icon, origin + Vector2(x, 64 + (96 - pixels) * 0.5), pixels)
			_label(str(pixels), origin + Vector2(x, 170), pixels, 16)
			x += pixels + 16
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://.scratch/weapon-icons/preview.png")
	print("WEAPON ICONS: 24 resources loaded at 64 × 64; preview: ", error_string(error))
	get_tree().quit(0 if error == OK else 1)
