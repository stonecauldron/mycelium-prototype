extends Camera2D

@export var fixed_y: float = 540.0
@export var max_shake_offset: float = 14.0
@export var trauma_decay: float = 2.6

var _trauma: float = 0.0
var _base_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("battle_camera")
	_base_offset = offset


func add_shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _process(delta: float) -> void:
	var player_troop := _find_player_troop()
	if player_troop != null:
		global_position.x = player_troop.get_flag_global_position().x
		global_position.y = fixed_y

	if _trauma > 0.0:
		_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
		var shake := _trauma * _trauma
		offset = _base_offset + Vector2(
			max_shake_offset * shake * randf_range(-1.0, 1.0),
			max_shake_offset * shake * randf_range(-1.0, 1.0) * 0.55
		)
	else:
		offset = _base_offset


func _find_player_troop() -> Troop:
	for node in get_tree().get_nodes_in_group("troops"):
		var troop := node as Troop
		if troop != null and not troop.is_enemy:
			return troop
	return null
