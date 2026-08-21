class_name DetailTooltipPopup
extends CanvasLayer

## Rich detail cards are shown on a CanvasLayer overlay, not inside Godot's
## tooltip PopupPanel. `_make_custom_tooltip` must return a *visible* Control or
## Viewport memdeletes it and never tracks hover (see viewport.cpp). Call sites
## return `configure(tip)`: we show the card here and hand the engine a 1px
## dummy so it still owns delay / hide.

const _LAYER := 128
const _VIEW_MARGIN := 24.0
const _CURSOR_OFFSET := Vector2(16, 20)
const _OFFSCREEN := Vector2(-16384, -16384)
const _FADE_IN_SEC := 0.15
const _FADE_OUT_SEC := 0.12
const _MIN_OWNER_EDGE := 8.0
const _LAYOUT_STABLE_ATTEMPTS := 4

static var _instance: DetailTooltipPopup

var _host: Control
var _tip: Control
var _laid_out: bool = false
var _measured_size: Vector2 = Vector2.ZERO
var _size_stable_frames: int = 0
var _layout_attempts: int = 0
var _fade_tween: Tween


static func configure(tip: Control) -> Control:
	if tip == null or not is_instance_valid(tip):
		return _make_lease()
	var overlay := _ensure()
	overlay._present(tip)
	var lease := _make_lease()
	lease.tree_exiting.connect(_on_lease_exiting.bind(tip))
	return lease


## Re-fit a card that is already on the overlay (e.g. plot tip refresh).
static func relayout(tip: Control) -> void:
	if _instance == null or not is_instance_valid(_instance):
		return
	if _instance._tip != tip:
		return
	_instance._layout_tip(tip)
	if not _instance._laid_out:
		_instance._queue_layout(tip)


static func _make_lease() -> Control:
	var lease := Control.new()
	lease.name = "DetailTooltipLease"
	lease.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Must stay visible: Godot 4.7 skips the engine popup when the custom
	# tooltip is hidden, which also skips cancel-on-unhover.
	lease.visible = true
	lease.modulate.a = 0.0
	lease.custom_minimum_size = Vector2(1, 1)
	return lease


static func _ensure() -> DetailTooltipPopup:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var overlay := DetailTooltipPopup.new()
	overlay.name = "DetailTooltipOverlay"
	overlay.layer = _LAYER
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.root.add_child(overlay)
	_instance = overlay
	return overlay


static func _on_lease_exiting(tracked: Control) -> void:
	if _instance == null or not is_instance_valid(_instance):
		return
	if is_instance_valid(tracked) and _instance._tip == tracked:
		_instance._dismiss()


func _ready() -> void:
	layer = _LAYER
	_host = Control.new()
	_host.name = "Host"
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.clip_contents = false
	_host.propagate_maximum_size = false
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_host)


func _present(tip: Control) -> void:
	if _host == null:
		call_deferred("_present", tip)
		return
	if _tip == tip:
		_kill_fade()
	elif _tip != null and is_instance_valid(_tip):
		_kill_fade()
		_tip.queue_free()
	_laid_out = false
	_measured_size = Vector2.ZERO
	_size_stable_frames = 0
	_layout_attempts = 0
	_tip = tip
	if tip.get_parent() != _host:
		if tip.get_parent() != null:
			tip.get_parent().remove_child(tip)
		_host.add_child(tip)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.visible = true
	tip.modulate.a = 0.0
	tip.position = _OFFSCREEN
	_disable_clipping(tip)
	_layout_tip(tip)
	if not _laid_out:
		_queue_layout(tip)


func _queue_layout(tip: Control) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	var cb := _on_process_layout.bind(tip)
	if tree.process_frame.is_connected(cb):
		return
	tree.process_frame.connect(cb, CONNECT_ONE_SHOT)


func _on_process_layout(tip: Control) -> void:
	_layout_tip(tip)
	if is_instance_valid(tip) and tip == _tip and not _laid_out:
		_queue_layout(tip)


