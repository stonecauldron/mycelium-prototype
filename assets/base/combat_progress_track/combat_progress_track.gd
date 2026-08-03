class_name CombatProgressTrack
extends Control

## Chapter track: 4 normal battles + elite skull. Signals for scout elite preview.

signal elite_hovered(day: int)
signal elite_unhovered

const _SKULL_TEXTURE := preload("res://assets/base/combat_progress_track/skull.png")

const CHAPTER_LENGTH := 5
const NODE_COUNT := 5
const TRACK_WIDTH := 420.0
const TRACK_HEIGHT := 110.0
const NODE_RADIUS := 22.0
const ELITE_NODE_SIZE := 56.0
const HOVER_SCALE := 1.22
const HOVER_TWEEN_SEC := 0.12
const LINE_THICKNESS := 6.0
const MARKER_SIZE := Vector2(22.0, 16.0)
const _INK := Color(0.03, 0.035, 0.027, 1.0)
const _FILL := Color(0.96, 0.96, 0.94, 1.0)

var _upcoming_day: int = 1
var _chapter_start: int = 1
var _skull_control: Control = null
var _marker: Polygon2D = null
var _node_centers: Array[Vector2] = []
var _node_controls: Array[Control] = []
var _built_chapter_start: int = -1
var _hover_t: Array[float] = []  # 0..1 per node; drives animated size
var _hover_tweens: Dictionary = {}  # index -> Tween


func _ready() -> void:
	custom_minimum_size = Vector2(TRACK_WIDTH, TRACK_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()


func refresh() -> void:
	_upcoming_day = clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	_chapter_start = _chapter_start_for_day(_upcoming_day)
	if _built_chapter_start != _chapter_start:
		_build_nodes()
	_layout_nodes()
	_update_marker()
	queue_redraw()


static func _chapter_start_for_day(day: int) -> int:
	var clamped := clampi(day, 1, GameState.WIN_DAYS)
	return floori(float(clamped - 1) / float(CHAPTER_LENGTH)) * CHAPTER_LENGTH + 1


func chapter_elite_day() -> int:
	return _chapter_start + CHAPTER_LENGTH - 1


func _build_nodes() -> void:
	_kill_hover_tweens()
	for child in get_children():
		child.free()
	_node_centers.clear()
	_node_controls.clear()
	_hover_t.clear()
	_skull_control = null
	_marker = null
	_built_chapter_start = _chapter_start

	for i in NODE_COUNT:
		_hover_t.append(0.0)
		var day := _chapter_start + i
		var is_elite := i == NODE_COUNT - 1
		var node: Control
		if is_elite:
			node = Control.new()
		else:
			var day_node := CombatProgressDayNode.new()
			day_node.setup(day)
			node = day_node
		node.name = "Node%d" % day
		var node_size := ELITE_NODE_SIZE if is_elite else NODE_RADIUS * 2.0
		node.custom_minimum_size = Vector2(node_size, node_size)
		node.mouse_filter = Control.MOUSE_FILTER_STOP
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_child(node)
		_node_controls.append(node)
		node.mouse_entered.connect(_on_node_entered.bind(i, is_elite, day))
		node.mouse_exited.connect(_on_node_exited.bind(i, is_elite))
		if is_elite:
			_skull_control = node
			var skull := TextureRect.new()
			skull.name = "SkullIcon"
			skull.texture = _SKULL_TEXTURE
			skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			skull.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_child(skull)

	_marker = Polygon2D.new()
	_marker.name = "CurrentMarker"
	_marker.color = _FILL
	_marker.polygon = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(-MARKER_SIZE.x * 0.5, MARKER_SIZE.y),
		Vector2(MARKER_SIZE.x * 0.5, MARKER_SIZE.y),
	])
	add_child(_marker)


