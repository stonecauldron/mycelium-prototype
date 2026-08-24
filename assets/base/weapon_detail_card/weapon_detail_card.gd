class_name WeaponDetailCard
extends Control

const CARD_WIDTH := 320.0

var weapon_data: WeaponData
var interactive: bool = true

@onready var _card_panel: PanelContainer = $CardPanel
@onready var _name_label: Label = %NameLabel
@onready var _desc_label: RichTextLabel = %DescLabel
@onready var _dmg_label: Label = %DmgLabel
@onready var _speed_label: Label = %SpeedLabel
@onready var _range_tag: TagChip = %RangeTag
@onready var _scaling_tag: TagChip = %ScalingTag
@onready var _blunt_tag: TagChip = %BluntTag
@onready var _aoe_tag: TagChip = %AoeTag
@onready var _sell_row: HBoxContainer = %SellRow
@onready var _footer_spacer: Control = $CardPanel/Margin/VBox/FooterSpacer


func setup(weapon: WeaponData, p_interactive: bool = true) -> void:
	weapon_data = weapon
	interactive = p_interactive
	if is_node_ready():
		_apply_interaction_mode()
		_refresh()
		fit_to_content()
	else:
		ready.connect(_on_setup_ready, CONNECT_ONE_SHOT)


func _on_setup_ready() -> void:
	_apply_interaction_mode()
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
	if _footer_spacer != null:
		# Spacer was for fixed-height cards; content-fit tips should hug rows.
		_footer_spacer.visible = false
		_footer_spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	DetailCardFit.apply(self, _card_panel, CARD_WIDTH)


func _ready() -> void:
	_set_children_mouse_filter_ignore(self)
	_apply_interaction_mode()
	if weapon_data == null and get_tree().current_scene == self:
		weapon_data = WeaponSchool.sword()
	if weapon_data != null:
		_refresh()
	fit_to_content()


func _refresh() -> void:
	if weapon_data == null:
		return
	_name_label.text = weapon_data.display_name
	StatDisplay.apply_to(
		_desc_label,
		weapon_data.short_description,
		24,
		StatDisplay.INK_MUTED
	)
	_desc_label.visible = not weapon_data.short_description.is_empty()
	_dmg_label.text = "DMG %d" % weapon_data.base_damage
	_speed_label.text = "Attacks every %s secs" % str(weapon_data.attack_interval)
	_range_tag.set_text(_range_label(weapon_data.formation_line))
	_scaling_tag.show_icons(
		StatDisplay.textures_for_damage_stat(weapon_data.damage_stat),
		"or",
		22,
		"Scaling"
	)
	_blunt_tag.visible = weapon_data.damage_type == WeaponData.DamageType.BLUNT
	if _blunt_tag.visible:
		_blunt_tag.set_text("Blunt")
	_aoe_tag.visible = weapon_data.targeting_mode == WeaponData.TargetingMode.AOE
	if _aoe_tag.visible:
		_aoe_tag.set_text("AOE")
	if _sell_row != null:
		_sell_row.visible = false
		var footer := _sell_row.get_parent() as Control
		if footer != null:
			footer.visible = false


func _range_label(formation_line: WeaponData.FormationLine) -> String:
	if formation_line == WeaponData.FormationLine.MID:
		return "Mid Range"
	return str(WeaponData.FORMATION_LINE_LABELS.get(formation_line, "?"))


func _apply_interaction_mode() -> void:
	mouse_filter = (
		Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	)


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
