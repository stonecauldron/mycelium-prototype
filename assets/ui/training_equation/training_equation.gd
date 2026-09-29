class_name TrainingEquation
extends HBoxContainer

const SLOT_SIZE := Vector2(64, 64)
const _ICON_SIZE := Vector2(48, 48)
const _SLOT_TEXTURE := preload("res://assets/asset_packs/Cila - Paper UI stylized/square/square border 14.png")
const _TEXT_COLOR := Color(0.2, 0.22, 0.18, 1)


func _init() -> void:
	name = "TrainingEquation"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	alignment = BoxContainer.ALIGNMENT_BEGIN


func setup(unit: RosterUnitData) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for i in range(2):
		if i > 0:
			add_child(_make_separator("+"))
		var weapon: WeaponData = null
		if unit != null and i < unit.weapon_trainings.size():
			weapon = WeaponSchool.load_weapon(WeaponSchool.base_weapon_path(unit.weapon_trainings[i]))
		var slot := _make_slot(weapon)
		slot.name = "TrainingSlot%d" % (i + 1)
		add_child(slot)
	add_child(_make_separator("="))
	var result := _make_icon(unit.weapon if unit != null else null)
	result.name = "ResultWeapon"
	add_child(result)


func _make_slot(weapon: WeaponData) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := StyleBoxTexture.new()
	paper.texture = _SLOT_TEXTURE
	paper.set_content_margin_all(8.0)
	slot.add_theme_stylebox_override("panel", paper)
	if weapon == null:
		var empty := _make_separator("Empty")
		empty.add_theme_font_size_override("font_size", 16)
		slot.add_child(empty)
	else:
		slot.add_child(_make_icon(weapon))
	return slot


func _make_icon(weapon: WeaponData) -> Control:
	if weapon == null or weapon.icon == null:
		var missing := _make_separator("—")
		missing.custom_minimum_size = _ICON_SIZE
		return missing
	var icon := TextureRect.new()
	icon.custom_minimum_size = _ICON_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = weapon.icon
	return icon


func _make_separator(symbol: String) -> Label:
	var label := Label.new()
	label.text = symbol
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", _TEXT_COLOR)
	return label
