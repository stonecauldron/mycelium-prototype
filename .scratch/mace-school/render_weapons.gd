extends Node2D

const _WEAPONS := ["warhammer", "polehammer", "sling", "sword_and_shield", "mace_and_shield", "spear_and_shield"]
const _FONT := preload("res://assets/fonts/SpicyRice-Regular.ttf")


func _ready() -> void:
	call_deferred("_run")


func _label(text: String, at: Vector2, font_size: int = 26) -> void:
	var label := Label.new()
	label.position = at
	label.size = Vector2(306, 45)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#293c39"))
	label.text = text
	add_child(label)


func _appearance(id: String, adult: bool, at: Vector2, facing: float = 1.0) -> UnitAppearance:
	var weapon := load("res://assets/weapons/%s/%s.tres" % [id, id]) as WeaponData
	var appearance := UnitAppearance.compose_player(adult)
	add_child(appearance)
	appearance.position = at
	appearance.scale *= Vector2(1.35 * facing, 1.35)
	appearance.mount_weapon_appearance(weapon)
	appearance.play_idle(false)
	return appearance


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("#ebe4d3"))
	_label("Mace school — in-engine weapon and offhand checks", Vector2(650, 20), 32)
	for i in _WEAPONS.size():
		var id: String = _WEAPONS[i]
		var weapon := load("res://assets/weapons/%s/%s.tres" % [id, id]) as WeaponData
		var x := float(i) * 320.0
		_label(weapon.display_name, Vector2(x, 95))
		_appearance(id, true, Vector2(x + 135, 320))
		_label("Adult", Vector2(x, 335), 20)
		_appearance(id, false, Vector2(x + 135, 610))
		_label("Child", Vector2(x, 625), 20)
	for i in 3:
		var x := float(i) * 320.0
		_appearance(_WEAPONS[i + 3], true, Vector2(x + 185, 945), -1.0)
		_label("Mirrored", Vector2(x, 960), 20)
	for i in 3:
		var x := float(i + 3) * 320.0
		var appearance := _appearance("spear_and_shield", i != 1, Vector2(x + 155, 945))
		appearance.weapon_mount.hide()
		if i == 2:
			appearance.rotation = deg_to_rad(30)
		_label("Spear released" if i < 2 else "Whole-body throw lean", Vector2(x, 960), 20)
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.scratch/mace-school/weapon-gallery.png")
	get_tree().quit()
