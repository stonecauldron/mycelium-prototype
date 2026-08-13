class_name SealCard
extends Control

signal card_pressed(seal: SealData)

const _COLOR_SELECTED_BORDER := Color(0.12, 0.45, 0.18, 1)

var seal: SealData

@onready var _panel: PanelContainer = %Panel
@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %TitleLabel
@onready var _description: Label = %DescriptionLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_refresh()


func setup(seal_data: SealData) -> void:
	seal = seal_data
	if is_node_ready():
		_refresh()


func set_selected(selected: bool) -> void:
	if _panel == null:
		return
	_panel.add_theme_stylebox_override("panel", _make_card_style(selected))


func _refresh() -> void:
	if _title == null:
		return
	if seal == null:
		_icon.texture = null
		_title.text = "Seal"
		_description.text = "Seal description"
		return

	_icon.texture = seal.icon
	_title.text = seal.display_name
	_description.text = seal.description
	set_selected(false)


func _make_card_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	style.bg_color = Color(0.92156863, 0.9098039, 0.87058824, 1)
	style.border_width_left = 5
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 8 if selected else 5
	style.border_color = _COLOR_SELECTED_BORDER if selected else Color(0, 0, 0, 1)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	return style


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			card_pressed.emit(seal)
			get_viewport().set_input_as_handled()
