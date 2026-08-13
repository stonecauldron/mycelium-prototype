class_name CombatProgressDayNode
extends Control

## Day node on the combat progress track. Theme blanks native TooltipPanel,
## so tooltips must be custom (same style as scout tips).

const _TOOLTIP_WIDTH := 160.0

var day: int = 1:
	set(value):
		day = value
		tooltip_text = "Day %d" % day


func setup(day_number: int) -> void:
	day = day_number
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _make_custom_tooltip(_for_text: String) -> Object:
	var tip := _build_day_tooltip()
	DetailTooltipPopup.configure(tip)
	return tip


func _build_day_tooltip() -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PaperStyles.apply_tooltip(panel)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = "Day %d" % day
	name_label.add_theme_color_override("font_color", PaperStyles.INK)
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(_TOOLTIP_WIDTH, 0)
	panel.add_child(name_label)
	panel.reset_size()
	return panel
