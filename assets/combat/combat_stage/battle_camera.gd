extends Camera2D

@export var fixed_y: float = 540.0


func _process(_delta: float) -> void:
	var player_troop := _find_player_troop()
	if player_troop == null:
		return

	global_position.x = player_troop.get_flag_global_position().x
	global_position.y = fixed_y


func _find_player_troop() -> Troop:
	for node in get_tree().get_nodes_in_group("troops"):
		var troop := node as Troop
		if troop != null and not troop.is_enemy:
			return troop
	return null