func _layout_nodes() -> void:
	if _built_chapter_start < 0:
		return
	_node_centers.clear()
	var pad_x := ELITE_NODE_SIZE * 0.5 + 8.0
	var usable := maxf(size.x - pad_x * 2.0, 1.0)
	if size.x < 1.0:
		usable = TRACK_WIDTH - pad_x * 2.0
	# Center nodes in the track so hit targets match the drawn circles/skull.
	var y := size.y * 0.5 if size.y > 1.0 else TRACK_HEIGHT * 0.5
	for i in NODE_COUNT:
		var t := 0.0 if NODE_COUNT <= 1 else float(i) / float(NODE_COUNT - 1)
		var center := Vector2(pad_x + usable * t, y)
		_node_centers.append(center)
		if i >= _node_controls.size():
			continue
		var node := _node_controls[i]
		var is_elite := i == NODE_COUNT - 1
		var half := (ELITE_NODE_SIZE if is_elite else NODE_RADIUS * 2.0) * 0.5
		node.size = Vector2(half * 2.0, half * 2.0)
		node.pivot_offset = node.size * 0.5
		node.position = center - node.pivot_offset
		_apply_node_hover_visual(i)


func _update_marker() -> void:
	if _marker == null or _node_centers.is_empty():
		return
	var index := clampi(_upcoming_day - _chapter_start, 0, NODE_COUNT - 1)
	var center: Vector2 = _node_centers[index]
	var marker_pad := _node_visual_radius(index)
	_marker.position = Vector2(center.x, center.y + marker_pad + 6.0)


func _hover_amount(index: int) -> float:
	if index < 0 or index >= _hover_t.size():
		return 0.0
	return _hover_t[index]


func _node_scale_for(index: int) -> float:
	return lerpf(1.0, HOVER_SCALE, _hover_amount(index))


func _node_visual_radius(index: int) -> float:
	var base := ELITE_NODE_SIZE * 0.5 if index == NODE_COUNT - 1 else NODE_RADIUS
	return base * _node_scale_for(index)


func _apply_node_hover_visual(index: int) -> void:
	if index < 0 or index >= _node_controls.size():
		return
	var node := _node_controls[index]
	node.pivot_offset = node.size * 0.5
	var s := _node_scale_for(index)
	node.scale = Vector2(s, s)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built_chapter_start >= 0:
		_layout_nodes()
		_update_marker()
		queue_redraw()


func _draw() -> void:
	if _node_centers.size() < 2:
		return
	var y := _node_centers[0].y
	draw_line(
		Vector2(_node_centers[0].x, y),
		Vector2(_node_centers[_node_centers.size() - 1].x, y),
		_INK,
		LINE_THICKNESS,
		true
	)

	for i in _node_centers.size():
		if i == NODE_COUNT - 1:
			continue  # Elite uses skull.png TextureRect.
		var center: Vector2 = _node_centers[i]
		var radius := _node_visual_radius(i)
		draw_circle(center, radius, _FILL)
		draw_arc(center, radius, 0.0, TAU, 48, _INK, 4.0, true)

	if not _node_centers.is_empty():
		var index := clampi(_upcoming_day - _chapter_start, 0, NODE_COUNT - 1)
		var tip: Vector2 = _node_centers[index] + Vector2(0.0, _node_visual_radius(index) + 6.0)
		var pts := PackedVector2Array([
			tip,
			tip + Vector2(-MARKER_SIZE.x * 0.5, MARKER_SIZE.y),
			tip + Vector2(MARKER_SIZE.x * 0.5, MARKER_SIZE.y),
			tip,
		])
		draw_polyline(pts, _INK, 3.0, true)


func _on_node_entered(index: int, is_elite: bool, day: int) -> void:
	_tween_node_hover(index, true)
	if is_elite:
		elite_hovered.emit(day)


func _on_node_exited(index: int, is_elite: bool) -> void:
	_tween_node_hover(index, false)
	if is_elite:
		elite_unhovered.emit()


func _tween_node_hover(index: int, hovering: bool) -> void:
	if index < 0 or index >= _hover_t.size():
		return
	if _hover_tweens.has(index):
		var prev: Tween = _hover_tweens[index]
		if prev != null and prev.is_valid():
			prev.kill()
	var target := 1.0 if hovering else 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_hover_t.bind(index), _hover_t[index], target, HOVER_TWEEN_SEC)
	_hover_tweens[index] = tween


func _set_hover_t(value: float, index: int) -> void:
	if index < 0 or index >= _hover_t.size():
		return
	_hover_t[index] = value
	_apply_node_hover_visual(index)
	_update_marker()
	queue_redraw()


func _kill_hover_tweens() -> void:
	for key in _hover_tweens.keys():
		var tween: Tween = _hover_tweens[key]
		if tween != null and tween.is_valid():
			tween.kill()
	_hover_tweens.clear()
