class_name MutationDetailCard
extends Control

const CARD_WIDTH := 280.0
const _MUTATION_ICON := preload("res://assets/base/nursery/mutations/mutation_icon.png")
const _BODY_MUTATION_ICON := preload("res://assets/base/nursery/mutations/body_mutation_icon.png")
const _CAP_MUTATION_ICON := preload("res://assets/base/nursery/mutations/cap_mutation_icon.png")
const _EMPTY_ICON_MODULATE := Color(1, 1, 1, 0.4)
const _EMPTY_TITLE := "Empty Mutation slot"
const _EMPTY_DESC := "Drag and drop a mutation from the shop"

var mutation: MutationData
var _empty_slot: bool = false

@onready var _card_panel: PanelContainer = $CardPanel
@onready var _icon: TextureRect = %Icon
@onready var _slot_row: Control = %SlotRow
@onready var _slot_icon: TextureRect = %SlotIcon
@onready var _slot_label: Label = %SlotLabel
@onready var _title_label: Label = %TitleLabel
@onready var _desc_label: Label = %DescLabel


func setup(mutation_data: MutationData) -> void:
	mutation = mutation_data
	_empty_slot = false
	if is_node_ready():
		_refresh()
		fit_to_content()
	else:
		ready.connect(_on_setup_ready, CONNECT_ONE_SHOT)


func setup_empty() -> void:
	mutation = null
	_empty_slot = true
	if is_node_ready():
		_refresh()
		fit_to_content()
	else:
		ready.connect(_on_setup_ready, CONNECT_ONE_SHOT)


func _on_setup_ready() -> void:
	_refresh()
	fit_to_content()


func card_size() -> Vector2:
	if custom_minimum_size.x > 0.0 and custom_minimum_size.y > 0.0:
		return custom_minimum_size
	if size.x > 0.0 and size.y > 0.0:
		return size
	return Vector2(CARD_WIDTH, 1.0)


func reset_compact_layout() -> void:
	fit_to_content()


func fit_to_content() -> void:
	if not is_node_ready() or _card_panel == null:
		return
	DetailCardFit.apply(self, _card_panel, CARD_WIDTH)


func _ready() -> void:
	_set_children_mouse_filter_ignore(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()
	fit_to_content()


func _refresh() -> void:
	if _empty_slot:
		_refresh_empty()
		return
	if mutation == null:
		return
	if _icon != null:
		_icon.texture = _MUTATION_ICON
		_icon.self_modulate = mutation.tint
	if _slot_row != null:
		_slot_row.visible = true
	if _slot_icon != null:
		_slot_icon.texture = (
			_BODY_MUTATION_ICON if mutation.is_body() else _CAP_MUTATION_ICON
		)
	_slot_label.text = mutation.slot_label()
	_title_label.text = mutation.display_name
	var desc := mutation.subtitle_text()
	_desc_label.text = desc
	_desc_label.visible = not desc.is_empty()


func _refresh_empty() -> void:
	if _icon != null:
		_icon.texture = _MUTATION_ICON
		_icon.self_modulate = _EMPTY_ICON_MODULATE
	if _slot_row != null:
		_slot_row.visible = false
	_title_label.text = _EMPTY_TITLE
	_desc_label.text = _EMPTY_DESC
	_desc_label.visible = true


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