func _layout_tip(tip: Control) -> void:
	if not is_instance_valid(tip) or tip != _tip or not tip.is_inside_tree():
		return
	_disable_clipping(tip)
	_fit_tip_tree(tip)
	var tip_size := _measure_tip_size(tip)
	if tip_size.x <= 1.0 or tip_size.y <= 1.0:
		return
	if tip_size.is_equal_approx(_measured_size):
		_size_stable_frames += 1
	else:
		_size_stable_frames = 0
		_measured_size = tip_size
	tip.custom_minimum_size = tip_size
	tip.custom_maximum_size = Vector2(-1, -1)
	tip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	tip.size = tip_size
	if tip is BoxContainer:
		_layout_box_children(tip as BoxContainer, tip_size)
	var view := get_viewport().get_visible_rect()
	var max_w := maxf(64.0, view.size.x - _VIEW_MARGIN * 2.0)
	var max_h := maxf(64.0, view.size.y - _VIEW_MARGIN * 2.0)
	var fit_scale := minf(1.0, minf(max_w / tip_size.x, max_h / tip_size.y))
	tip.scale = Vector2(fit_scale, fit_scale)
	var visual := tip_size * fit_scale
	var mouse := get_viewport().get_mouse_position()
	tip.position = _placed_position(visual, mouse, view, _hover_anchor_rect(mouse, view))
	_layout_attempts += 1
	if _size_stable_frames < 1 and _layout_attempts < _LAYOUT_STABLE_ATTEMPTS:
		return
	if not _laid_out:
		_laid_out = true
		_fade_in(tip)


func _fade_in(tip: Control) -> void:
	if not is_instance_valid(tip):
		return
	_kill_fade()
	tip.modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.set_ignore_time_scale(true)
	_fade_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(tip, "modulate:a", 1.0, _FADE_IN_SEC).from(0.0)


