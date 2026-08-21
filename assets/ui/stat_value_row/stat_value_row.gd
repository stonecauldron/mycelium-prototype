class_name StatValueRow
extends HBoxContainer

enum Layout { ICON_FIRST, ICON_LAST }

@onready var _icon: TextureRect = %Icon
@onready var _abbrev: Label = %Abbrev
@onready var _value: Label = %Value

var _pending: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 4)
	_ignore_mouse(self)
	if not _pending.is_empty():
		_apply_pending()


func configure(
	abbrev: String,
	value_text: String,
	font_size: int,
	value_color: Color,
	show_abbrev: bool = false,
	layout: Layout = Layout.ICON_FIRST,
	icon_color: Color = StatDisplay.INK
) -> void:
	_pending = {
		"abbrev": abbrev,
		"value_text": value_text,
		"font_size": font_size,
		"value_color": value_color,
		"show_abbrev": show_abbrev,
		"layout": layout,
		"icon_color": icon_color,
	}
	if is_node_ready():
		_apply_pending()


func _apply_pending() -> void:
	if _icon == null or _abbrev == null or _value == null:
		return
	var abbrev := str(_pending.get("abbrev", "STR"))
	var value_text := str(_pending.get("value_text", ""))
	var font_size := int(_pending.get("font_size", 26))
	var value_color: Color = _pending.get("value_color", StatDisplay.INK)
	var show_abbrev := bool(_pending.get("show_abbrev", false))
	var layout: Layout = _pending.get("layout", Layout.ICON_FIRST) as Layout
	var icon_color: Color = _pending.get("icon_color", StatDisplay.INK)
	var icon_px := float(StatDisplay.icon_px(font_size))
	_icon.texture = StatDisplay.white_icon(abbrev)
	_icon.modulate = icon_color
	_icon.custom_minimum_size = Vector2(icon_px, icon_px)
	_icon.visible = not value_text.is_empty() or show_abbrev
	_abbrev.text = abbrev
	_abbrev.visible = show_abbrev
	_abbrev.add_theme_font_size_override("font_size", font_size)
	_abbrev.add_theme_color_override("font_color", value_color)
	_value.text = value_text
	_value.add_theme_font_size_override("font_size", font_size)
	_value.add_theme_color_override("font_color", value_color)
	custom_minimum_size.y = icon_px
	if layout == Layout.ICON_LAST:
		move_child(_value, 0)
		move_child(_icon, 1)
		move_child(_abbrev, 2)
		_abbrev.visible = false
	else:
		move_child(_icon, 0)
		move_child(_abbrev, 1)
		move_child(_value, 2)


func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)
