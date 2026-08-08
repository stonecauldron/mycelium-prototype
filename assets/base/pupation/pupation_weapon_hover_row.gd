class_name PupationWeaponHoverRow
extends HBoxContainer

## Weapon icon+name row with WeaponDetailCard tooltip (used in pupation confirm).

const _WEAPON_DETAIL_CARD_SCENE := preload("res://assets/base/weapon_detail_card/weapon_detail_card.tscn")

var weapon: WeaponData = null


func set_weapon(data: WeaponData) -> void:
	weapon = data
	# Non-empty text enables the tooltip popup; content comes from _make_custom_tooltip.
	tooltip_text = data.display_name if data != null else ""


func _make_custom_tooltip(_for_text: String) -> Object:
	if weapon == null:
		return null
	var tip: WeaponDetailCard = _WEAPON_DETAIL_CARD_SCENE.instantiate()
	tip.setup(weapon, false)
	DetailTooltipPopup.configure(tip)
	return tip
