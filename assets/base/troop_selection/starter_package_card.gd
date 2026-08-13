class_name StarterPackageCard
extends Control

signal card_pressed(package_id: StringName)

const _TAG_CHIP_SCENE := preload("res://assets/ui/tag_chip/tag_chip.tscn")
const _PORTRAIT_SCALE := 0.7
const _COLOR_TEXT := Color(0.03137255, 0.03529412, 0.02745098, 1)
const _COLOR_DESC := Color(0.2, 0.22, 0.18, 1)
const _TAG_FONT_SIZE := 18

var package_id: StringName = &""

@onready var _panel: PanelContainer = %Panel
@onready var _title: Label = %TitleLabel
@onready var _portrait_host: Control = %PortraitHost
@onready var _weapon_name: Label = %WeaponNameLabel
@onready var _description: Label = %DescriptionLabel
@onready var _tag_row: HFlowContainer = %TagRow


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_refresh()


func setup(p_package_id: StringName) -> void:
	package_id = p_package_id
	if is_node_ready():
		_refresh()


func set_selected(selected: bool) -> void:
	if _panel == null:
		return
	PaperStyles.apply_card(_panel, selected)


func _refresh() -> void:
	if _title == null:
		return
	if package_id == &"":
		_title.text = "Starter"
		_weapon_name.text = "Weapon"
		_description.text = "Weapon description"
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
		_description.text = weapon.short_description
		_description.visible = true
	else:
		_description.visible = false

	if weapon != null:
		_tag_row.add_child(_make_tag(_range_label(weapon.formation_line)))
		_tag_row.add_child(
			_make_tag(str(WeaponData.DAMAGE_STAT_LABELS.get(weapon.damage_stat, "?")))
		)
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


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			card_pressed.emit(package_id)
			get_viewport().set_input_as_handled()
