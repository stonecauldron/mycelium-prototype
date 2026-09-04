class_name SchoolTrainingDetailCard
extends Control

const CARD_WIDTH := 360.0

var school: int = 0

@onready var _card_panel: PanelContainer = $CardPanel
@onready var _school_icon: TextureRect = %SchoolIcon
@onready var _title_label: Label = %TitleLabel
@onready var _children_stats: Label = %ChildrenStats
@onready var _combos_box: VBoxContainer = %CombosBox


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
	_children_stats.text = "Children: %s" % WeaponSchool.school_stat_delta_text(school).replace("  ", " · ")
	_refresh_combos()


func _refresh_combos() -> void:
	for child in _combos_box.get_children():
		_combos_box.remove_child(child)
		child.queue_free()
	for other_school in WeaponSchool.COUNT:
		var weapon := WeaponSchool.load_weapon(WeaponSchool.combo_weapon_path(school, other_school))
		var row := Label.new()
		row.text = "%s + %s → %s" % [
			WeaponSchool.display_name(school),
			WeaponSchool.display_name(other_school),
			weapon.display_name,
		]
		row.add_theme_font_size_override("font_size", 18)
		row.add_theme_color_override("font_color", StatDisplay.INK)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_combos_box.add_child(row)


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
