class_name SealChoiceDialog
extends Control

signal seal_chosen(seal: SealData)

const _SEAL_CARD_SCENE := preload("res://assets/base/seals/seal_card.tscn")

var _offers: Array[SealData] = []
var _selected: SealData = null
var _cards: Dictionary = {} # SealData -> SealCard

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
	_cards.clear()
	for seal in _offers:
		if seal == null:
			continue
		var card: SealCard = _SEAL_CARD_SCENE.instantiate()
		card.setup(seal)
		card.card_pressed.connect(_on_card_pressed)
		_cards[seal] = card
		_cards_row.add_child(card)


func _on_card_pressed(seal: SealData) -> void:
	_selected = seal
	_refresh_selection()


func _refresh_selection() -> void:
	for seal in _cards.keys():
		var card: SealCard = _cards[seal]
		if card == null:
			continue
		card.set_selected(seal == _selected)
	_confirm_button.disabled = _selected == null


func _on_confirm_pressed() -> void:
	if _selected == null:
		return
	seal_chosen.emit(_selected)
	queue_free()
