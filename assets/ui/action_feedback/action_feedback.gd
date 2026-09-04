extends CanvasLayer

## Screen-fixed presentation and drag-session coordination for expected rule rejections.

enum PresentationMode { DRAG_MESSAGE, ANCHORED_MESSAGE, GLOBAL_MESSAGE }

const _LAYER := 120
const _HOVER_DELAY_MSEC := 300
const _DISPLAY_SEC := 1.75
const _FADE_SEC := 0.16
const _NUDGE_COOLDOWN_MSEC := 400
const _VIEW_MARGIN := 24.0
const _ANCHOR_GAP := 10.0
const _INK := Color(0.18, 0.16, 0.14, 1.0)
const _WARNING := Color(0.55, 0.16, 0.12, 1.0)
const _COPY_BY_REASON := {
	ActionReasons.UNIT_CANNOT_TRAIN: "This unit cannot be trained.",
	ActionReasons.MUTATION_CAPACITY_FULL: "Mutation capacity full",
	ActionReasons.FERTILIZER_CAPACITY_FULL: "Fertilizer capacity full.",
	ActionReasons.NOT_ENOUGH_BIOMASS: "Not enough Biomass.",
}

var _host: Control
var _tag: PanelContainer
var _symbol: Label
var _message: Label
var _anchor: Control
var _candidate_anchor: Control
var _candidate_decision: ActionDecision
var _candidate_started_msec: int = 0
var _previewing_drag: bool = false
var _global_positioning: bool = false
var _last_nudge_msec: int = -_NUDGE_COOLDOWN_MSEC
var _fade_tween: Tween
var _nudge_tween: Tween
var _warned_unmapped_reasons: Dictionary = {}


func _ready() -> void:
	layer = _LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _candidate_decision != null:
		if not _candidate_is_valid():
			_clear_drag_candidate(true)
		elif now - _candidate_started_msec >= _HOVER_DELAY_MSEC:
			_present(_candidate_anchor, _candidate_decision, PresentationMode.DRAG_MESSAGE)
	if _tag.visible:
		if _global_positioning:
			_position_tag()
		elif not is_instance_valid(_anchor) or not _anchor.is_inside_tree():
			dismiss()
		else:
			_position_tag()


func preview_rejection(anchor: Control, decision: ActionDecision) -> void:
	if not is_instance_valid(anchor) or not _is_rejection(decision):
		clear_drag_preview()
		return
	DetailTooltipPopup.set_suppressed(true)
	var now := Time.get_ticks_msec()
	var changed := _candidate_anchor != anchor or _candidate_decision == null
	if not changed:
		changed = _candidate_decision.reason != decision.reason
	_candidate_anchor = anchor
	_candidate_decision = decision
	if changed:
		_candidate_started_msec = now
		_hide_until_drag_reason()


func clear_drag_preview() -> void:
	_clear_drag_candidate(true)


func show_rejection(anchor: Control, decision: ActionDecision) -> void:
	if not is_instance_valid(anchor) or not _is_rejection(decision):
		return
	_clear_drag_candidate(false)
	_present(anchor, decision, PresentationMode.ANCHORED_MESSAGE)


func show_global_rejection(decision: ActionDecision) -> void:
	if not _is_rejection(decision):
		return
	_clear_drag_candidate(false)
	_present(null, decision, PresentationMode.GLOBAL_MESSAGE)


func dismiss() -> void:
	_clear_drag_candidate(false)
	DetailTooltipPopup.set_suppressed(false)
	_kill_fade()
	_kill_nudge()
	_anchor = null
	_previewing_drag = false
	_global_positioning = false
	if _tag != null:
		_tag.visible = false
		_tag.modulate.a = 1.0
		_tag.rotation_degrees = 0.0


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END:
		return
	var viewport := get_viewport()
	var successful := viewport != null and viewport.gui_is_drag_successful()
	if successful or _candidate_decision == null:
		_clear_drag_candidate(true)
		return
	if not _candidate_is_valid():
		_clear_drag_candidate(true)
		return
	var anchor := _candidate_anchor
	var decision := _candidate_decision
	_clear_drag_candidate(false)
	show_rejection(anchor, decision)


func _build_ui() -> void:
	_host = Control.new()
	_host.name = "Host"
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_host)

	_tag = PanelContainer.new()
	_tag.name = "RejectionTag"
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.visible = false
	_tag.z_index = 1
	PaperStyles.apply_tooltip(_tag)
	_host.add_child(_tag)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	_tag.add_child(row)

	_symbol = Label.new()
	_symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_symbol.text = "×"
	_symbol.add_theme_font_size_override("font_size", 25)
	_symbol.add_theme_color_override("font_color", _WARNING)
	row.add_child(_symbol)

	_message = Label.new()
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.add_theme_font_size_override("font_size", 20)
	_message.add_theme_color_override("font_color", _INK)
	row.add_child(_message)


