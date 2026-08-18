class_name ArmyHpChip
extends PanelContainer

const _DEFAULT_FILL := Color(0.46769798, 0.59962183, 0.46769798, 1)

@export var title: String = "Your Troop":
	set(value):
		title = value
		_apply_title()

@export var fill_color: Color = _DEFAULT_FILL:
	set(value):
		fill_color = value
		_apply_fill()

@export var title_horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		title_horizontal_alignment = value
		_apply_title()

@onready var _title: Label = %Title
@onready var _bar: ProgressBar = %Bar
@onready var _value: Label = %Value


func _ready() -> void:
	_apply_title()
	_apply_fill()


func set_hp(current: int, maximum: int) -> void:
	if _bar == null:
		return
	var max_hp := maxi(maximum, 1)
	_bar.max_value = max_hp
	_bar.value = clampi(current, 0, max_hp)
	if _value != null:
		_value.text = "%d / %d" % [current, maximum]


func _apply_title() -> void:
	if _title == null:
		return
	_title.text = title
	_title.horizontal_alignment = title_horizontal_alignment


func _apply_fill() -> void:
	if _bar == null:
		return
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(2)
	_bar.add_theme_stylebox_override("fill", fill)
