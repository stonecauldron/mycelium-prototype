class_name StarterChoiceDialog
extends Control

signal package_chosen(package_id: StringName)

const _STARTER_CARD_SCENE := preload("res://assets/base/troop_selection/starter_package_card.tscn")

var _selected_id: StringName = &""
var _cards: Dictionary = {} # StringName -> StarterPackageCard

@onready var _dim: ColorRect = %Dim
@onready var _cards_row: HBoxContainer = %CardsRow
@onready var _confirm_button: Button = %ConfirmButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_gui_input)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_confirm_button.disabled = true
	_build_cards()
	_refresh_selection()


func _unhandled_input(event: InputEvent) -> void:
	# Blocking: swallow escape so it cannot dismiss the dialog.
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
	for package_id in StarterPackages.all_ids():
		var card: StarterPackageCard = _STARTER_CARD_SCENE.instantiate()
		card.setup(package_id)
		card.card_pressed.connect(_on_card_pressed)
		_cards[package_id] = card
		_cards_row.add_child(card)


func _on_card_pressed(package_id: StringName) -> void:
	_selected_id = package_id
	_refresh_selection()


func _refresh_selection() -> void:
	for package_id in _cards.keys():
		var card: StarterPackageCard = _cards[package_id]
		if card == null:
			continue
		card.set_selected(package_id == _selected_id)
	_confirm_button.disabled = _selected_id == &""


func _on_confirm_pressed() -> void:
	if _selected_id == &"":
		return
	package_chosen.emit(_selected_id)
	queue_free()
