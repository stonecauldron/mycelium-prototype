class_name StarterChoiceDialog
extends Control

signal package_chosen(package_id: StringName)

const _CARD_SIZE := Vector2(280, 620)
const _PORTRAIT_SIZE := Vector2(0, 140)
const _PORTRAIT_SCALE := 0.7
const _TAG_CHIP_SCENE := preload("res://assets/ui/tag_chip/tag_chip.tscn")
const _COLOR_TEXT := Color(0.03137255, 0.03529412, 0.02745098, 1)
const _COLOR_DESC := Color(0.2, 0.22, 0.18, 1)
const _COLOR_SELECTED_BORDER := Color(0.12, 0.45, 0.18, 1)
const _TAG_FONT_SIZE := 18

var _selected_id: StringName = &""
var _card_panels: Dictionary = {} # StringName -> PanelContainer

@onready var _dim: ColorRect = %Dim
@onready var _cards_row: HBoxContainer = %CardsRow
@onready var _confirm_button: Button = %ConfirmButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_gui_input)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_confirm_button.disabled = true
	_build_cards()
	_refresh_selection()


func _unhandled_input(event: InputEvent) -> void:
	# Blocking: swallow escape so it cannot dismiss the dialog.
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()


func _build_cards() -> void:
	for child in _cards_row.get_children():
		child.queue_free()
	_card_panels.clear()
	for package_id in StarterPackages.all_ids():
		var card := _make_package_card(package_id)
		_cards_row.add_child(card)


func _make_package_card(package_id: StringName) -> Control:
	var root := Control.new()
	root.custom_minimum_size = _CARD_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_card_gui_input.bind(package_id))

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_card_style(false))
	root.add_child(panel)
	_card_panels[package_id] = panel

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = StarterPackages.display_name(package_id)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", _COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 24)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var preview_units := StarterPackages.build_units(package_id)
	var evolved: RosterUnitData = null
	var adult: RosterUnitData = null
	for unit in preview_units:
		if unit == null:
			continue
		if unit.is_fully_evolved() and evolved == null:
			evolved = unit
		elif adult == null:
			adult = unit

	# Package cards always list Evolved above Adult (squad seeding stays range-ordered).
	vbox.add_child(_make_unit_block(evolved))

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0, 0, 0, 0.18)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(divider)

	vbox.add_child(_make_unit_block(adult))
	return root


func _make_unit_block(unit: RosterUnitData) -> Control:
	var weapon: WeaponData = unit.weapon if unit != null else null
	var block := VBoxContainer.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_theme_constant_override("separation", 4)
	block.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var portrait_host := Control.new()
	portrait_host.custom_minimum_size = _PORTRAIT_SIZE
	portrait_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(portrait_host)
	if unit != null:
		unit.mount_portrait(portrait_host, _PORTRAIT_SCALE)

	var weapon_name := Label.new()
	weapon_name.text = weapon.display_name if weapon != null else "?"
	weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_name.add_theme_color_override("font_color", _COLOR_TEXT)
	weapon_name.add_theme_font_size_override("font_size", 20)
	weapon_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(weapon_name)

	var desc := Label.new()
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", _COLOR_DESC)
	desc.add_theme_font_size_override("font_size", 20)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if weapon != null and not weapon.short_description.is_empty():
		desc.text = weapon.short_description
	else:
		desc.visible = false
	block.add_child(desc)

	if weapon != null:
		block.add_child(_make_tag_row(weapon))
	return block


func _make_tag_row(weapon: WeaponData) -> Control:
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	row.add_child(_make_tag(_range_label(weapon.formation_line)))
	row.add_child(
		_make_tag(str(WeaponData.DAMAGE_STAT_LABELS.get(weapon.damage_stat, "?")))
	)
	if weapon.damage_type == WeaponData.DamageType.BLUNT:
		row.add_child(_make_tag("Blunt"))
	if weapon.targeting_mode == WeaponData.TargetingMode.AOE:
		row.add_child(_make_tag("AOE"))
	return row


func _make_tag(text: String) -> TagChip:
	var chip: TagChip = _TAG_CHIP_SCENE.instantiate()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.set_text(text)
	# Compact for package cards; default TagChip font is shop-detail sized.
	if chip.is_node_ready():
		_shrink_tag_font(chip)
	else:
		chip.ready.connect(_shrink_tag_font.bind(chip), CONNECT_ONE_SHOT)
	return chip


func _shrink_tag_font(chip: TagChip) -> void:
	var label := chip.get_node_or_null("%Label") as Label
	if label != null:
		label.add_theme_font_size_override("font_size", _TAG_FONT_SIZE)


func _range_label(formation_line: WeaponData.FormationLine) -> String:
	if formation_line == WeaponData.FormationLine.MID:
		return "Mid Range"
	return str(WeaponData.FORMATION_LINE_LABELS.get(formation_line, "?"))


func _make_card_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	style.bg_color = Color(0.92156863, 0.9098039, 0.87058824, 1)
	style.border_width_left = 5
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 8 if selected else 5
	style.border_color = _COLOR_SELECTED_BORDER if selected else Color(0, 0, 0, 1)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	return style


func _on_card_gui_input(event: InputEvent, package_id: StringName) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_selected_id = package_id
			_refresh_selection()
			get_viewport().set_input_as_handled()


func _refresh_selection() -> void:
	for package_id in _card_panels.keys():
		var panel: PanelContainer = _card_panels[package_id]
		if panel == null:
			continue
		panel.add_theme_stylebox_override(
			"panel",
			_make_card_style(package_id == _selected_id)
		)
	_confirm_button.disabled = _selected_id == &""


func _on_confirm_pressed() -> void:
	if _selected_id == &"":
		return
	package_chosen.emit(_selected_id)
	queue_free()
