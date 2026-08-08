class_name UnitDetailCard
extends Control

const CARD_WIDTH := 390.0
const PORTRAIT_HOST_HEIGHT := 200.0
const PORTRAIT_SCALE := 0.9
## Extra room under feet so the ground shadow is not clipped (UnitCard keeps default).
const PORTRAIT_SHADOW_CLEARANCE := 24.0
const _STAT_CHIP_SCENE := preload("res://assets/ui/stat_chip/stat_chip.tscn")

var unit_data: RosterUnitData
var show_portrait: bool = true
var interactive: bool = true
var _portrait_instance: Node2D = null
var _strain_chip: StatChip = null

@onready var _card_panel: PanelContainer = $CardPanel
@onready var _name_label: Label = %NameLabel
@onready var _type_label: Label = %TypeLabel
@onready var _desc_label: Label = %DescLabel
@onready var _age_label: Label = %AgeLabel
@onready var _stage_tag: TagChip = %StageTag
@onready var _tier_tag: TagChip = %TierTag
@onready var _portrait_host: Control = %PortraitHost
@onready var _atk_chip: StatChip = %AtkChip
@onready var _hp_chip: StatChip = %HpChip
@onready var _str_label: Label = %StrLabel
@onready var _dex_label: Label = %DexLabel
@onready var _con_label: Label = %ConLabel
@onready var _spd_label: Label = %SpdLabel
@onready var _fertilizer_info_label: Label = %FertilizerInfoLabel


func setup(
	unit: RosterUnitData,
	with_portrait: bool = true,
	p_interactive: bool = true
) -> void:
	unit_data = unit
	show_portrait = with_portrait
	interactive = p_interactive
	if is_node_ready():
		_apply_interaction_mode()
		_apply_portrait_visibility()
		_refresh()
		fit_to_content()
	else:
		ready.connect(_on_setup_ready, CONNECT_ONE_SHOT)


func _on_setup_ready() -> void:
	_apply_interaction_mode()
	_apply_portrait_visibility()
	_refresh()
	fit_to_content()


func card_size() -> Vector2:
	if custom_minimum_size.x > 0.0 and custom_minimum_size.y > 0.0:
		return custom_minimum_size
	if size.x > 0.0 and size.y > 0.0:
		return size
	return Vector2(CARD_WIDTH, PORTRAIT_HOST_HEIGHT)


func reset_compact_layout() -> void:
	fit_to_content()


func fit_to_content() -> void:
	if not is_node_ready() or _card_panel == null:
		return
	if _portrait_host != null:
		_portrait_host.clip_contents = false
		_portrait_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_portrait_host.custom_minimum_size = Vector2(
			0.0,
			PORTRAIT_HOST_HEIGHT if show_portrait else 0.0
		)
	DetailCardFit.apply(self, _card_panel, CARD_WIDTH)


func _ready() -> void:
	_set_children_mouse_filter_ignore(self)
	_apply_interaction_mode()
	_apply_portrait_visibility()
	if unit_data == null and get_tree().current_scene == self:
		unit_data = _make_mock_unit()
	if unit_data != null:
		_refresh()
	fit_to_content()


func _make_mock_unit() -> RosterUnitData:
	var weapon := load(RiboforgeData.SWORD_WEAPON_PATH) as WeaponData
	return RosterUnitData.create(
		"Mock Capling",
		UnitStatsData.create_for_tier(UnitStatsData.PowerTier.COMMON),
		weapon,
		null,
		UnitStatsData.PowerTier.COMMON,
	)


