class_name StatDisplay
extends RefCounted

## Renders STR/DEX/CON as 1em silhouettes. Source PNGs are black; we convert to
## white-alpha once so TextureRect.modulate and RichTextLabel.add_image color work.

const INK := Color(0.03137255, 0.03529412, 0.02745098, 1)
const INK_MUTED := Color(0.2, 0.22, 0.18, 1)
## Silhouettes read small next to type; draw a bit larger than 1em.
const ICON_EM := 1.5

const ABBREVS: PackedStringArray = ["STR", "DEX", "CON"]
const DISPLAY_NAMES := {
	"STR": "Strength",
	"DEX": "Dexterity",
	"CON": "Constitution",
}
const DESCRIPTIONS := {
	"STR": "Affects damage with melee attacks.",
	"DEX": "Affects damage with ranged attacks.",
	"CON": "Determines Max HP",
}

const _STAT_ICON_SCENE := preload("res://assets/ui/stat_icon/stat_icon.tscn")

const _ICON_PATHS := {
	"STR": "res://assets/ui/STR_icon.png",
	"DEX": "res://assets/ui/DEX_icon.png",
	"CON": "res://assets/ui/CON_icon.png",
}

static var _white_icons: Dictionary = {}
static var _abbrev_regex: RegEx


static func white_icon(abbrev: String) -> Texture2D:
	var key := abbrev.to_upper()
	if _white_icons.has(key):
		return _white_icons[key] as Texture2D
	var path := str(_ICON_PATHS.get(key, ""))
	if path.is_empty():
		return null
	var src := load(path) as Texture2D
	if src == null:
		return null
	var img := src.get_image()
	if img == null:
		_white_icons[key] = src
		return src
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var pixel := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, pixel.a))
	var tex := ImageTexture.create_from_image(img)
	_white_icons[key] = tex
	return tex


static func display_name(abbrev: String) -> String:
	return str(DISPLAY_NAMES.get(abbrev.to_upper(), abbrev))


static func description(abbrev: String) -> String:
	return str(DESCRIPTIONS.get(abbrev.to_upper(), ""))


static func make_tooltip(abbrev: String) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PaperStyles.apply_tooltip(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = display_name(abbrev)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", INK)
	box.add_child(title)
	var body := Label.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.text = description(abbrev)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(220, 0)
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", INK_MUTED)
	box.add_child(body)
	return panel


static func icon_px(font_size: int) -> int:
	return maxi(1, int(round(float(font_size) * ICON_EM)))


static func textures_for_damage_stat(damage_stat: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	match damage_stat:
		WeaponData.DamageStat.DEX:
			out.append(white_icon("DEX"))
		WeaponData.DamageStat.FINESSE:
			out.append(white_icon("STR"))
			out.append(white_icon("DEX"))
		_:
			out.append(white_icon("STR"))
	return out


static func apply_to(
	rtl: RichTextLabel,
	source: String,
	font_size: int,
	color: Color,
	icon_color: Color = INK
) -> void:
	if rtl == null:
		return
	rtl.bbcode_enabled = false
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.add_theme_font_size_override("normal_font_size", font_size)
	rtl.add_theme_color_override("default_color", color)
	rtl.clear()
	var text := source
	var regex := _regex()
	if regex == null:
		rtl.add_text(text)
		return
	var pos := 0
	for matched in regex.search_all(text):
		var start := matched.get_start()
		if start > pos:
			rtl.add_text(text.substr(pos, start - pos))
		var tex := white_icon(matched.get_string())
		if tex != null:
			var px := icon_px(font_size)
			rtl.add_image(tex, px, px, icon_color, INLINE_ALIGNMENT_CENTER)
		else:
			rtl.add_text(matched.get_string())
		pos = matched.get_end()
	if pos < text.length():
		rtl.add_text(text.substr(pos))


static func fill_inline(
	host: VBoxContainer,
	source: String,
	font_size: int,
	text_color: Color,
	icon_color: Color = INK
) -> void:
	if host == null:
		return
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
	if source.is_empty():
		return
	for line in source.split("\n"):
		var flow := HFlowContainer.new()
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 2)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_fill_flow(flow, line, font_size, text_color, icon_color)
		host.add_child(flow)


static func _fill_flow(
	flow: HFlowContainer,
	line: String,
	font_size: int,
	text_color: Color,
	icon_color: Color
) -> void:
	var regex := _regex()
	if regex == null or regex.search(line) == null:
		flow.add_child(_make_text_label(line, font_size, text_color, true))
		return
	var pos := 0
	for matched in regex.search_all(line):
		var start := matched.get_start()
		if start > pos:
			_add_text_run(flow, line.substr(pos, start - pos), font_size, text_color)
		var icon: StatIcon = _STAT_ICON_SCENE.instantiate()
		icon.setup(matched.get_string(), icon_px(font_size), icon_color)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		flow.add_child(icon)
		pos = matched.get_end()
	if pos < line.length():
		_add_text_run(flow, line.substr(pos), font_size, text_color)


static func _add_text_run(
	flow: HFlowContainer,
	run: String,
	font_size: int,
	color: Color
) -> void:
	for word in run.split(" ", false):
		if word.is_empty():
			continue
		flow.add_child(_make_text_label(word, font_size, color, false))


static func _make_text_label(
	text: String,
	font_size: int,
	color: Color,
	autowrap: bool
) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if autowrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


static func make_rich_label(
	source: String,
	font_size: int,
	color: Color,
	min_width: float = 0.0
) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.bbcode_enabled = false
	rtl.fit_content = true
	rtl.scroll_active = false
	if min_width > 0.0:
		rtl.custom_minimum_size = Vector2(min_width, 0)
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_to(rtl, source, font_size, color)
	return rtl


static func _regex() -> RegEx:
	if _abbrev_regex == null:
		_abbrev_regex = RegEx.new()
		_abbrev_regex.compile("\\b(STR|DEX|CON)\\b")
	return _abbrev_regex
