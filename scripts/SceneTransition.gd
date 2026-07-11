extends CanvasLayer

const FADE_DURATION := 0.4
const FADE_COLOR := Color(0.04, 0.04, 0.05, 1.0)

var _overlay: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.name = "FadeOverlay"
	_overlay.color = Color(FADE_COLOR, 0.0)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	await _fade_to(1.0)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0)

	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _fade_to(target_alpha: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_overlay, "color:a", target_alpha, FADE_DURATION).set_ease(
		Tween.EASE_IN_OUT
	).set_trans(Tween.TRANS_SINE)
	await tween.finished
