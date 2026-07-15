class_name StockDropHost
extends PanelContainer

signal shop_spore_dropped(data: Dictionary)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return str(data.get("type", "")) == "shop_spore"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	if str(data.get("type", "")) != "shop_spore":
		return
	var spore := data.get("spore") as SporeData
	if spore == null:
		return
	shop_spore_dropped.emit(data)
