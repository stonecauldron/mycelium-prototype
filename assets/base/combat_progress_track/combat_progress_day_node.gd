class_name CombatProgressDayNode
extends Button

## Day node on the combat progress track with a rich paper tooltip for Seal icons.

const _TOOLTIP_WIDTH := 160.0
const _SEAL_TEXTURE := preload("res://assets/base/seals/seal.png")
const _TROPHY_TEXTURE := preload("res://assets/base/combat_progress_track/trophy.svg")

var _is_elite := false
var _day_label: Label
var _trophy: TextureRect

var day: int = 1:
	set(value):
		day = value
		tooltip_text = "Day %d" % day
		if GameState.is_seal_choice_day(day):
			tooltip_text += "\nSeal choice"
		accessibility_name = "Preview Battle on %s" % tooltip_text


func setup(day_number: int, is_elite: bool = false) -> void:
	_is_elite = is_elite
	day = day_number
	if _is_elite and not GameState.is_seal_choice_day(day):
		tooltip_text = ""
	flat = true
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, empty)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	set_process_input(false)
	if not _is_elite or GameState.is_seal_choice_day(day):
		focus_entered.connect(_show_focus_tooltip)
		focus_exited.connect(_hide_focus_tooltip)
		mouse_exited.connect(_hide_focus_tooltip)
	_trophy = TextureRect.new()
	_trophy.name = "TrophyIcon"
	_trophy.texture = _TROPHY_TEXTURE
	_trophy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trophy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_trophy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_trophy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trophy.offset_left = -6.0
	_trophy.offset_top = -6.0
	_trophy.offset_right = 6.0
	_trophy.offset_bottom = 6.0
	add_child(_trophy)
	_day_label = Label.new()
	_day_label.name = "DayNumber"
	_day_label.text = str(day)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_day_label.add_theme_color_override("font_color", PaperStyles.INK)
	_day_label.add_theme_font_size_override("font_size", 24)
	_day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_day_label)
	set_completed(false)


func set_completed(completed: bool) -> void:
	_trophy.visible = completed
	_day_label.visible = not _is_elite and not completed
	var battle := "Elite Battle" if _is_elite else "Battle"
	accessibility_name = "Preview %s on Day %d%s" % [battle, day, " (completed)" if completed else ""]
	if GameState.is_seal_choice_day(day):
		accessibility_name += " · Seal choice"


func _show_focus_tooltip() -> void:
	# Mouse clicks also grant focus; let Godot own the hover tooltip's lifetime.
	if is_hovered():
		return
	var lease := DetailTooltipPopup.configure(_build_day_tooltip())
	lease.name = "FocusTooltipLease"
	add_child(lease)
	set_process_input(true)


func _input(event: InputEvent) -> void:
	# Switching back to the pointer ends a keyboard tooltip without clearing focus.
	if event is InputEventMouse:
		_hide_focus_tooltip()


func _hide_focus_tooltip() -> void:
	set_process_input(false)
	var lease := get_node_or_null("FocusTooltipLease")
	if lease != null:
		remove_child(lease)
		lease.queue_free()


func _make_custom_tooltip(_for_text: String) -> Object:
	var tip := _build_day_tooltip()
	return DetailTooltipPopup.configure(tip)


func _has_point(point: Vector2) -> bool:
	# Include the Seal artwork above the circle in this Day's hover target.
	var top := -36.0 if GameState.is_seal_choice_day(day) else 0.0
	var hit_rect := Rect2(Vector2(0, top), size - Vector2(0, top))
	if _trophy != null and _trophy.visible:
		hit_rect = hit_rect.merge(Rect2(_trophy.position, _trophy.size))
	return hit_rect.has_point(point)


func _build_day_tooltip() -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PaperStyles.apply_tooltip(panel)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = "Day %d" % day
	name_label.add_theme_color_override("font_color", PaperStyles.INK)
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(_TOOLTIP_WIDTH, 0)
	content.add_child(name_label)
	if GameState.is_seal_choice_day(day):
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		content.add_child(row)
		var seal_label := Label.new()
		seal_label.text = "Seal choice"
		seal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seal_label.add_theme_color_override("font_color", PaperStyles.INK)
		seal_label.add_theme_font_size_override("font_size", 30)
		row.add_child(seal_label)
		var seal_icon := TextureRect.new()
		seal_icon.custom_minimum_size = Vector2(36, 36)
		seal_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		seal_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seal_icon.texture = _SEAL_TEXTURE
		seal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		seal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(seal_icon)
	panel.reset_size()
	return panel
