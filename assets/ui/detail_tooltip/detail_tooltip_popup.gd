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

static var _instance: DetailTooltipPopup

var _host: Control
var _tip: Control
var _laid_out: bool = false
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
	for child in tip.get_children():
		if child is Control and (child as Control).has_method("fit_to_content"):
			(child as Control).call("fit_to_content")
	if tip.has_method("fit_to_content"):
		tip.call("fit_to_content")
	else:
		tip.reset_size()
	var tip_size := tip.get_combined_minimum_size()
	tip_size.x = maxf(tip_size.x, tip.size.x)
	tip_size.y = maxf(tip_size.y, tip.size.y)
	if tip_size.x <= 0.0 or tip_size.y <= 0.0:
		return
	tip.custom_minimum_size = tip_size
	tip.custom_maximum_size = Vector2(-1, -1)
	tip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	tip.size = tip_size
	var vp := get_viewport().get_visible_rect().size
	var max_w := maxf(64.0, vp.x - _VIEW_MARGIN * 2.0)
	var max_h := maxf(64.0, vp.y - _VIEW_MARGIN * 2.0)
	var fit_scale := minf(1.0, minf(max_w / tip_size.x, max_h / tip_size.y))
	tip.scale = Vector2(fit_scale, fit_scale)
	var visual := tip_size * fit_scale
	var pos := get_viewport().get_mouse_position() + _CURSOR_OFFSET
	pos.x = clampf(pos.x, _VIEW_MARGIN, vp.x - _VIEW_MARGIN - visual.x)
	pos.y = clampf(pos.y, _VIEW_MARGIN, vp.y - _VIEW_MARGIN - visual.y)
	tip.position = pos
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


static func _disable_clipping(node: Node) -> void:
	if node is Control:
		var control := node as Control
		control.clip_contents = false
		control.custom_maximum_size = Vector2(-1, -1)
		control.propagate_maximum_size = false
	for child in node.get_children():
		_disable_clipping(child)
