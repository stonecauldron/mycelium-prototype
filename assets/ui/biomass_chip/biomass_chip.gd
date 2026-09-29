class_name BiomassChip
extends Control

const _PREVIEW_SCALE := 1.18
const _TWEEN_SECONDS := 0.14

@onready var _amount: Label = %BiomassAmount
@onready var _delta: Label = %BiomassDelta
@onready var _context: Label = %PreviewContext
## The wrapper keeps container layout from resetting the paper's animated scale.
@onready var _paper: PanelContainer = $Paper

var _previewing: bool = false
var _last_amount: int = -1
var _last_preview: Dictionary = {}
var _scale_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ignore_mouse(self)
	GameState.biomass.changed.connect(refresh)
	refresh()


func _process(_dt: float) -> void:
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	var preview: Dictionary = {}
	if is_visible_in_tree() and not get_tree().paused and not SceneTransition.is_transitioning():
		preview = BiomassPreview.for_hovered(get_viewport().gui_get_hovered_control())
	var balance := GameState.biomass.amount
	if balance == _last_amount and preview == _last_preview:
		return
	_last_amount = balance
	_last_preview = preview
	var active := not preview.is_empty()
	var change := int(preview.get("delta", 0))
	_amount.text = BiomassDisplay.number(balance + change)
	_amount.add_theme_color_override("font_color", StatDisplay.change_color(change, true))
	_delta.text = BiomassDisplay.number(change, true) if change != 0 else ""
	_delta.add_theme_color_override("font_color", StatDisplay.change_color(change))
	_delta.get_parent().visible = active and change != 0
	_context.text = str(preview.get("context", ""))
	_context.visible = not _context.text.is_empty()
	# Keep this input-ignoring readout visible above Base modal dimmers.
	z_index = 102 if active else 0
	if active != _previewing:
		_previewing = active
		if _scale_tween != null and _scale_tween.is_valid():
			_scale_tween.kill()
		_scale_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_scale_tween.tween_property(_paper, "scale", Vector2.ONE * (_PREVIEW_SCALE if active else 1.0), _TWEEN_SECONDS)


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
