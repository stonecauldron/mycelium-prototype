class_name StarterPackageCard
extends Control

signal card_pressed(package_id: StringName)

const _TAG_CHIP_SCENE := preload("res://assets/ui/tag_chip/tag_chip.tscn")
const _PORTRAIT_SCALE := 0.7
const _COLOR_TEXT := Color(0.03137255, 0.03529412, 0.02745098, 1)
const _COLOR_DESC := Color(0.2, 0.22, 0.18, 1)
const _TAG_FONT_SIZE := 18

var package_id: StringName = &""
var _idle_panel_style: StyleBox
var _description_source: String = ""

@onready var _panel: PanelContainer = %Panel
@onready var _title: Label = %TitleLabel
@onready var _portrait_host: Control = %PortraitHost
@onready var _weapon_name: Label = %WeaponNameLabel
@onready var _description: RichTextLabel = %DescriptionLabel
@onready var _tag_row: HFlowContainer = %TagRow


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_children_mouse_filter_ignore(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_cache_idle_panel_style()
	_refresh()


func _cache_idle_panel_style() -> void:
	if _panel == null:
		return
	_idle_panel_style = _panel.get_theme_stylebox("panel")


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)


func _has_point(point: Vector2) -> bool:
	var hit := Rect2(Vector2.ZERO, size)
	var panel := _panel
	if panel == null:
		panel = get_node_or_null("%Panel") as PanelContainer
	if panel != null:
		var box := panel.get_theme_stylebox("panel")
		if box != null:
			hit.position = Vector2(-box.expand_margin_left, -box.expand_margin_top)
			hit.size = size + Vector2(
				box.expand_margin_left + box.expand_margin_right,
				box.expand_margin_top + box.expand_margin_bottom
			)
	return hit.has_point(point)


func setup(p_package_id: StringName) -> void:
	package_id = p_package_id
	if is_node_ready():
		_refresh()


func set_selected(selected: bool) -> void:
	if _panel == null:
		return
	if selected:
		PaperStyles.apply_card(_panel, true)
	elif _idle_panel_style != null:
		_panel.add_theme_stylebox_override("panel", _idle_panel_style)
	var title_color := PaperStyles.CREAM if selected else _COLOR_TEXT
	var body_color := PaperStyles.CREAM if selected else _COLOR_DESC
	if _title != null:
		_title.add_theme_color_override("font_color", title_color)
	if _weapon_name != null:
		_weapon_name.add_theme_color_override("font_color", title_color)
	_apply_description(body_color)


func _refresh() -> void:
	if _title == null:
		return
	if package_id == &"":
		_title.text = "Starter"
		_weapon_name.text = "Weapon"
		_description_source = "Weapon description"
		_apply_description(_COLOR_DESC)
		_description.visible = true
		_clear_tags()
		return

	_title.text = StarterPackages.display_name(package_id)
	var unit := StarterPackages.preview_unit(package_id)
	_populate_unit(unit)
	set_selected(false)


func _populate_unit(unit: RosterUnitData) -> void:
	for child in _portrait_host.get_children():
		child.queue_free()
	_clear_tags()

	var weapon: WeaponData = unit.weapon if unit != null else null
	if unit != null:
		unit.mount_portrait(_portrait_host, _PORTRAIT_SCALE)

	_weapon_name.text = weapon.display_name if weapon != null else "?"
	if weapon != null and not weapon.short_description.is_empty():
		_description_source = weapon.short_description
		_apply_description(_COLOR_DESC)
		_description.visible = true
	else:
		_description_source = ""
		_description.visible = false

	if weapon != null:
		_tag_row.add_child(_make_tag(_range_label(weapon.formation_line)))
		_tag_row.add_child(_make_stat_tag(weapon.damage_stat))
		if weapon.damage_type == WeaponData.DamageType.BLUNT:
			_tag_row.add_child(_make_tag("Blunt"))
		if weapon.targeting_mode == WeaponData.TargetingMode.AOE:
			_tag_row.add_child(_make_tag("AOE"))


func _clear_tags() -> void:
	for child in _tag_row.get_children():
		child.queue_free()


func _make_tag(text: String) -> TagChip:
	var chip: TagChip = _TAG_CHIP_SCENE.instantiate()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.set_text(text)
	if chip.is_node_ready():
		chip.set_content_font_size(_TAG_FONT_SIZE)
	else:
		chip.ready.connect(chip.set_content_font_size.bind(_TAG_FONT_SIZE), CONNECT_ONE_SHOT)
	return chip


func _make_stat_tag(damage_stat: int) -> TagChip:
	var chip: TagChip = _TAG_CHIP_SCENE.instantiate()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.show_icons(
		StatDisplay.textures_for_damage_stat(damage_stat),
		"or",
		_TAG_FONT_SIZE,
		"Scaling"
	)
	if chip.is_node_ready():
		chip.set_content_font_size(_TAG_FONT_SIZE)
	else:
		chip.ready.connect(chip.set_content_font_size.bind(_TAG_FONT_SIZE), CONNECT_ONE_SHOT)
	return chip


func _apply_description(color: Color) -> void:
	if _description == null:
		return
	var icon_color := (
		PaperStyles.CREAM if color.is_equal_approx(PaperStyles.CREAM) else StatDisplay.INK
	)
	StatDisplay.apply_to(_description, _description_source, 20, color, icon_color)


func _range_label(formation_line: WeaponData.FormationLine) -> String:
	if formation_line == WeaponData.FormationLine.MID:
		return "Mid Range"
	return str(WeaponData.FORMATION_LINE_LABELS.get(formation_line, "?"))


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			card_pressed.emit(package_id)
			get_viewport().set_input_as_handled()
