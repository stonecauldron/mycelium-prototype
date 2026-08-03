extends Camera2D

@export var fixed_y: float = 540.0
@export var max_shake_offset: float = 14.0
@export var trauma_decay: float = 2.6
@export var frame_padding: float = 280.0
@export var min_zoom: float = 0.55
@export var max_zoom: float = 1.0
@export var zoom_smooth: float = 6.0

var _trauma: float = 0.0


func _ready() -> void:
	add_to_group("battle_camera")
	# Frame army extents (player flag + furthest enemy, or flag + frontmost friend after win).
	offset = Vector2.ZERO
	zoom = Vector2(max_zoom, max_zoom)


func add_shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _physics_process(delta: float) -> void:
	# Match Camera2D process_callback = PHYSICS so follow stays in sync with
	# flag bearer movement and position smoothing.
	var player_troop := _find_troop(false)
	if player_troop == null:
		return
	var player_flag_x := player_troop.get_flag_global_position().x
	var left_x := player_flag_x
	var right_x := player_flag_x

	var enemy_troop := _find_troop(true)
	var furthest_enemy := _furthest_living_unit_from(enemy_troop, player_flag_x)
	if furthest_enemy != null:
		# Frame player banner ↔ deepest enemy (enemies no longer have a flag).
		left_x = minf(player_flag_x, furthest_enemy.global_position.x)
		right_x = maxf(player_flag_x, furthest_enemy.global_position.x)
	else:
		# Victory / no enemies: frame own banner and the furthest friend.
		var front := player_troop.get_frontmost_living_unit()
		if front != null:
			left_x = minf(player_flag_x, front.global_position.x)
			right_x = maxf(player_flag_x, front.global_position.x)

	var target_x := (left_x + right_x) * 0.5
	var target_zoom := max_zoom
	var span := right_x - left_x + frame_padding * 2.0
	var view_w := get_viewport_rect().size.x
	if view_w > 1.0 and span > 1.0:
		target_zoom = clampf(view_w / span, min_zoom, max_zoom)
	global_position.x = target_x
	global_position.y = fixed_y
	var z := lerpf(zoom.x, target_zoom, clampf(zoom_smooth * delta, 0.0, 1.0))
	zoom = Vector2(z, z)


func _furthest_living_unit_from(troop: Troop, from_x: float) -> Unit:
	if troop == null:
		return null
	var furthest: Unit = null
	var best_distance := -1.0
	for unit in troop.get_living_units():
		var distance := absf(unit.global_position.x - from_x)
		if distance > best_distance:
			best_distance = distance
			furthest = unit
	return furthest


func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
		var shake := _trauma * _trauma
		offset = Vector2(
			max_shake_offset * shake * randf_range(-1.0, 1.0),
			max_shake_offset * shake * randf_range(-1.0, 1.0) * 0.55
		)
	else:
		offset = Vector2.ZERO


func _find_troop(enemy: bool) -> Troop:
	for node in get_tree().get_nodes_in_group("troops"):
		var troop := node as Troop
		if troop != null and troop.is_enemy == enemy:
			return troop
	return null
