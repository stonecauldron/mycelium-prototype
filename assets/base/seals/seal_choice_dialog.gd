class_name SealChoiceDialog
extends Control

signal seal_chosen(seal: SealData)

const _CARD_SIZE := Vector2(260, 420)
const _ICON_SIZE := Vector2(96, 96)
const _COLOR_TEXT := Color(0.03137255, 0.03529412, 0.02745098, 1)
const _COLOR_DESC := Color(0.2, 0.22, 0.18, 1)
const _COLOR_SELECTED_BORDER := Color(0.12, 0.45, 0.18, 1)

var _offers: Array[SealData] = []
var _selected: SealData = null
var _card_panels: Dictionary = {} # SealData -> PanelContainer

@onready var _dim: ColorRect = %Dim
@onready var _cards_row: HBoxContainer = %CardsRow
@onready var _confirm_button: Button = %ConfirmButton


func setup(offers: Array[SealData]) -> void:
	_offers = offers


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_gui_input)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_confirm_button.disabled = true
	if _offers.is_empty():
		_offers = SealCatalog.roll_offers(3, GameState.seals)
	_build_cards()
	_refresh_selection()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()


func _build_cards() -> void:
	for child in _cards_row.get_children():
		child.queue_free()
	_card_panels.clear()
	for seal in _offers:
		if seal == null:
			continue
		_cards_row.add_child(_make_seal_card(seal))


func _make_seal_card(seal: SealData) -> Control:
	var root := Control.new()
	root.custom_minimum_size = _CARD_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_card_gui_input.bind(seal))

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_card_style(false))
	root.add_child(panel)
	_card_panels[seal] = panel

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = _ICON_SIZE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = seal.icon
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)

	var title := Label.new()
	title.text = seal.display_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", _COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 26)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = seal.description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", _COLOR_DESC)
	desc.add_theme_font_size_override("font_size", 20)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)
	return root


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


func _on_card_gui_input(event: InputEvent, seal: SealData) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_selected = seal
			_refresh_selection()
			get_viewport().set_input_as_handled()


func _refresh_selection() -> void:
	for seal in _card_panels.keys():
		var panel: PanelContainer = _card_panels[seal]
		if panel == null:
			continue
		panel.add_theme_stylebox_override("panel", _make_card_style(seal == _selected))
	_confirm_button.disabled = _selected == null


func _on_confirm_pressed() -> void:
	if _selected == null:
		return
	seal_chosen.emit(_selected)
	queue_free()
