class_name CombatProgressDayNode
extends Control

## Day node on the combat progress track. Theme blanks native TooltipPanel,
## so tooltips must be custom (same style as scout / strain tips).

const _TOOLTIP_WIDTH := 160.0
const _PANEL_BG := Color(0.92156863, 0.9098039, 0.87058824, 1)
const _INK := Color(0.03137255, 0.03529412, 0.02745098, 1)

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
	tip.tree_entered.connect(_configure_tooltip_popup.bind(tip), CONNECT_ONE_SHOT)
	return tip


func _build_day_tooltip() -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = _PANEL_BG
	style.border_color = Color(0, 0, 0, 1)
	style.set_border_width_all(5)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14.0
	style.content_margin_top = 12.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = "Day %d" % day
	name_label.add_theme_color_override("font_color", _INK)
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(_TOOLTIP_WIDTH, 0)
	panel.add_child(name_label)
	panel.reset_size()
	return panel


func _configure_tooltip_popup(tip: Control) -> void:
	var node: Node = tip.get_parent()
	while node != null:
		if node is PopupPanel:
			var popup := node as PopupPanel
			popup.transparent = true
			popup.transparent_bg = true
			popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			var tip_size := tip.get_combined_minimum_size()
			popup.size = Vector2i(ceili(tip_size.x), ceili(tip_size.y))
			return
		node = node.get_parent()
