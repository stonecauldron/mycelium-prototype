class_name SporeCard
extends PanelContainer

const CARD_SIZE := Vector2(120, 100)

var spore: SporeData
var stock_index: int = 0

@onready var _name_label: Label = %NameLabel
@onready var _days_label: Label = %DaysLabel


func setup(spore_data: SporeData, index: int) -> void:
	spore = spore_data
	stock_index = index
	if is_node_ready():
		_refresh()
	else:
		ready.connect(_refresh, CONNECT_ONE_SHOT)


func reset_compact_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	anchor_right = anchor_left
	anchor_bottom = anchor_top
	offset_left = 0.0
	offset_top = 0.0
	offset_right = CARD_SIZE.x
	offset_bottom = CARD_SIZE.y
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_children_mouse_filter_ignore(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	reset_compact_layout()
	if spore != null:
		_refresh()


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)


func _refresh() -> void:
	if spore == null:
		return
	_name_label.text = spore.display_name
	_days_label.text = "%d days" % spore.days_to_mature


func _get_drag_data(_at_position: Vector2) -> Variant:
	if spore == null:
		return null
	var host := Control.new()
	host.custom_minimum_size = CARD_SIZE
	host.size = CARD_SIZE
	host.clip_contents = true
	var preview := duplicate() as SporeCard
	preview.modulate = Color(1, 1, 1, 0.85)
	preview.reset_compact_layout()
	host.add_child(preview)
	set_drag_preview(host)
	return {
		"type": "spore",
		"stock_index": stock_index,
		"spore": spore,
	}
