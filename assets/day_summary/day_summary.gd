extends Control

const _BASE_SCENE_PATH := "res://assets/base/base.tscn"
const _PORTRAIT_HOST_SIZE := Vector2(52, 64)
const _PORTRAIT_SCALE := 0.42

const _RANGE_COLORS := {
	WeaponData.WeaponRange.MELEE: Color(0.35, 0.75, 0.45),
	WeaponData.WeaponRange.MID: Color(0.35, 0.55, 0.9),
	WeaponData.WeaponRange.RANGED: Color(0.85, 0.65, 0.3),
}

@onready var _entries: VBoxContainer = %Entries
@onready var _continue_button: Button = %ContinueButton
@onready var _title: Label = %Title


func _ready() -> void:
	_title.text = "DAY %d / %d" % [GameState.current_day, GameState.WIN_DAYS]
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
		var range_class := int(entry.get("range_class", -1))
		if range_class >= 0:
			_entries.add_child(_make_icon_row(text, range_class))
		else:
			_entries.add_child(_make_message_row(text))


func _make_message_row(text: String) -> Control:
	var label := Label.new()
	label.theme_type_variation = &"PageSubtitleLabel"
	label.text = text
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

	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	return row


func _make_icon_row(text: String, range_class: int) -> Control:
	var row := HBoxContainer.new()

	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.color = _RANGE_COLORS.get(range_class, Color(0.7, 0.7, 0.7))
	row.add_child(icon)

	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	return row


func _on_continue_pressed() -> void:
	SceneTransition.change_scene(_BASE_SCENE_PATH)
