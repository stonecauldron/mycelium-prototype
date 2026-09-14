extends Node2D

const FONT := preload("res://assets/fonts/SpicyRice-Regular.ttf")
const HERE := "res://.scratch/skull-art-pass/"
const SKULL := preload("res://assets/base/combat_progress_track/skull.png")
const TRACK := preload("res://assets/base/combat_progress_track/combat_progress_track.tscn")

var _hovered_days: Array[int] = []


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
	_label("Elite skull art pass", Vector2(0, 24), 1920, 52, Color("293c39"))
	_label("Bold bones · simpler face · native 56 px and hover checks", Vector2(0, 99), 1920, 28, Color("67705a"))
	var old_texture := ImageTexture.create_from_image(Image.load_from_file(HERE + "before/skull.png"))
	for index in 3:
		var x := float(190 + index * 520)
		_panel(Vector2(x, 168), Vector2(500, 448), Color("253a35") if index == 2 else Color("d9d4bf"))
		var sprite := Sprite2D.new()
		sprite.texture = old_texture if index == 0 else SKULL
		sprite.position = Vector2(x + 250, 427)
		sprite.scale = Vector2.ONE * 2.2
		add_child(sprite)
		_label("Original" if index == 0 else "Updated", Vector2(x, 187), 500, 32, Color("e9e3d2") if index == 2 else Color("293c39"))
	_label("Actual progression track · original / updated", Vector2(0, 639), 1920, 31, Color("293c39"))
	for row in 2:
		for side in 2:
			var origin := Vector2(230 + side * 780, 713 + row * 166)
			_panel(origin, Vector2(680, 145), Color("253a35") if row == 1 else Color("d9d4bf"))
			var track := TRACK.instantiate() as CombatProgressTrack
			track.position = origin + Vector2(126, 16)
			track.size = Vector2(420, 110)
			add_child(track)
			var day := 5 if row == 0 else 10
			track._chapter_start = 1 if row == 0 else 6
			track._upcoming_day = day
			track._build_nodes()
			track._layout_nodes()
			track._update_marker()
			track.queue_redraw()
			var skull: TextureRect = track.get_node("Node%d/SkullIcon" % day)
			assert(skull.texture == SKULL)
			assert(skull.get_parent().size == Vector2(56, 56))
			if side == 0:
				skull.texture = old_texture
			if row == 1:
				track.elite_hovered.connect(func(hover_day: int) -> void: _hovered_days.append(hover_day))
				skull.get_parent().mouse_entered.emit()
	await get_tree().create_timer(0.25).timeout
	assert(_hovered_days == [10, 10])
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(HERE + "preview.png")
	print("SKULL PREVIEW: ", error_string(error), " · elite day 5 / 10 and hover signal verified")
	get_tree().quit(0 if error == OK else 1)
