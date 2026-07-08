extends Camera2D

@export var fixed_y: float = 540.0


func _process(_delta: float) -> void:
	var player_army := _find_player_army()
	if player_army == null:
		return

	global_position.x = player_army.get_flag_global_position().x
	global_position.y = fixed_y


func _find_player_army() -> Army:
	for node in get_tree().get_nodes_in_group("armies"):
		var army := node as Army
		if army != null and not army.is_enemy:
			return army
	return null
