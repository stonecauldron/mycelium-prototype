extends CheckBox


func _ready() -> void:
	# A checkbox remains a distinct control beside the primary New Run action.
	# Override inherited paper Button styles, which otherwise obscure its label.
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 12.0
	empty.content_margin_right = 12.0
	empty.content_margin_top = 6.0
	empty.content_margin_bottom = 6.0
	for state in ["normal", "pressed", "hover", "hover_pressed", "disabled"]:
		add_theme_stylebox_override(state, empty)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(0.18, 0.16, 0.14, 1)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	add_theme_stylebox_override("focus", focus)
	add_theme_constant_override("h_separation", 10)
	for icon_name in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		var source := get_theme_icon(icon_name, "CheckBox")
		if source == null:
			continue
		var icon_texture := ImageTexture.create_from_image(source.get_image())
		icon_texture.set_size_override(Vector2i(26, 26))
		add_theme_icon_override(icon_name, icon_texture)
	refresh()
	toggled.connect(SettingsServer.set_guided_run_enabled)


func refresh() -> void:
	set_pressed_no_signal(SettingsServer.guided_run_enabled)
