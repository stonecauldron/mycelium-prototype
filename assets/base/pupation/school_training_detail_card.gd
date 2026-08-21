class_name SchoolTrainingDetailCard
extends Control

const CARD_WIDTH := 280.0
const _STAT_ROW_SCENE := preload("res://assets/ui/stat_value_row/stat_value_row.tscn")
const _COLOR_UP := Color(0.12, 0.45, 0.18, 1)
const _COLOR_DOWN := Color(0.7, 0.15, 0.12, 1)

var school: int = 0

@onready var _card_panel: PanelContainer = $CardPanel
@onready var _school_icon: TextureRect = %SchoolIcon
@onready var _title_label: Label = %TitleLabel
@onready var _stats_box: VBoxContainer = %StatsBox


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
	_refresh_stat_lines()


func _refresh_stat_lines() -> void:
	if _stats_box == null:
		return
	for child in _stats_box.get_children():
		_stats_box.remove_child(child)
		child.queue_free()
	var deltas := WeaponSchool.school_stat_deltas(school)
	var keys: Array[String] = ["strength", "dex", "con"]
	for key in keys:
		var v := int(deltas.get(key, 0))
		if v == 0:
			continue
		var label_name := "STR"
		match key:
			"strength":
				label_name = "STR"
			"dex":
				label_name = "DEX"
			"con":
				label_name = "CON"
		var row: StatValueRow = _STAT_ROW_SCENE.instantiate()
		_stats_box.add_child(row)
		row.configure(
			label_name,
			"%+d" % v,
			22,
			_COLOR_UP if v > 0 else _COLOR_DOWN,
			false,
			StatValueRow.Layout.ICON_LAST,
			StatDisplay.INK
		)


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
