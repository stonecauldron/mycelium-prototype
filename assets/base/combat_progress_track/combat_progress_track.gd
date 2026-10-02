class_name CombatProgressTrack
extends Control

## Chapter track: 4 normal battles + elite skull. Signals for Scout day previews.

signal day_hovered(day: int)
signal day_unhovered
signal day_pressed(day: int)

const _SKULL_TEXTURE := preload("res://assets/base/combat_progress_track/skull.png")
const _SEAL_TEXTURE := preload("res://assets/base/seals/seal.png")

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
var _marker: Polygon2D = null
var _node_centers: Array[Vector2] = []
var _node_controls: Array[Control] = []
var _built_chapter_start: int = -1
var _hover_t: Array[float] = []  # 0..1 per node; drives animated size
var _hover_tweens: Dictionary = {}  # index -> Tween
var _focused_day: int = 0
var _keyboard_focus_visible: bool = true


func _ready() -> void:
	custom_minimum_size = Vector2(TRACK_WIDTH, TRACK_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()


func _input(event: InputEvent) -> void:
	var keyboard_focus_visible := _keyboard_focus_visible
	if event is InputEventMouse:
		keyboard_focus_visible = false
	elif (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		keyboard_focus_visible = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		keyboard_focus_visible = true
	if keyboard_focus_visible == _keyboard_focus_visible:
		return
	# Mouse clicks retain navigation focus, but must not leave a focus highlight.
	_keyboard_focus_visible = keyboard_focus_visible
	for index in _node_controls.size():
		_apply_node_hover_visual(index)
	_update_marker()
	queue_redraw()


func refresh() -> void:
	visible = GameState.is_feature_available(&"progression")
	_upcoming_day = clampi(GameState.get_upcoming_day(), 1, GameState.get_run_length())
	_chapter_start = _chapter_start_for_day(_upcoming_day)
	if _built_chapter_start != _chapter_start:
		_build_nodes()
	for i in _node_controls.size():
		var completed := _chapter_start + i <= GameState.current_day
		(_node_controls[i] as CombatProgressDayNode).set_completed(completed)
		var skull := _node_controls[i].get_node_or_null("SkullIcon") as TextureRect
		if skull != null:
			skull.visible = not completed
	_layout_nodes()
	_update_marker()
	queue_redraw()


static func _chapter_start_for_day(day: int) -> int:
	var clamped := clampi(day, 1, GameState.get_run_length())
	return floori(float(clamped - 1) / float(CHAPTER_LENGTH)) * CHAPTER_LENGTH + 1


func chapter_elite_day() -> int:
	return _chapter_start + CHAPTER_LENGTH - 1


func set_focused_day(day: int) -> void:
	_focused_day = day
	for index in _node_controls.size():
		_apply_node_hover_visual(index)
	_update_marker()
	queue_redraw()


func _build_nodes() -> void:
	_kill_hover_tweens()
	# Focus callbacks read the marker geometry; release while every old node is live.
	for node in _node_controls:
		if node.has_focus():
			node.release_focus()
	for child in get_children():
		child.free()
	_node_centers.clear()
	_node_controls.clear()
	_hover_t.clear()
	_marker = null
	_built_chapter_start = _chapter_start

	for i in NODE_COUNT:
		_hover_t.append(0.0)
		var day := _chapter_start + i
		var is_elite := i == NODE_COUNT - 1
		var node := CombatProgressDayNode.new()
		node.setup(day, is_elite)
		node.name = "Node%d" % day
		var node_size := ELITE_NODE_SIZE if is_elite else NODE_RADIUS * 2.0
		node.custom_minimum_size = Vector2(node_size, node_size)
		node.mouse_filter = Control.MOUSE_FILTER_STOP
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_child(node)
		_node_controls.append(node)
		node.pressed.connect(_on_day_pressed.bind(day))
		node.focus_entered.connect(_on_node_focus_changed.bind(i))
		node.focus_exited.connect(_on_node_focus_changed.bind(i))
		node.mouse_entered.connect(_on_node_entered.bind(i, day))
		node.mouse_exited.connect(_on_node_exited.bind(i))
		if is_elite:
			var skull := TextureRect.new()
			skull.name = "SkullIcon"
			skull.texture = _SKULL_TEXTURE
			skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			skull.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_child(skull)
		if GameState.is_seal_choice_day(day):
			var seal_icon := TextureRect.new()
			seal_icon.name = "SealIcon"
			seal_icon.texture = _SEAL_TEXTURE
			seal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			seal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			seal_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			seal_icon.size = Vector2(32, 32)
			seal_icon.position = Vector2((node_size - 32.0) * 0.5, -36.0)
			node.add_child(seal_icon)

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
	if _focused_day == _chapter_start + index or _has_visible_focus(index):
		return HOVER_SCALE
	return lerpf(1.0, HOVER_SCALE, _hover_amount(index))


func _has_visible_focus(index: int) -> bool:
	return _keyboard_focus_visible and _node_controls[index].has_focus()


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


func _on_node_focus_changed(index: int) -> void:
	_apply_node_hover_visual(index)
	_update_marker()
	queue_redraw()


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
		var center: Vector2 = _node_centers[i]
		var radius := _node_visual_radius(i)
		var selected := _focused_day == _chapter_start + i
		var focused := _has_visible_focus(i)
		if i == NODE_COUNT - 1:
			if selected:
				draw_circle(center, radius + 6.0, Color(0.467, 0.6, 0.467, 1))
			if focused:
				draw_arc(center, radius + 10.0, 0.0, TAU, 48, _FILL, 2.0, true)
			continue  # Elite uses skull.png TextureRect.
		if _chapter_start + i <= GameState.current_day:
			if selected or focused:
				var underline := Vector2(radius * 0.55, radius + 3.0)
				draw_line(center + Vector2(-underline.x, underline.y), center + underline, _FILL, 2.0, true)
			continue  # Completed days use an unnumbered gold trophy.
		draw_circle(center, radius, Color(0.68, 0.8, 0.63) if selected else _FILL)
		# Focus reuses the circle's border instead of adding a second outer ring.
		draw_arc(center, radius, 0.0, TAU, 48, _FILL if focused else _INK, 4.0, true)

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


func _on_day_pressed(day: int) -> void:
	day_pressed.emit(day)


func _on_node_entered(index: int, day: int) -> void:
	_tween_node_hover(index, true)
	day_hovered.emit(day)


func _on_node_exited(index: int) -> void:
	_tween_node_hover(index, false)
	day_unhovered.emit()


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
