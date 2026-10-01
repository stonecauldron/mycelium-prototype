class_name TrainingPreviewTooltip
extends VBoxContainer

## Passive result-only drag preview, sharing the confirmation's result calculation.
const _COMPARISON_SCENE := preload("res://assets/base/pupation/training_comparison.tscn")
const _THEME := preload("res://assets/themes/default.tres")
const _TITLE_PAPER := preload("res://assets/themes/paper/paper_dialog_title.tres")
const _TITLE_TEXTURE := preload("res://assets/asset_packs/Cila - Paper UI stylized/title/title 3 8.png")

var _unit: RosterUnitData
var _school: int
var _comparison: TrainingComparison


func setup(unit: RosterUnitData, school: int) -> void:
	_unit = unit
	_school = school


func _ready() -> void:
	theme = _THEME
	add_theme_constant_override("separation", 8)
	var header := PanelContainer.new()
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title_paper := _TITLE_PAPER.duplicate() as StyleBoxTexture
	title_paper.texture = _TITLE_TEXTURE
	header.add_theme_stylebox_override("panel", title_paper)
	add_child(header)
	var title := Label.new()
	var action := "Train" if _unit.is_adult_stage() else "Evolve"
	title.text = "%s %s · %s" % [action, _unit.display_name, WeaponSchool.display_name(_school)]
	title.custom_minimum_size.x = 320.0
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", PaperStyles.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	_comparison = _COMPARISON_SCENE.instantiate()
	_comparison.result_only = true
	_comparison.custom_minimum_size.x = 390.0
	_comparison.setup(_unit, _school)
	add_child(_comparison)
	_make_passive(self)


func _make_passive(node: Node) -> void:
	if node is Control:
		var control := node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.focus_mode = Control.FOCUS_NONE
		control.tooltip_text = ""
	for child in node.get_children():
		_make_passive(child)
