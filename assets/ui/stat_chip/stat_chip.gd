class_name StatChip
extends Control

const CHIP_SIZE := Vector2(32, 32)

@export var icon: Texture2D:
	set(value):
		icon = value
		if _icon != null:
			_icon.texture = value

@onready var _icon: TextureRect = %Icon
@onready var _value_label: Label = %Value


func _ready() -> void:
	custom_minimum_size = CHIP_SIZE
	size = CHIP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_children_mouse_filter_ignore(self)
	if icon != null:
		_icon.texture = icon


func set_value(value: Variant) -> void:
	_value_label.text = str(value)


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
