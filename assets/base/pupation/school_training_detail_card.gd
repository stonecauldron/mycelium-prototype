class_name SchoolTrainingDetailCard
extends Control

const CARD_SIZE := Vector2(280, 280)
const _COLOR_UP := Color(0.12, 0.45, 0.18, 1)
const _COLOR_DOWN := Color(0.7, 0.15, 0.12, 1)

var school: int = 0

@onready var _school_icon: TextureRect = %SchoolIcon
@onready var _title_label: Label = %TitleLabel
@onready var _stats_box: VBoxContainer = %StatsBox


func setup(p_school: int) -> void:
	school = p_school
	if is_node_ready():
		reset_compact_layout()
		_refresh()
	else:
		ready.connect(_on_setup_ready, CONNECT_ONE_SHOT)


func _on_setup_ready() -> void:
	reset_compact_layout()
	_refresh()


func card_size() -> Vector2:
	return CARD_SIZE


func reset_compact_layout() -> void:
	var size_for_mode := card_size()
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	anchor_right = anchor_left
	anchor_bottom = anchor_top
	offset_left = 0.0
	offset_top = 0.0
	offset_right = size_for_mode.x
	offset_bottom = size_for_mode.y
	custom_minimum_size = size_for_mode
	size = size_for_mode
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _ready() -> void:
	_set_children_mouse_filter_ignore(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset_compact_layout()
	_refresh()


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
	var keys: Array[String] = ["strength", "dex", "con", "spd"]
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
			"spd":
				label_name = "SPD"
		var line := Label.new()
		line.text = "%+d %s" % [v, label_name]
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_font_size_override("font_size", 22)
		line.add_theme_color_override(
			"font_color",
			_COLOR_UP if v > 0 else _COLOR_DOWN
		)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stats_box.add_child(line)


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
