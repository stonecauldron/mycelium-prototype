class_name PaperStyles
extends RefCounted

## Shared Paper Style 2 boxes for runtime swaps (selected cards, tooltips).
## Scene panels assign these StyleBoxes on the node so they can be edited
## in the inspector (Make Unique to diverge).

const PANEL: StyleBoxTexture = preload("res://assets/themes/paper/paper_panel.tres")
const CARD: StyleBoxTexture = preload("res://assets/themes/paper/paper_card.tres")
const CARD_SELECTED: StyleBoxTexture = preload("res://assets/themes/paper/paper_card_selected.tres")
const DIALOG: StyleBoxTexture = preload("res://assets/themes/paper/paper_dialog.tres")
const HUD: StyleBoxTexture = preload("res://assets/themes/paper/paper_hud.tres")
const CHIP: StyleBoxTexture = preload("res://assets/themes/paper/paper_chip.tres")

const INK := Color(0.18, 0.16, 0.14, 1)
const INK_MUTED := Color(0.32, 0.3, 0.26, 1)
const CREAM := Color(0.94, 0.94, 0.88, 1)


static func apply_card(panel: PanelContainer, selected: bool = false) -> void:
	panel.add_theme_stylebox_override("panel", CARD_SELECTED if selected else CARD)


static func apply_tooltip(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", CARD)