func _dismiss() -> void:
	var tip := _tip
	_tip = null
	_laid_out = false
	_measured_size = Vector2.ZERO
	_size_stable_frames = 0
	_layout_attempts = 0
	if tip == null or not is_instance_valid(tip):
		_kill_fade()
		return
	_kill_fade()
	var from_a := tip.modulate.a
	if from_a <= 0.01:
		tip.queue_free()
		return
	var tween := tip.create_tween()
	tween.set_ignore_time_scale(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(tip, "modulate:a", 0.0, _FADE_OUT_SEC * from_a)
	tween.tween_callback(tip.queue_free)


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


## Godot Viewport::_gui_show_tooltip_at: prefer cursor + offset; if that
## overflows, flip to the opposite side of the hovered control (so the
## hover target stays visible); if that still fails, hug the view edge.
static func _placed_position(
	visual: Vector2,
	mouse: Vector2,
	view: Rect2,
	owner_rect: Rect2
) -> Vector2:
	var vr_pos := view.position + Vector2(_VIEW_MARGIN, _VIEW_MARGIN)
	var vr_end := view.position + view.size - Vector2(_VIEW_MARGIN, _VIEW_MARGIN)
	var pivot := owner_rect
	if pivot.size.x < _MIN_OWNER_EDGE or pivot.size.y < _MIN_OWNER_EDGE:
		pivot = Rect2(mouse, Vector2.ZERO)
	var pos := mouse + _CURSOR_OFFSET
	if pos.x + visual.x > vr_end.x:
		pos.x = pivot.position.x - visual.x - _CURSOR_OFFSET.x
		if pos.x < vr_pos.x:
			pos.x = vr_end.x - visual.x
	elif pos.x < vr_pos.x:
		pos.x = vr_pos.x
	if pos.y + visual.y > vr_end.y:
		pos.y = pivot.position.y - visual.y - _CURSOR_OFFSET.y
		if pos.y < vr_pos.y:
			pos.y = vr_end.y - visual.y
	elif pos.y < vr_pos.y:
		pos.y = vr_pos.y
	pos.x = clampf(pos.x, vr_pos.x, maxf(vr_pos.x, vr_end.x - visual.x))
	pos.y = clampf(pos.y, vr_pos.y, maxf(vr_pos.y, vr_end.y - visual.y))
	return pos


func _hover_anchor_rect(mouse: Vector2, view: Rect2) -> Rect2:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null or not is_instance_valid(hovered):
		return Rect2(mouse, Vector2.ZERO)
	if _host != null and (hovered == _host or _host.is_ancestor_of(hovered)):
		return Rect2(mouse, Vector2.ZERO)
	var xf := hovered.get_global_transform_with_canvas()
	var p1 := xf * Vector2.ZERO
	var p2 := xf * hovered.size
	var pos := Vector2(minf(p1.x, p2.x), minf(p1.y, p2.y))
	var rect_size := Vector2(absf(p2.x - p1.x), absf(p2.y - p1.y))
	if rect_size.x < _MIN_OWNER_EDGE or rect_size.y < _MIN_OWNER_EDGE:
		return Rect2(mouse, Vector2.ZERO)
	if rect_size.x > view.size.x * 0.5 or rect_size.y > view.size.y * 0.5:
		return Rect2(mouse, Vector2.ZERO)
	return Rect2(pos, rect_size)


func _fit_tip_tree(tip: Control) -> void:
	for child in tip.get_children():
		if child is Control:
			_fit_tip_tree(child as Control)
	if tip.has_method("fit_to_content"):
		tip.call("fit_to_content")
	elif tip is BoxContainer:
		(tip as BoxContainer).reset_size()


func _layout_box_children(box: BoxContainer, total: Vector2) -> void:
	var sep := float(box.get_theme_constant("separation"))
	var horizontal := box is HBoxContainer
	var cursor := 0.0
	for child in box.get_children():
		if not child is Control:
			continue
		var child_control := child as Control
		if not child_control.visible:
			continue
		var child_size := _control_content_size(child_control)
		child_control.custom_minimum_size = child_size
		child_control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		child_control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var rect := (
			Rect2(cursor, 0.0, child_size.x, total.y)
			if horizontal
			else Rect2(0.0, cursor, total.x, child_size.y)
		)
		box.fit_child_in_rect(child_control, rect)
		if horizontal:
			cursor += child_size.x + sep
		else:
			cursor += child_size.y + sep
	box.custom_minimum_size = total
	box.size = total


func _measure_tip_size(tip: Control) -> Vector2:
	if tip is BoxContainer:
		var box := tip as BoxContainer
		var sep := float(box.get_theme_constant("separation"))
		var total := Vector2.ZERO
		var count := 0
		var horizontal := box is HBoxContainer
		for child in box.get_children():
			if not child is Control:
				continue
			var child_control := child as Control
			if not child_control.visible:
				continue
			var child_size := _measure_tip_size(child_control)
			if horizontal:
				total.x += child_size.x
				total.y = maxf(total.y, child_size.y)
			else:
				total.x = maxf(total.x, child_size.x)
				total.y += child_size.y
			count += 1
		if count > 1:
			if horizontal:
				total.x += sep * float(count - 1)
			else:
				total.y += sep * float(count - 1)
		return total
	return _control_content_size(tip)


func _control_content_size(control: Control) -> Vector2:
	if control.has_method("card_size"):
		var card: Vector2 = control.call("card_size")
		if card.x > 1.0 and card.y > 1.0:
			return card
	var combined := control.get_combined_minimum_size()
	return Vector2(
		maxf(combined.x, control.size.x),
		maxf(combined.y, control.size.y)
	)


static func _disable_clipping(node: Node) -> void:
	if node is Control:
		var control := node as Control
		control.clip_contents = false
		control.custom_maximum_size = Vector2(-1, -1)
		control.propagate_maximum_size = false
	for child in node.get_children():
		_disable_clipping(child)
