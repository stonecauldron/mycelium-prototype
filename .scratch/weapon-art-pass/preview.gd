extends Node2D

const WEAPONS: Array[String] = [
	"sword", "mace", "shield", "spear", "bow", "sickle",
	"great_sword", "great_hammer", "great_shield", "great_spear", "great_bow", "giant_horn",
	"warhammer", "polehammer", "lance", "crossbow", "umbrella", "mortar",
	"rapier", "scythe", "sling", "sword_and_shield", "spear_and_shield", "mace_and_shield",
]


func _ready() -> void:
	call_deferred("_run")


func _label(value: String, at: Vector2, width: float, font_size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("293c39"))
	add_child(label)


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("e8e2ce"))
	_label("Weapon art pass · character-scale inspection", Vector2(0, 10), 1920, 34)
	for index in WEAPONS.size():
		var id := WEAPONS[index]
		var origin := Vector2(12 + (index % 6) * 318, 68 + floori(float(index) / 6.0) * 250)
		var panel := ColorRect.new()
		panel.position = origin
		panel.size = Vector2(306, 240)
		panel.color = Color("c4c4ae") if index >= 6 and index < 12 else Color("d7d6c2")
		add_child(panel)
		var weapon := load("res://assets/weapons/%s/%s.tres" % [id, id]) as WeaponData
		assert(weapon != null)
		var actor := UnitAppearance.compose_player(true)
		actor.position = origin + Vector2(100, 202)
		add_child(actor)
		actor.mount_weapon_appearance(weapon)
		var visual := actor.weapon_mount.get_child(0).get_node("Visual") as Sprite2D
		if visual == null or visual.texture == null or visual.texture.get_size() != Vector2(512, 512):
			push_error("Invalid weapon sprite: " + id)
			get_tree().quit(1)
			return
		_label(weapon.display_name, origin + Vector2(0, 208), 306, 23)
	for frame in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://.scratch/weapon-art-pass/preview.png")
	print("WEAPON ART: 24 equipment combinations mounted; preview: ", error_string(error))
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if error == OK else 1)