func _present(
	anchor: Control,
	decision: ActionDecision,
	mode: PresentationMode
) -> void:
	var global := mode == PresentationMode.GLOBAL_MESSAGE
	if not _is_rejection(decision) or (not global and not is_instance_valid(anchor)):
		return
	var drag_preview := mode == PresentationMode.DRAG_MESSAGE
	var nudge := mode == PresentationMode.ANCHORED_MESSAGE or global
	_anchor = anchor
	_previewing_drag = drag_preview
	_global_positioning = global
	_message.text = _copy_for(decision.reason)
	_message.visible = true
	_tag.visible = true
	_tag.modulate.a = 1.0
	_tag.reset_size()
	_tag.size = _tag.get_combined_minimum_size()
	_tag.pivot_offset = _tag.size * 0.5
	_position_tag()
	if drag_preview:
		_kill_fade()
	else:
		_start_fade_timer()
	if nudge:
		_play_nudge()


func _copy_for(reason: StringName) -> String:
	if _COPY_BY_REASON.has(reason):
		return str(_COPY_BY_REASON[reason])
	if not _warned_unmapped_reasons.has(reason):
		_warned_unmapped_reasons[reason] = true
		push_error("ActionFeedback has no copy for rejection reason: %s" % reason)
	return "Action unavailable"


func _position_tag() -> void:
	if _tag == null or not _tag.visible:
		return
	if not _global_positioning and not is_instance_valid(_anchor):
		return
	_tag.reset_size()
	_tag.size = _tag.get_combined_minimum_size()
	_tag.pivot_offset = _tag.size * 0.5
	var view := get_viewport().get_visible_rect()
	if _global_positioning:
		_tag.position = Vector2(
			view.position.x + (view.size.x - _tag.size.x) * 0.5,
			view.end.y - _tag.size.y - 72.0
		)
		return
	var anchor_rect := _screen_rect(_anchor)
	var centered_x := anchor_rect.position.x + (anchor_rect.size.x - _tag.size.x) * 0.5
	var above_y := anchor_rect.position.y - _tag.size.y - _ANCHOR_GAP
	var below_y := anchor_rect.end.y + _ANCHOR_GAP
	var y := above_y if above_y >= view.position.y + _VIEW_MARGIN else below_y
	var min_pos := view.position + Vector2(_VIEW_MARGIN, _VIEW_MARGIN)
	var max_pos := view.end - _tag.size - Vector2(_VIEW_MARGIN, _VIEW_MARGIN)
	_tag.position = Vector2(
		clampf(centered_x, min_pos.x, maxf(min_pos.x, max_pos.x)),
		clampf(y, min_pos.y, maxf(min_pos.y, max_pos.y))
	)


func _screen_rect(control: Control) -> Rect2:
	var canvas_transform := control.get_global_transform_with_canvas()
	var top_left := canvas_transform * Vector2.ZERO
	var bottom_right := canvas_transform * control.size
	var position := Vector2(minf(top_left.x, bottom_right.x), minf(top_left.y, bottom_right.y))
	return Rect2(position, (bottom_right - top_left).abs())


func _start_fade_timer() -> void:
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.set_ignore_time_scale(true)
	_fade_tween.tween_interval(_DISPLAY_SEC)
	_fade_tween.tween_property(_tag, "modulate:a", 0.0, _FADE_SEC)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_fade_tween.tween_callback(_finish_fade)


func _finish_fade() -> void:
	_fade_tween = null
	_anchor = null
	_previewing_drag = false
	_global_positioning = false
	_tag.visible = false
	_tag.modulate.a = 1.0


func _play_nudge() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_nudge_msec < _NUDGE_COOLDOWN_MSEC:
		return
	_last_nudge_msec = now
	_kill_nudge()
	_tag.rotation_degrees = 0.0
	_nudge_tween = create_tween()
	_nudge_tween.set_ignore_time_scale(true)
	_nudge_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_nudge_tween.tween_property(_tag, "rotation_degrees", -2.5, 0.045)
	_nudge_tween.tween_property(_tag, "rotation_degrees", 2.0, 0.07)
	_nudge_tween.tween_property(_tag, "rotation_degrees", -0.8, 0.055)
	_nudge_tween.tween_property(_tag, "rotation_degrees", 0.0, 0.045)


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _kill_nudge() -> void:
	if _nudge_tween != null and _nudge_tween.is_valid():
		_nudge_tween.kill()
	_nudge_tween = null


func _hide_until_drag_reason() -> void:
	_kill_fade()
	_anchor = null
	_previewing_drag = true
	_global_positioning = false
	if _tag != null:
		_tag.visible = false
		_tag.modulate.a = 1.0


func _is_rejection(decision: ActionDecision) -> bool:
	return (
		decision != null
		and not decision.allowed
		and not decision.reason.is_empty()
	)


func _candidate_is_valid() -> bool:
	return (
		_candidate_decision != null
		and is_instance_valid(_candidate_anchor)
		and _candidate_anchor.is_inside_tree()
	)


func _clear_drag_candidate(hide_preview: bool) -> void:
	_candidate_anchor = null
	_candidate_decision = null
	_candidate_started_msec = 0
	DetailTooltipPopup.set_suppressed(false)
	if hide_preview and _previewing_drag:
		_anchor = null
		_previewing_drag = false
		_global_positioning = false
		_kill_fade()
		if _tag != null:
			_tag.visible = false
			_tag.modulate.a = 1.0
