class_name SealChoiceDialog
extends Control

signal seal_chosen(seal: SealData)

const _SEAL_CARD_SCENE := preload("res://assets/base/seals/seal_card.tscn")
const _OFFER_COUNT := 3
const _DIM_COLOR_RUN_START := Color(0.24705882, 0.3529412, 0.34901962, 1.0)
const _DIM_COLOR_MID_RUN := Color(0.06, 0.12, 0.07, 0.62)

var _offers: Array[SealData] = []
var _selected: SealData = null
var _cards: Dictionary = {} # SealData -> SealCard
## False on the run-start pick (starting biomass cannot cover the cost).
var _allow_reroll: bool = true

@onready var _dim: ColorRect = %Dim
@onready var _cards_row: HBoxContainer = %CardsRow
@onready var _confirm_button: Button = %ConfirmButton
@onready var _reroll_button: Button = %RerollButton
@onready var _reroll_cost_label: Label = %RerollCostLabel


func setup(offers: Array[SealData], allow_reroll: bool = true) -> void:
	_offers = offers
	_allow_reroll = allow_reroll


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_gui_input)
	_dim.color = _DIM_COLOR_MID_RUN if _allow_reroll else _DIM_COLOR_RUN_START
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_confirm_button.disabled = true
	_reroll_button.pressed.connect(_on_reroll_pressed)
	if _offers.is_empty():
		_offers = SealCatalog.roll_offers(_OFFER_COUNT, GameState.seals)
	_build_cards()
	_refresh_selection()
	_refresh_reroll_affordability()


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


func _refresh_reroll_affordability() -> void:
	if _reroll_button == null:
		return
	if _reroll_cost_label != null:
		_reroll_cost_label.text = "%d" % BiomassData.SEAL_REROLL_COST
	_reroll_button.visible = _allow_reroll
	if not _allow_reroll:
		_reroll_button.disabled = true
		return
	var can_reroll := GameState.biomass.can_afford(BiomassData.SEAL_REROLL_COST)
	_reroll_button.disabled = not can_reroll
	_reroll_button.modulate = Color.WHITE if can_reroll else Color(1, 1, 1, 0.45)


func _on_reroll_pressed() -> void:
	if not _allow_reroll:
		_refresh_reroll_affordability()
		return
	if not GameState.biomass.try_spend(BiomassData.SEAL_REROLL_COST):
		_refresh_reroll_affordability()
		return
	Analytics.biomass_sink("Seal", "Reroll", BiomassData.SEAL_REROLL_COST)
	_offers = SealCatalog.roll_offers(_OFFER_COUNT, GameState.seals, null, _offers)
	_selected = null
	_build_cards()
	_refresh_selection()
	_refresh_reroll_affordability()
	_refresh_base_hud()


func _refresh_base_hud() -> void:
	var base := get_tree().current_scene
	if base != null and base.has_method("_refresh_hud"):
		base._refresh_hud()


func _on_confirm_pressed() -> void:
	if _selected == null:
		return
	seal_chosen.emit(_selected)
	queue_free()
