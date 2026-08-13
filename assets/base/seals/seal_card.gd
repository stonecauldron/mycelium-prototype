class_name SealCard
extends Control

signal card_pressed(seal: SealData)

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
	PaperStyles.apply_card(_panel, selected)
	var title_color := PaperStyles.CREAM if selected else PaperStyles.INK
	var body_color := PaperStyles.CREAM if selected else PaperStyles.INK_MUTED
	if _title != null:
		_title.add_theme_color_override("font_color", title_color)
	if _description != null:
		_description.add_theme_color_override("font_color", body_color)


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


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			card_pressed.emit(seal)
			get_viewport().set_input_as_handled()
