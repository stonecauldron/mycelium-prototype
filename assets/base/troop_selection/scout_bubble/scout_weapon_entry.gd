class_name ScoutWeaponEntry
extends HBoxContainer

const _WEAPON_DETAIL_CARD_SCENE := preload("res://assets/base/weapon_detail_card/weapon_detail_card.tscn")

@onready var _count_label: Label = %CountLabel
@onready var _icon: TextureRect = %Icon

var _weapon: WeaponData = null


func setup(count: int, weapon: WeaponData) -> void:
	if is_node_ready():
		_apply(count, weapon)
	else:
		ready.connect(_apply.bind(count, weapon), CONNECT_ONE_SHOT)


func _apply(count: int, weapon: WeaponData) -> void:
	_weapon = weapon
	_count_label.text = "%d ×" % count
	_icon.texture = weapon.icon if weapon != null else null
	# Non-empty text enables the tooltip popup; content comes from _make_custom_tooltip.
	tooltip_text = weapon.display_name if weapon != null else ""


func _make_custom_tooltip(_for_text: String) -> Object:
	if _weapon == null:
		return null
	var tip: WeaponDetailCard = _WEAPON_DETAIL_CARD_SCENE.instantiate()
	tip.setup(_weapon, false)
	return DetailTooltipPopup.configure(tip)