func _refresh() -> void:
	if unit_data == null:
		return
	_name_label.text = unit_data.display_name
	_refresh_strain_meta()
	_refresh_tags()
	if unit_data.stats != null:
		var display_stats := BroodEmpressEffect.hub_preview_stats(unit_data)
		if display_stats == null:
			display_stats = unit_data.stats
		_atk_chip.set_value(BroodEmpressEffect.hub_effective_attack(unit_data))
		_hp_chip.set_value(BroodEmpressEffect.hub_effective_max_hp(unit_data))
		_str_label.text = "STR %d" % display_stats.strength
		_dex_label.text = "DEX %d" % display_stats.dex
		_con_label.text = "CON %d" % display_stats.con
		_spd_label.text = "SPD %d" % display_stats.spd
	else:
		_atk_chip.set_value("—")
		_hp_chip.set_value("—")
		_str_label.text = "STR —"
		_dex_label.text = "DEX —"
		_con_label.text = "CON —"
		_spd_label.text = "SPD —"
	_refresh_strain_chip()
	_refresh_fertilizer_info()
	_refresh_portrait()


func _refresh_fertilizer_info() -> void:
	if _fertilizer_info_label == null:
		return
	_fertilizer_info_label.text = _fertilizer_info_text()
	_fertilizer_info_label.visible = not _fertilizer_info_label.text.is_empty()


func _fertilizer_info_text() -> String:
	if unit_data == null or unit_data.applied_fertilizers.is_empty():
		return ""
	var counts: Dictionary = {}
	var order: Array[FertilizerData] = []
	for fert in unit_data.applied_fertilizers:
		if fert == null:
			continue
		if fert.behavior == FertilizerData.Behavior.FUNGICIDE:
			continue
		var key := fert.display_name
		if not counts.has(key):
			counts[key] = 0
			order.append(fert)
		counts[key] = int(counts[key]) + 1
	var lines: PackedStringArray = []
	for fert in order:
		var count := int(counts.get(fert.display_name, 0))
		var desc := "%s (%s)" % [fert.display_name, fert.subtitle_text()]
		if count > 1:
			lines.append("%d X %s" % [count, desc])
		else:
			lines.append(desc)
	if lines.is_empty():
		return ""
	return "Fertilizers\n" + "\n".join(lines)


func _refresh_strain_chip() -> void:
	if _strain_chip != null:
		if is_instance_valid(_strain_chip):
			_strain_chip.queue_free()
		_strain_chip = null
	if unit_data == null or unit_data.strain == null or _atk_chip == null:
		return
	var info := unit_data.strain.get_stat_chip(unit_data)
	if info.is_empty():
		return
	var row := _atk_chip.get_parent() as Control
	if row == null:
		return
	var chip: StatChip = _STAT_CHIP_SCENE.instantiate()
	chip.chip_size = Vector2(72, 72)
	chip.value_font_size = 30
	chip.icon = info.get("icon") as Texture2D
	row.add_child(chip)
	chip.set_value(info.get("value", 0))
	_strain_chip = chip


func _refresh_strain_meta() -> void:
	var strain := unit_data.strain
	if strain != null:
		_type_label.text = "%s Strain" % strain.display_name
		_desc_label.text = strain.short_description
		_desc_label.visible = not strain.short_description.is_empty()
	else:
		_type_label.text = "—"
		_desc_label.text = ""
		_desc_label.visible = false
	_age_label.text = _age_text(unit_data.days_alive)


func _refresh_tags() -> void:
	if unit_data.is_adult_stage():
		_stage_tag.set_text("Adult")
	else:
		_stage_tag.set_text("Child")
	_tier_tag.set_text(UnitStatsData.label_for_tier(unit_data.power_tier))
	_tier_tag.set_fill_color(UnitStatsData.tint_for_tier(unit_data.power_tier))


func _age_text(days: int) -> String:
	if days == 1:
		return "Age: 1 day"
	return "Age: %d days" % days


func _apply_interaction_mode() -> void:
	mouse_filter = (
		Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	)


func _apply_portrait_visibility() -> void:
	if _portrait_host != null:
		_portrait_host.visible = show_portrait


func _refresh_portrait() -> void:
	if _portrait_instance != null:
		_portrait_instance.queue_free()
		_portrait_instance = null
	if not show_portrait or _portrait_host == null or unit_data == null:
		return
	_portrait_instance = unit_data.mount_portrait(
		_portrait_host,
		PORTRAIT_SCALE,
		PORTRAIT_SHADOW_CLEARANCE
	)


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
