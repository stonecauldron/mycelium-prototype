class_name SchoolTrainingDetailCard
extends Control

const CARD_WIDTH := 360.0
const _STAT_ROW_SCENE := preload("res://assets/ui/stat_value_row/stat_value_row.tscn")

var school: int = 0

@onready var _card_panel: PanelContainer = $CardPanel
@onready var _school_icon: TextureRect = %SchoolIcon
@onready var _title_label: Label = %TitleLabel
@onready var _stats_row: HBoxContainer = %StatsRow


func setup(p_school: int) -> void:
	school = p_school
	if is_node_ready():
		_refresh()
		fit_to_content()
	else:
		ready.connect(_on_setup_ready, CONNECT_ONE_SHOT)


func _on_setup_ready() -> void:
	_refresh()
	fit_to_content()


func card_size() -> Vector2:
	if custom_minimum_size.x > 0.0 and custom_minimum_size.y > 0.0:
		return custom_minimum_size
	if size.x > 0.0 and size.y > 0.0:
		return size
	return Vector2(CARD_WIDTH, 1.0)


func reset_compact_layout() -> void:
	fit_to_content()


func fit_to_content() -> void:
	if not is_node_ready() or _card_panel == null:
		return
	DetailCardFit.apply(self, _card_panel, CARD_WIDTH)


func _ready() -> void:
	_set_children_mouse_filter_ignore(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()
	fit_to_content()


func _refresh() -> void:
	var weapon := WeaponSchool.load_weapon(WeaponSchool.base_weapon_path(school))
	_school_icon.texture = weapon.icon if weapon != null else null
	_title_label.text = "%s Training" % WeaponSchool.display_name(school)
	_refresh_stats()


func _refresh_stats() -> void:
	for child in _stats_row.get_children():
		_stats_row.remove_child(child)
		child.queue_free()
	var deltas := WeaponSchool.school_stat_deltas(school)
	var keys: Array[String] = ["strength", "dex", "con"]
	var abbreviations: Array[String] = ["STR", "DEX", "CON"]
	for i in keys.size():
		var delta := int(deltas.get(keys[i], 0))
		if delta == 0:
			continue
		var row: StatValueRow = _STAT_ROW_SCENE.instantiate()
		_stats_row.add_child(row)
		row.configure(
			abbreviations[i], "%+d" % delta, 18,
			StatDisplay.GAIN_COLOR if delta > 0 else StatDisplay.LOSS_COLOR,
			false, StatValueRow.Layout.ICON_FIRST, StatDisplay.INK
		)


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
