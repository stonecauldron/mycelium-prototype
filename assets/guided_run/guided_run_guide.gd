class_name GuidedRunGuide
extends Control

enum ArrowSide { TOP, BOTTOM, LEFT }

## One non-interactive arrow. Inspection advances presentation, never gameplay.
const _ARROW_SCENE := preload("res://assets/ui/floating_arrow/floating_arrow.tscn")
const _ARROW_SIZE := Vector2(96, 96)
const _SOURCE_SECONDS := 2.5
const _INSPECTION_SECONDS := 1.2
const _PASSIVE_SECONDS := 4.0

var resolve_target: Callable
var is_blocked: Callable
var _arrow: FloatingArrow
var _shown_key: String = ""
var _shown_seconds: float = 0.0
var _inspection_seconds: float = 0.0
var _texture_bounds: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 90
	_arrow = _ARROW_SCENE.instantiate() as FloatingArrow
	add_child(_arrow)
	_arrow.custom_minimum_size = _ARROW_SIZE
	_arrow.size = _ARROW_SIZE
	_arrow.pivot_offset = _ARROW_SIZE * 0.5


func _process(delta: float) -> void:
	if not resolve_target.is_valid() or not is_blocked.is_valid() or is_blocked.call():
		_hide_arrow()
		return
	var hint := GuidedRunHints.next_hint()
	if hint.is_empty():
		_hide_arrow()
		return
	var key := GuidedRunHints.history_key(hint)
	var source: Dictionary = hint.get("source", {})
	var source_key := _source_history_key(key, source)
	var showing_source := not source.is_empty() and not GameState.guided_hint_history.has(source_key)
	var presentation := source if showing_source else hint
	var resolved: Dictionary = resolve_target.call(presentation)
	var target := resolved.get("control") as Control
	if not _can_point_at(target):
		_hide_arrow()
		return
	var navigation := bool(resolved.get("navigation", false))
	var shown_key := source_key if showing_source else key + ":target"
	if navigation:
		shown_key += ":navigation"
	if _shown_key != shown_key:
		_shown_key = shown_key
		_shown_seconds = 0.0
		_inspection_seconds = 0.0
	var local_rect := _target_local_rect(target)
	# Cards sit directly beneath headings; use the open space below them.
	var side := ArrowSide.TOP
	var target_kind := StringName(presentation.get("target", &""))
	if not navigation and target_kind == &"shop_reroll":
		side = ArrowSide.LEFT
	elif not navigation and target_kind in [&"shop", &"stock"]:
		side = ArrowSide.BOTTOM
		# The first Shop column reserves its lower space for the unlocked reroll.
		if target_kind == &"shop" and int(presentation.get("shop_index", -1)) == 0 and GameState.is_feature_available(&"shop_reroll"):
			side = ArrowSide.LEFT
	_place_arrow(target, local_rect, side)
	var target_rect := target.get_global_transform_with_canvas() * local_rect
	var arrow_rect := _arrow.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, _arrow.size)
	if DetailTooltipPopup.obscures_rect(target_rect) or DetailTooltipPopup.obscures_rect(arrow_rect):
		_hide_arrow()
		return
	_arrow.show_arrow()
	if navigation:
		return
	_shown_seconds += delta
	if _is_inspecting(target):
		_inspection_seconds += delta
	else:
		_inspection_seconds = 0.0
	if showing_source:
		# Briefly indicate what to drag, then its destination. Native drag arrows take over.
		if _shown_seconds >= _SOURCE_SECONDS or _inspection_seconds >= _INSPECTION_SECONDS:
			GameState.guided_hint_history[source_key] = true
	elif not bool(hint.get("action_required", false)) and StringName(hint.get("target", &"")) != &"battle":
		if (_inspection_seconds >= _INSPECTION_SECONDS
				or (bool(hint.get("passive", false)) and _shown_seconds >= _PASSIVE_SECONDS)):
			GameState.guided_hint_history[key] = true


func _source_history_key(key: String, source: Dictionary) -> String:
	var location := str(source.get("target", ""))
	var unit := source.get("unit") as RosterUnitData
	if unit != null:
		location += ":%d" % unit.get_instance_id()
	else:
		location += ":%d" % int(source.get("stock_index", source.get("shop_index", -1)))
	# A bought item moves from Shop to Stock; point out its new source location too.
	return key + ":source:" + location


func _can_point_at(target: Control) -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	if not target.is_visible_in_tree() or target.modulate.a <= 0.0 or target.size == Vector2.ZERO:
		return false
	if target is BaseButton and (target as BaseButton).disabled:
		return false
	return true


func _is_inspecting(target: Control) -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	var focused := get_viewport().gui_get_focus_owner()
	return (
		(hovered != null and Rect2(Vector2.ZERO, target.size).has_point(target.get_local_mouse_position()))
		or focused == target or (focused != null and target.is_ancestor_of(focused))
	)


func _target_local_rect(target: Control) -> Rect2:
	var rect := Rect2(Vector2.ZERO, target.size)
	var icon := target as TextureRect
	if icon == null or icon.texture == null or icon.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		return rect
	var texture := icon.texture
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return rect
	if not _texture_bounds.has(texture):
		var painted := Rect2(Vector2.ZERO, texture_size)
		var image := texture.get_image()
		if image != null:
			if image.is_compressed():
				image.decompress()
			painted = Rect2(image.get_used_rect())
		_texture_bounds[texture] = painted
	var ratio := minf(target.size.x / texture_size.x, target.size.y / texture_size.y)
	var bounds: Rect2 = _texture_bounds[texture]
	return Rect2((target.size - texture_size * ratio) * 0.5 + bounds.position * ratio, bounds.size * ratio)


func _place_arrow(target: Control, local_rect: Rect2, side: ArrowSide) -> void:
	# Targets live in both the scrolling world and the fixed HUD. Convert into this canvas.
	var transform := get_global_transform_with_canvas().affine_inverse() * target.get_global_transform_with_canvas()
	var rect := transform * local_rect
	if side == ArrowSide.LEFT:
		_arrow.rotation = -PI * 0.5
		_arrow.position = Vector2(
			clampf(rect.position.x - _ARROW_SIZE.x - 8.0, 8.0, size.x - _ARROW_SIZE.x - 8.0),
			clampf(rect.get_center().y - _ARROW_SIZE.y * 0.5, 8.0, size.y - _ARROW_SIZE.y - 8.0)
		)
		return
	var center_x := clampf(rect.get_center().x, _ARROW_SIZE.x * 0.5 + 8.0, size.x - _ARROW_SIZE.x * 0.5 - 8.0)
	_arrow.rotation = 0.0
	var top := rect.position.y - _ARROW_SIZE.y - 8.0
	if top < 8.0 or side == ArrowSide.BOTTOM:
		# Top-edge controls leave more room below: point upward instead.
		_arrow.rotation = PI
		top = rect.end.y + 8.0
	_arrow.position = Vector2(center_x - _ARROW_SIZE.x * 0.5, clampf(top, 8.0, size.y - _ARROW_SIZE.y - 8.0))


func _hide_arrow() -> void:
	_arrow.hide_arrow()
	_inspection_seconds = 0.0
