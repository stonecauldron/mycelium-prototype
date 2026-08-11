class_name FertilizerDetailCard
extends Control

const CARD_WIDTH := 280.0
const _FERTILIZER_ATLAS := preload("res://assets/base/nursery/fertilizers/fertiliser.png")
const _FERTILIZER_ICON_REGION := Rect2(183, 167, 169, 180)

var fertilizer: FertilizerData
var residue_text: String = ""

var _fertilizer_icon: AtlasTexture

@onready var _card_panel: PanelContainer = $CardPanel
@onready var _icon: TextureRect = %Icon
@onready var _title_label: Label = %TitleLabel
@onready var _desc_label: Label = %DescLabel
@onready var _residue_label: Label = %ResidueLabel


func setup(fert: FertilizerData, p_residue_text: String = "") -> void:
	fertilizer = fert
	residue_text = p_residue_text
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
	if fertilizer == null:
		return
	if _icon != null:
		_icon.texture = _icon_texture()
		_icon.self_modulate = fertilizer.tint
	_title_label.text = fertilizer.display_name
	var desc := fertilizer.subtitle_text()
	_desc_label.text = desc
	_desc_label.visible = not desc.is_empty()
	var residue := residue_text.strip_edges()
	_residue_label.text = residue
	_residue_label.visible = not residue.is_empty()


func _icon_texture() -> AtlasTexture:
	if _fertilizer_icon == null:
		_fertilizer_icon = AtlasTexture.new()
		_fertilizer_icon.atlas = _FERTILIZER_ATLAS
		_fertilizer_icon.region = _FERTILIZER_ICON_REGION
	return _fertilizer_icon


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
