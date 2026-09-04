class_name CompostConfirmDialog
extends Control

signal confirmed(unit: RosterUnitData)
signal cancelled

const PORTRAIT_SCALE := 0.7
const PORTRAIT_SHADOW := 20.0
const _COMPOST_ICON := preload("res://assets/base/composting_bin/composting_bin.png")
const _COLOR_NEUTRAL := Color(0.03, 0.035, 0.027, 1)
const _COLOR_UP := Color(0.12, 0.45, 0.18, 1)

var _unit: RosterUnitData

@onready var _dim: ColorRect = %Dim
@onready var _header_icon: TextureRect = %HeaderIcon
@onready var _header_title: Label = %HeaderTitle
@onready var _close_button: Button = %CloseButton
@onready var _unit_title: Label = %UnitTitle
@onready var _left_portrait: Control = %LeftPortrait
@onready var _left_stage: Label = %LeftStage
@onready var _outcome_biomass: Label = %OutcomeBiomass
@onready var _outcome_spore: Label = %OutcomeSpore
@onready var _confirm_button: Button = %ConfirmButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_gui_input)
	_close_button.pressed.connect(_on_cancel_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_header_icon.texture = _COMPOST_ICON
	if _unit != null:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_on_cancel_pressed()
			get_viewport().set_input_as_handled()


func setup(unit: RosterUnitData) -> void:
	_unit = unit
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	if _unit == null:
		return
	_header_title.text = "Composting"
	_unit_title.text = "Compost %s" % _unit.display_name
	_clear_portrait(_left_portrait)
	_unit.mount_portrait(_left_portrait, PORTRAIT_SCALE, PORTRAIT_SHADOW)
	_left_stage.text = WeaponSchool.stage_display_name(_unit.life_stage_id)

	var preview := GameState.preview_compost_outcome(_unit)
	var biomass := int(preview.get("biomass", 0))
	var emits_spore := bool(preview.get("emits_spore", false))
	_outcome_biomass.text = "+%d kg biomass" % biomass
	_outcome_biomass.add_theme_color_override("font_color", _COLOR_UP)
	if emits_spore:
		var lineage := _unit.lineage_name.strip_edges()
		if lineage.is_empty():
			lineage = _unit.display_name.strip_edges()
		if lineage.is_empty():
			lineage = "Unit"
		_outcome_spore.text = "Emits %s's spores" % lineage
		_outcome_spore.add_theme_color_override("font_color", _COLOR_UP)
	else:
		_outcome_spore.text = "No spores"
		_outcome_spore.add_theme_color_override("font_color", _COLOR_NEUTRAL)

	_confirm_button.text = "Confirm"
	_confirm_button.icon = null
	_confirm_button.disabled = not GameState.can_compost_unit(_unit)
	_confirm_button.modulate = (
		Color.WHITE if not _confirm_button.disabled else Color(0.55, 0.55, 0.55, 1)
	)


func _clear_portrait(host: Control) -> void:
	if host == null:
		return
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_cancel_pressed()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()


func _on_confirm_pressed() -> void:
	if _unit == null:
		return
	if not GameState.can_compost_unit(_unit):
		return
	confirmed.emit(_unit)
	queue_free()
