extends Control

const _BASE_SCENE_PATH := "res://assets/base/base.tscn"
const _PORTRAIT_HOST_SIZE := Vector2(68, 84)
const _PORTRAIT_SCALE := 0.54
const _BIOMASS_ICON := preload("res://assets/base/biomass.png")
const _BIOMASS_ICON_SIZE := Vector2(96, 96)
const _PLOT_EMPTY := preload("res://assets/base/plot_tile/plot_empty.png")
const _EGG0 := preload("res://assets/base/plot_tile/egg0.png")
const _EGG1 := preload("res://assets/base/plot_tile/egg1.png")
const _PLOT_ICON_SIZE := Vector2(84, 96)

const _FORMATION_COLORS := {
	WeaponData.FormationLine.FRONT: Color(0.35, 0.75, 0.45),
	WeaponData.FormationLine.MID: Color(0.35, 0.55, 0.9),
	WeaponData.FormationLine.BACK: Color(0.85, 0.65, 0.3),
}

@onready var _entries: VBoxContainer = %Entries
@onready var _continue_button: Button = %ContinueButton
@onready var _title: Label = %Title


func _ready() -> void:
	_title.text = "Day %d => Day %d" % [GameState.current_day, GameState.current_day + 1]
	_populate_entries(DaySummaryFeed.take_entries())
	_continue_button.pressed.connect(_on_continue_pressed)
	_continue_button.grab_focus()


func _populate_entries(entries: Array[Dictionary]) -> void:
	for child in _entries.get_children():
		child.queue_free()

	if entries.is_empty():
		_entries.add_child(_make_message_row("Nothing notable happened today."))
		return

	for entry in entries:
		var text := str(entry.get("text", ""))
		var unit := entry.get("unit") as RosterUnitData
		if unit != null:
			_entries.add_child(_make_unit_row(text, unit))
			continue
		if bool(entry.get("biomass", false)):
			_entries.add_child(_make_biomass_row(text))
			continue
		if bool(entry.get("nursery_ready", false)):
			_entries.add_child(_make_nursery_row(
				text,
				entry.get("tint", Color.WHITE) as Color,
				bool(entry.get("as_imago", false))
			))
			continue
		var formation_line := int(entry.get("formation_line", -1))
		if formation_line >= 0:
			_entries.add_child(_make_icon_row(text, formation_line))
		else:
			_entries.add_child(_make_message_row(text))


func _make_message_row(text: String) -> Control:
	return _make_entry_label(text)


func _make_entry_label(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"SummaryEntryLabel"
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _make_unit_row(text: String, unit: RosterUnitData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var host := Control.new()
	host.custom_minimum_size = _PORTRAIT_HOST_SIZE
	host.size = _PORTRAIT_HOST_SIZE
	host.clip_contents = true
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(host)
	unit.mount_portrait(host, _PORTRAIT_SCALE)
	row.add_child(_make_entry_label(text))

	return row


func _make_biomass_row(text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var icon := TextureRect.new()
	icon.custom_minimum_size = _BIOMASS_ICON_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture = _BIOMASS_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	row.add_child(_make_entry_label(text))

	return row


func _make_nursery_row(text: String, tint: Color, as_imago: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var host := Control.new()
	host.custom_minimum_size = _PLOT_ICON_SIZE
	host.size = _PLOT_ICON_SIZE
	host.clip_contents = true
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var bed := TextureRect.new()
	bed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bed.texture = _PLOT_EMPTY
	bed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bed.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.add_child(bed)

	var egg := TextureRect.new()
	egg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	egg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	egg.texture = _EGG1 if as_imago else _EGG0
	egg.modulate = tint
	egg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	egg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.add_child(egg)

	row.add_child(host)
	row.add_child(_make_entry_label(text))
	return row


func _make_icon_row(text: String, formation_line: int) -> Control:
	var row := HBoxContainer.new()

	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.color = _FORMATION_COLORS.get(formation_line, Color(0.7, 0.7, 0.7))
	row.add_child(icon)
	row.add_child(_make_entry_label(text))

	return row


func _on_continue_pressed() -> void:
	SceneTransition.change_scene(_BASE_SCENE_PATH)
