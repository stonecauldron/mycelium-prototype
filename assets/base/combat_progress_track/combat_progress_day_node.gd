class_name CombatProgressDayNode
extends Control

## Day node on the combat progress track. Theme blanks native TooltipPanel,
## so tooltips must be custom (same style as scout tips).

const _TOOLTIP_WIDTH := 160.0

var day: int = 1:
	set(value):
		day = value
		tooltip_text = "Day %d" % day
		if GameState.is_seal_choice_day(day):
			tooltip_text += "\nSeal choice · Before Battle %d" % day
		accessibility_name = tooltip_text


func setup(day_number: int) -> void:
	day = day_number
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(_show_focus_tooltip)
	focus_exited.connect(_hide_focus_tooltip)
	var day_label := Label.new()
	day_label.text = str(day)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	day_label.add_theme_color_override("font_color", PaperStyles.INK)
	day_label.add_theme_font_size_override("font_size", 24)
	day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(day_label)


func _show_focus_tooltip() -> void:
	# Keep the lease alive until focus leaves, just like the engine's hover tooltip.
	var lease := DetailTooltipPopup.configure(_build_day_tooltip())
	lease.name = "FocusTooltipLease"
	add_child(lease)


func _hide_focus_tooltip() -> void:
	var lease := get_node_or_null("FocusTooltipLease")
	if lease != null:
		lease.queue_free()


func _make_custom_tooltip(_for_text: String) -> Object:
	var tip := _build_day_tooltip()
	return DetailTooltipPopup.configure(tip)


func _has_point(point: Vector2) -> bool:
	# Include the Seal artwork above the circle in this Day's hover target.
	var top := -36.0 if GameState.is_seal_choice_day(day) else 0.0
	return Rect2(Vector2(0, top), size - Vector2(0, top)).has_point(point)


func _build_day_tooltip() -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PaperStyles.apply_tooltip(panel)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = tooltip_text
	name_label.add_theme_color_override("font_color", PaperStyles.INK)
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(_TOOLTIP_WIDTH, 0)
	panel.add_child(name_label)
	panel.reset_size()
	return panel
