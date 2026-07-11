extends Control

const _BASE_SCENE_PATH := "res://scenes/base/Base.tscn"

const _RANGE_COLORS := {
	WeaponData.WeaponRange.MELEE: Color(0.35, 0.75, 0.45),
	WeaponData.WeaponRange.MID: Color(0.35, 0.55, 0.9),
	WeaponData.WeaponRange.RANGED: Color(0.85, 0.65, 0.3),
}

@onready var _entries: VBoxContainer = %Entries
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
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
