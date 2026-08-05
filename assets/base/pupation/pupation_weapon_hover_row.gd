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
	var tip_size := tip.card_size()
	tip.custom_minimum_size = tip_size
	tip.size = tip_size
	tip.tree_entered.connect(_configure_detail_tooltip_popup.bind(tip), CONNECT_ONE_SHOT)
	return tip


func _configure_detail_tooltip_popup(tip: WeaponDetailCard) -> void:
	var node: Node = tip.get_parent()
	while node != null:
		if node is PopupPanel:
			var popup := node as PopupPanel
			popup.transparent = true
			popup.transparent_bg = true
			popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			var tip_size := tip.card_size()
			popup.size = Vector2i(ceili(tip_size.x), ceili(tip_size.y))
			return
		node = node.get_parent()
