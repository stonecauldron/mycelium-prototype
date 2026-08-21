class_name StatIcon
extends Control

const _PUNCH_SCENE := preload("res://assets/ui/hover_punch/hover_punch.tscn")

var _abbrev: String = "STR"

@onready var _icon: TextureRect = %Icon


func _ready() -> void:
	if get_node_or_null("HoverPunch") == null:
		add_child(_PUNCH_SCENE.instantiate())
	mouse_filter = Control.MOUSE_FILTER_PASS
	_apply()


func setup(abbrev: String, icon_px: int, color: Color = StatDisplay.INK) -> void:
	_abbrev = abbrev
	custom_minimum_size = Vector2(icon_px, icon_px)
	custom_maximum_size = Vector2(icon_px, icon_px)
	modulate = color
	tooltip_text = StatDisplay.display_name(abbrev)
	if is_node_ready():
		_apply()


func _apply() -> void:
	if _icon == null:
		return
	_icon.texture = StatDisplay.white_icon(_abbrev)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.custom_minimum_size = custom_minimum_size


func _make_custom_tooltip(_for_text: String) -> Object:
	return DetailTooltipPopup.configure(StatDisplay.make_tooltip(_abbrev))
