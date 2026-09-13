class_name BiomassDisplay
extends RefCounted

const ICON := preload("res://assets/base/biomass_small_icon.png")
## Descriptions stay readable in resources; render the icon between amount and name.
const TOKEN_PATTERN := "(?<![\\w.])[+−-]?\\d+[ \\t]+biomass\\b"


static func number(amount: int, signed: bool = false) -> String:
	if amount < 0:
		return "−%d" % absi(amount)
	return "+%d" % amount if signed and amount > 0 else str(amount)


static func text(amount: int, signed: bool = false) -> String:
	return "%s biomass" % number(amount, signed)


static func token_number(token: String) -> String:
	return token.trim_suffix("biomass").strip_edges().replace("-", "−")


static func append_amount(label: RichTextLabel, value: String, font_size: int) -> void:
	# NBSP and word joiners keep the amount and inline object on the same line.
	label.add_text(value + "\u00a0\u2060")
	label.add_image(ICON, font_size, font_size, Color.WHITE, INLINE_ALIGNMENT_CENTER)
	label.add_text("\u2060")


static func make_amount(value: String, font_size: int, color: Color, outlined: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", maxi(2, roundi(font_size * 0.15)))
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outlined:
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 5)
	row.add_child(label)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = ICON
	icon.custom_minimum_size = Vector2(font_size, font_size)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	return row
