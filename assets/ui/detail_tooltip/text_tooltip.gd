extends Control

## Readable text tips for Controls in the theme with a blank native TooltipPanel.
func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PaperStyles.apply_tooltip(panel)
	var label := Label.new()
	label.text = for_text
	label.custom_minimum_size.x = 440.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", PaperStyles.INK)
	label.add_theme_font_size_override("font_size", 22)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return DetailTooltipPopup.configure(panel)
