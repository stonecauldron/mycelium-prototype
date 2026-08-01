class_name StatChip
extends Control

const CHIP_SIZE := Vector2(40, 40)
const DEFAULT_VALUE_FONT_SIZE := 24

@export var icon: Texture2D:
	set(value):
		icon = value
		if _icon != null:
			_icon.texture = value

@export var chip_size: Vector2 = CHIP_SIZE:
	set(value):
		chip_size = value
		_apply_chip_size()

@export var value_font_size: int = DEFAULT_VALUE_FONT_SIZE:
	set(value):
		value_font_size = value
		_apply_value_font_size()

@onready var _icon: TextureRect = %Icon
@onready var _value_label: Label = %Value


func _ready() -> void:
	_apply_chip_size()
	_apply_value_font_size()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_children_mouse_filter_ignore(self)
	if icon != null:
		_icon.texture = icon


func set_value(value: Variant = null) -> void:
	if value == null:
		_value_label.visible = false
		_value_label.text = ""
		return
	_value_label.visible = true
	_value_label.text = str(value)


func _apply_chip_size() -> void:
	custom_minimum_size = chip_size
	size = chip_size


func _apply_value_font_size() -> void:
	if _value_label == null:
		return
	_value_label.add_theme_font_size_override("font_size", value_font_size)


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
