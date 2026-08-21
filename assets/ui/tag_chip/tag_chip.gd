class_name TagChip
extends PanelContainer

const _INK := Color(0.03137255, 0.03529412, 0.02745098, 1)

@export var text: String = "":
	set(value):
		text = value
		_mode_icons = false
		_caption = ""
		if is_node_ready():
			_apply_mode()

var _mode_icons: bool = false
var _icon_textures: Array[Texture2D] = []
var _icon_glue: String = "or"
var _icon_px: int = 22
var _caption: String = ""

@onready var _label: Label = %Label
@onready var _icon_a: TextureRect = %IconA
@onready var _icon_b: TextureRect = %IconB
@onready var _glue: Label = %Glue


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_children_mouse_filter_ignore(self)
	_apply_mode()


func set_text(value: String) -> void:
	text = value


func show_icons(
	textures: Array[Texture2D],
	glue: String = "or",
	icon_px: int = 22,
	caption: String = ""
) -> void:
	_mode_icons = true
	_icon_textures.clear()
	for tex in textures:
		_icon_textures.append(tex)
	_icon_glue = glue
	_icon_px = StatDisplay.icon_px(icon_px)
	_caption = caption
	if is_node_ready():
		_apply_mode()


func set_content_font_size(font_size: int) -> void:
	_icon_px = StatDisplay.icon_px(font_size)
	if _label != null:
		_label.add_theme_font_size_override("font_size", font_size)
	if _glue != null:
		_glue.add_theme_font_size_override("font_size", font_size)
	_apply_icon_size()


func set_fill_color(color: Color) -> void:
	var base := get_theme_stylebox("panel")
	if base == null:
		return
	var tex := base.duplicate() as StyleBoxTexture
	if tex == null:
		return
	tex.modulate_color = color
	add_theme_stylebox_override("panel", tex)


func _apply_mode() -> void:
	if _label == null or _icon_a == null or _icon_b == null or _glue == null:
		return
	if _mode_icons and not _icon_textures.is_empty():
		_icon_a.visible = true
		_icon_a.texture = _icon_textures[0]
		_icon_a.modulate = _INK
		var two := _icon_textures.size() >= 2
		_glue.visible = two
		_icon_b.visible = two
		_glue.text = _icon_glue
		if two:
			_icon_b.texture = _icon_textures[1]
			_icon_b.modulate = _INK
		var has_caption := not _caption.is_empty()
		_label.visible = has_caption
		if has_caption:
			_label.text = _caption
		_apply_icon_size()
		return
	_icon_a.visible = false
	_icon_b.visible = false
	_glue.visible = false
	_label.visible = true
	_label.text = text


func _apply_icon_size() -> void:
	var icon_size := Vector2(_icon_px, _icon_px)
	if _icon_a != null:
		_icon_a.custom_minimum_size = icon_size
	if _icon_b != null:
		_icon_b.custom_minimum_size = icon_size


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
