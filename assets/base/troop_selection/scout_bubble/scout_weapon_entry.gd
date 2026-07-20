class_name ScoutWeaponEntry
extends HBoxContainer

@onready var _count_label: Label = %CountLabel
@onready var _icon: TextureRect = %Icon


func setup(count: int, weapon: WeaponData) -> void:
	if is_node_ready():
		_apply(count, weapon)
	else:
		ready.connect(_apply.bind(count, weapon), CONNECT_ONE_SHOT)


func _apply(count: int, weapon: WeaponData) -> void:
	_count_label.text = "%d ×" % count
	_icon.texture = RiboforgeData.icon_for_weapon(weapon)
