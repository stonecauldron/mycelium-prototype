class_name PupationConfirmDialog
extends Control

signal confirmed(unit: RosterUnitData, school: int)
signal cancelled

const _BIOMASS_ICON := preload("res://assets/base/biomass_small_icon.png")

var _unit: RosterUnitData
var _school: int = 0
var _confirmation_sent := false

@onready var _dim: ColorRect = %Dim
@onready var _school_icon: TextureRect = %SchoolIcon
@onready var _header_title: Label = %HeaderTitle
@onready var _close_button: Button = %CloseButton
@onready var _pupate_title: Label = %PupateTitle
@onready var _comparison: TrainingComparison = %ComparePanel
@onready var _confirm_button: Button = %ConfirmButton


func _ready() -> void:
	GameState.biomass.changed.connect(_refresh_affordability)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_gui_input)
	_close_button.pressed.connect(_on_cancel_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	BiomassPreview.bind(_confirm_button, _biomass_preview_delta)
	_confirm_button.icon = _BIOMASS_ICON
	_confirm_button.expand_icon = true
	_confirm_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_confirm_button.add_theme_constant_override("icon_max_width", 24)
	if _unit != null:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_on_cancel_pressed()
			get_viewport().set_input_as_handled()


func setup(unit: RosterUnitData, school: int) -> void:
	_unit = unit
	_school = school
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	if _unit == null:
		return
	var school_weapon := WeaponSchool.load_weapon(WeaponSchool.base_weapon_path(_school))
	_school_icon.texture = school_weapon.icon if school_weapon != null else null
	_header_title.text = "%s Training" % WeaponSchool.display_name(_school)
	_pupate_title.text = "%s %s" % [_action_verb(), _unit.display_name]
	_comparison.setup(_unit, _school)
	_refresh_affordability()


func _action_verb() -> String:
	return "Train" if _unit == null or _unit.is_adult_stage() else "Evolve"


func _biomass_preview_delta() -> Variant:
	if not GameState.can_cocoon_for_pupation(_unit, _school):
		return null
	return -WeaponSchool.COCOON_COST


func _refresh_affordability() -> void:
	var can_afford := GameState.biomass.can_afford(WeaponSchool.COCOON_COST)
	var unchanged := WeaponSchool.is_unchanged_training(_unit, _school)
	_confirm_button.text = (
		"No changes" if unchanged
		else "%s %s" % [_action_verb(), BiomassDisplay.number(WeaponSchool.COCOON_COST)]
	)
	_confirm_button.icon = null if unchanged else _BIOMASS_ICON
	_confirm_button.disabled = unchanged or not can_afford
	if unchanged:
		_confirm_button.modulate = Color.WHITE
		_confirm_button.add_theme_color_override("font_disabled_color", _confirm_button.get_theme_color("font_color"))
	else:
		_confirm_button.remove_theme_color_override("font_disabled_color")
		_confirm_button.modulate = Color.WHITE if can_afford else Color(0.55, 0.55, 0.55, 1)


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_cancel_pressed()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()


func _on_confirm_pressed() -> void:
	if _confirmation_sent:
		return
	if not GameState.can_cocoon_for_pupation(_unit, _school):
		return
	if not GameState.biomass.can_afford(WeaponSchool.COCOON_COST):
		return
	_confirmation_sent = true
	_confirm_button.disabled = true
	confirmed.emit(_unit, _school)
	queue_free()
