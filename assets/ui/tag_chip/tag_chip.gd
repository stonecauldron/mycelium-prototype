class_name TagChip
extends PanelContainer

@export var text: String = "":
	set(value):
		text = value
		if _label != null:
			_label.text = value

@onready var _label: Label = %Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_children_mouse_filter_ignore(self)
	if _label != null:
		_label.text = text


func set_text(value: String) -> void:
	text = value


func set_fill_color(color: Color) -> void:
	var base := get_theme_stylebox("panel")
	if base == null:
		return
	var tex := base.duplicate() as StyleBoxTexture
	if tex == null:
		return
	tex.modulate_color = color
	add_theme_stylebox_override("panel", tex)


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
