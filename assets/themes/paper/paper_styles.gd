class_name PaperStyles
extends RefCounted

## Runtime paper boxes for selected cards and tooltips. Detail-card and
## tooltip panels use the `DetailTooltipPanel` theme type variation.

const _TEX_CARD: Texture2D = preload(
	"res://assets/asset_packs/Cila - Paper UI stylized/Paper style 2/paper 1 01.png"
)
const _TEX_CARD_SELECTED: Texture2D = preload(
	"res://assets/asset_packs/Cila - Paper UI stylized/Paper style 2/paper 1 32.png"
)
const _TOOLTIP_PANEL: StyleBox = preload("res://assets/themes/paper/paper_tooltip_panel.tres")

const INK := Color(0.18, 0.16, 0.14, 1)
const INK_MUTED := Color(0.32, 0.3, 0.26, 1)
const CREAM := Color(0.94, 0.94, 0.88, 1)

static var _card: StyleBoxTexture
static var _card_selected: StyleBoxTexture


static func apply_card(panel: PanelContainer, selected: bool = false) -> void:
	panel.add_theme_stylebox_override("panel", _selected_box() if selected else _card_box())


static func apply_tooltip(panel: PanelContainer) -> void:
	panel.clip_contents = false
	panel.theme_type_variation = &"DetailTooltipPanel"
	panel.add_theme_stylebox_override("panel", _TOOLTIP_PANEL)


static func _card_box() -> StyleBoxTexture:
	if _card == null:
		_card = _make_card_box(_TEX_CARD)
	return _card


static func _selected_box() -> StyleBoxTexture:
	if _card_selected == null:
		_card_selected = _make_card_box(_TEX_CARD_SELECTED)
	return _card_selected


static func _make_card_box(tex: Texture2D) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.content_margin_left = 16.0
	box.content_margin_top = 14.0
	box.content_margin_right = 18.0
	box.content_margin_bottom = 20.0
	box.texture_margin_left = 40.0
	box.texture_margin_top = 40.0
	box.texture_margin_right = 48.0
	box.texture_margin_bottom = 48.0
	return box
