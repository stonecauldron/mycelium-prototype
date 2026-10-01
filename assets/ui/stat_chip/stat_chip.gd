class_name StatChip
extends Control

const CHIP_SIZE := Vector2(40, 40)
const DEFAULT_VALUE_FONT_SIZE := 24

@export var icon: Texture2D:
	set(value):
		icon = value
		if _icon != null:
			_icon.texture = value

@export_range(-180.0, 180.0, 1.0) var icon_rotation_degrees: float = 0.0:
	set(value):
		icon_rotation_degrees = value
		_apply_icon_transform()

@export_range(0.5, 2.0, 0.05) var icon_scale: float = 1.0:
	set(value):
		icon_scale = value
		_apply_icon_transform()

@export var chip_size: Vector2 = CHIP_SIZE:
	set(value):
		chip_size = value
		_apply_chip_size()

@export var value_font_size: int = DEFAULT_VALUE_FONT_SIZE:
	set(value):
		value_font_size = value
		_apply_value_font_size()

## Offset from the icon center, as a fraction of chip_size.
@export var value_position_offset: Vector2 = Vector2.ZERO:
	set(value):
		value_position_offset = value
		_apply_value_position()

## Optional factory returning a Control for Godot's custom tooltip popup.
var custom_tooltip_factory: Callable

@onready var _icon: TextureRect = %Icon
@onready var _value_label: Label = %Value


func _ready() -> void:
	_icon.resized.connect(_apply_icon_transform)
	_apply_chip_size()
	_apply_icon_transform()
	_apply_value_font_size()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_children_mouse_filter_ignore(self)
	if icon != null:
		_icon.texture = icon


func _make_custom_tooltip(_for_text: String) -> Object:
	if custom_tooltip_factory.is_valid():
		return custom_tooltip_factory.call()
	return null


func set_value(value: Variant = null) -> void:
	if value == null:
		_value_label.visible = false
		_value_label.text = ""
		return
	_value_label.visible = true
	_value_label.text = str(value)


func set_value_color(color: Color) -> void:
	_value_label.add_theme_color_override("font_color", color)


func _apply_chip_size() -> void:
	custom_minimum_size = chip_size
	size = chip_size
	_apply_value_position()


func _apply_icon_transform() -> void:
	if _icon == null:
		return
	_icon.pivot_offset = _icon.size * 0.5
	_icon.rotation_degrees = icon_rotation_degrees
	_icon.scale = Vector2.ONE * icon_scale


func _apply_value_font_size() -> void:
	if _value_label == null:
		return
	_value_label.add_theme_font_size_override("font_size", value_font_size)


func _apply_value_position() -> void:
	if _value_label == null:
		return
	var offset := chip_size * value_position_offset
	_value_label.offset_left = offset.x
	_value_label.offset_right = offset.x
	_value_label.offset_top = offset.y
	_value_label.offset_bottom = offset.y


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
