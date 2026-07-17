class_name WeaponStockDropHost
extends PanelContainer

signal shop_weapon_dropped(data: Dictionary)
signal equipped_weapon_dropped(data: Dictionary)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var drop_type := str(data.get("type", ""))
	return drop_type == "shop_weapon" or drop_type == "equipped_weapon"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var drop_type := str(data.get("type", ""))
	if drop_type == "shop_weapon":
		if data.get("weapon") as WeaponData == null:
			return
		shop_weapon_dropped.emit(data)
		return
	if drop_type == "equipped_weapon":
		if data.get("unit") as RosterUnitData == null:
			return
		equipped_weapon_dropped.emit(data)
