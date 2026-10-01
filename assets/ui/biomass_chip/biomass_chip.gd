class_name BiomassChip
extends Control

const _PREVIEW_SCALE := 1.18
const _TWEEN_SECONDS := 0.14

@onready var _amount: Label = %BiomassAmount
@onready var _delta: Label = %BiomassDelta
@onready var _context: Label = %PreviewContext
## The wrapper keeps container layout from resetting the paper's animated scale.
@onready var _paper: PanelContainer = $Paper
@onready var _amount_row: HBoxContainer = $Paper/BiomassChip/InfoFrame/InfoVBox/AmountRow

var _previewing: bool = false
var _last_amount: int = -1
var _last_preview: Dictionary = {}
var _scale_tween: Tween
var _gain_serial := 0
var _gain_total := 0
var _gain_received := 0
var _gain_balance := 0
var _gain_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ignore_mouse(self)
	GameState.biomass.changed.connect(refresh)
	refresh()


func _process(_dt: float) -> void:
	refresh()


func refresh() -> void:
	if not is_node_ready() or not is_inside_tree():
		return
	var balance := GameState.biomass.amount
	if _gain_total > 0:
		# Another transaction supersedes the cosmetic replay immediately.
		if balance != _gain_balance or get_tree().paused or not is_visible_in_tree():
			end_gain(_gain_serial)
		else:
			_amount.text = BiomassDisplay.number(maxi(0, balance - _gain_total + _gain_received))
			_amount.add_theme_color_override("font_color", Color("f1d980"))
			_delta.get_parent().hide()
			_context.hide()
			z_index = 102
			return
	var preview: Dictionary = {}
	if is_visible_in_tree() and not get_tree().paused and not SceneTransition.is_transitioning():
		preview = BiomassPreview.for_hovered(get_viewport().gui_get_hovered_control())
	if balance == _last_amount and preview == _last_preview:
		return
	_last_amount = balance
	_last_preview = preview
	var active := not preview.is_empty()
	var change := int(preview.get("delta", 0))
	var unaffordable := active and change < 0 and balance + change < 0
	_amount.text = BiomassDisplay.number(balance if unaffordable else balance + change)
	_amount.add_theme_color_override("font_color", StatDisplay.change_color(change, true))
	_delta.text = "Not enough\nbiomass" if unaffordable else (BiomassDisplay.number(change, true) if change != 0 else "")
	_delta.add_theme_color_override("font_color", StatDisplay.change_color(change))
	_delta.add_theme_constant_override("outline_size", 0 if unaffordable else 3)
	_delta.get_parent().visible = active and change != 0
	_context.text = "" if unaffordable else str(preview.get("context", ""))
	_context.visible = not _context.text.is_empty()
	# The wrapper is not a Container, so shrink the paper when taller text clears.
	_paper.set_anchors_and_offsets_preset.call_deferred(Control.PRESET_FULL_RECT)
	# Keep this input-ignoring readout visible above Base modal dimmers.
	z_index = 102 if active else 0
	if active != _previewing:
		_previewing = active
		if _scale_tween != null and _scale_tween.is_valid():
			_scale_tween.kill()
		_scale_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_scale_tween.tween_property(_paper, "scale", Vector2.ONE * (_PREVIEW_SCALE if active else 1.0), _TWEEN_SECONDS)


## Display an already credited award. This never changes the spendable balance.
func begin_gain(amount: int) -> int:
	end_gain(_gain_serial)
	_gain_serial += 1
	_gain_total = clampi(amount, 0, GameState.biomass.amount)
	_gain_received = 0
	_gain_balance = GameState.biomass.amount
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	if _gain_tween != null and _gain_tween.is_valid():
		_gain_tween.kill()
	_previewing = false
	_paper.scale = Vector2.ONE
	_amount_row.scale = Vector2.ONE
	refresh()
	return _gain_serial


func is_gain_active(token: int) -> bool:
	return token == _gain_serial and _gain_total > 0


func receive_gain(token: int, received: int) -> void:
	if not is_gain_active(token):
		return
	_gain_received = clampi(received, _gain_received, _gain_total)
	refresh()
	if not is_gain_active(token):
		return
	var progress := float(_gain_received) / float(_gain_total)
	if _gain_tween != null and _gain_tween.is_valid():
		_gain_tween.kill()
	_paper.pivot_offset = _paper.size * 0.5
	_amount_row.pivot_offset = _amount_row.size * 0.5
	_paper.scale = Vector2.ONE * (1.08 + progress * 0.06)
	_amount_row.scale = Vector2.ONE * (1.08 + progress * 0.18)
	_gain_tween = create_tween().set_parallel(true)
	_gain_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_gain_tween.tween_property(_paper, "scale", Vector2.ONE * (1.0 + progress * 0.06), 0.16)
	_gain_tween.tween_property(_amount_row, "scale", Vector2.ONE * (1.0 + progress * 0.18), 0.16)


func end_gain(token: int) -> void:
	if token != _gain_serial or _gain_total <= 0:
		return
	_gain_total = 0
	_gain_received = 0
	_last_amount = -1
	if _gain_tween != null and _gain_tween.is_valid():
		_gain_tween.kill()
	_paper.scale = Vector2.ONE
	_amount_row.scale = Vector2.ONE
	refresh()


func gain_target_canvas_position() -> Vector2:
	var icon := $Paper/BiomassChip/InfoFrame/InfoVBox/AmountRow/Icon as Control
	return icon.get_global_transform_with_canvas() * (icon.size * 0.5)


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
