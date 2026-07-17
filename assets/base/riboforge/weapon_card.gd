class_name WeaponCard
extends PanelContainer

const CARD_SIZE := Vector2(120, 140)
const RANGE_LABELS := {
	WeaponData.WeaponRange.MELEE: "Melee",
	WeaponData.WeaponRange.MID: "Mid",
	WeaponData.WeaponRange.RANGED: "Ranged",
}

var weapon: WeaponData
var stock_index: int = 0

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _meta_label: Label = %MetaLabel


func setup(weapon_data: WeaponData, index: int) -> void:
	weapon = weapon_data
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
	if weapon != null:
		_refresh()


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)


func _refresh() -> void:
	if weapon == null:
		return
	_name_label.text = weapon.display_name
	var range_name := str(RANGE_LABELS.get(weapon.range_class, "?"))
	_meta_label.text = "%s · dmg %d" % [range_name, weapon.base_damage]
	var icon := RiboforgeData.icon_for_weapon(weapon)
	_icon.texture = icon
	_icon.visible = icon != null



func _get_drag_data(_at_position: Vector2) -> Variant:
	if weapon == null:
		return null
	var host := Control.new()
	host.custom_minimum_size = CARD_SIZE
	host.size = CARD_SIZE
	host.clip_contents = true
	var preview := duplicate() as WeaponCard
	preview.modulate = Color(1, 1, 1, 0.85)
	preview.reset_compact_layout()
	host.add_child(preview)
	set_drag_preview(host)
	return {
		"type": "weapon",
		"stock_index": stock_index,
		"weapon": weapon,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var drop_type := str(data.get("type", ""))
	return drop_type == "shop_weapon" or drop_type == "equipped_weapon"


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var node: Node = get_parent()
	while node != null:
		if node is WeaponStockDropHost:
			(node as WeaponStockDropHost)._drop_data(at_position, data)
			return
		node = node.get_parent()
