class_name UnitDetailCardContent
extends VBoxContainer

const PORTRAIT_HOST_HEIGHT := 200.0
const PORTRAIT_SCALE := 0.9
## Extra room under feet so the ground shadow is not clipped (UnitCard keeps default).
const PORTRAIT_SHADOW_CLEARANCE := 24.0
const _ROW_ICON_SIZE := Vector2(36, 36)
const _STAT_CHIP_SCENE := preload("res://assets/ui/stat_chip/stat_chip.tscn")
const _FERTILIZER_ATLAS := preload("res://assets/base/nursery/fertilizers/fertiliser.png")
const _FERTILIZER_ICON_REGION := Rect2(183, 167, 169, 180)

var unit_data: RosterUnitData
var show_portrait: bool = true
var _portrait_instance: Node2D = null
var _mutation_chip: StatChip = null
var _fertilizer_icon: AtlasTexture = null

@onready var _name_label: Label = %NameLabel
@onready var _type_label: Label = %TypeLabel
@onready var _mutations_list: Control = %MutationsList
@onready var _cap_label: Label = %CapLabel
@onready var _body_label: Label = %BodyLabel
@onready var _stage_tag: TagChip = %StageTag
@onready var _tier_tag: TagChip = %TierTag
@onready var _portrait_host: Control = %PortraitHost
@onready var _atk_chip: StatChip = %AtkChip
@onready var _hp_chip: StatChip = %HpChip
@onready var _str_label: Label = %StrLabel
@onready var _dex_label: Label = %DexLabel
@onready var _con_label: Label = %ConLabel
@onready var _spd_label: Label = %SpdLabel
@onready var _fertilizers_label: Label = %FertilizersLabel
@onready var _fertilizers_list: VBoxContainer = %FertilizersList
@onready var _trainings_label: Label = %TrainingsLabel
@onready var _trainings_list: VBoxContainer = %TrainingsList


func setup(unit: RosterUnitData, with_portrait: bool = true) -> void:
	unit_data = unit
	show_portrait = with_portrait
	if is_node_ready():
		_apply_portrait_visibility()
		_refresh()
	else:
		ready.connect(_on_setup_ready, CONNECT_ONE_SHOT)


func _on_setup_ready() -> void:
	_apply_portrait_visibility()
	_refresh()


func apply_portrait_layout() -> void:
	if _portrait_host == null:
		return
	_portrait_host.clip_contents = false
	_portrait_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait_host.custom_minimum_size = Vector2(
		0.0,
		PORTRAIT_HOST_HEIGHT if show_portrait else 0.0
	)


func _ready() -> void:
	_set_children_mouse_filter_ignore(self)
	_apply_portrait_visibility()
	if unit_data == null and get_tree().current_scene == self:
		unit_data = _make_mock_unit()
	if unit_data != null:
		_refresh()


func _make_mock_unit() -> RosterUnitData:
	var weapon := load(RiboforgeData.SWORD_WEAPON_PATH) as WeaponData
	return RosterUnitData.create(
		"Mock Capling",
		UnitStatsData.create_for_tier(UnitStatsData.PowerTier.COMMON),
		weapon,
		UnitStatsData.PowerTier.COMMON,
	)


func _refresh() -> void:
	if unit_data == null:
		return
	_name_label.text = unit_data.display_name
	_refresh_mutation_meta()
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
	_refresh_mutation_chip()
	_refresh_fertilizers()
	_refresh_trainings()
	_refresh_portrait()


func _refresh_fertilizers() -> void:
	_clear_container(_fertilizers_list)
	if _fertilizers_label == null or _fertilizers_list == null:
		return
	if unit_data == null:
		_set_fertilizers_visible(false)
		return
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
	if order.is_empty():
		_set_fertilizers_visible(false)
		return
	_set_fertilizers_visible(true)
	for fert in order:
		var count := int(counts.get(fert.display_name, 0))
		var desc := "%s (%s)" % [fert.display_name, fert.subtitle_text()]
		if count > 1:
			desc = "%d X %s" % [count, desc]
		var icon := _fertilizer_row_icon()
		var row_icon := TextureRect.new()
		row_icon.custom_minimum_size = _ROW_ICON_SIZE
		row_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_icon.texture = icon
		row_icon.modulate = fert.tint
		_fertilizers_list.add_child(_make_detail_row(row_icon, desc))


func _set_fertilizers_visible(show_section: bool) -> void:
	if _fertilizers_label != null:
		_fertilizers_label.visible = show_section
	if _fertilizers_list != null:
		_fertilizers_list.visible = show_section


func _fertilizer_row_icon() -> AtlasTexture:
	if _fertilizer_icon == null:
		_fertilizer_icon = AtlasTexture.new()
		_fertilizer_icon.atlas = _FERTILIZER_ATLAS
		_fertilizer_icon.region = _FERTILIZER_ICON_REGION
	return _fertilizer_icon


func _refresh_trainings() -> void:
	_clear_container(_trainings_list)
	if _trainings_label == null or _trainings_list == null:
		return
	if unit_data == null or unit_data.enemy_unit_data != null:
		_trainings_label.visible = false
		_trainings_list.visible = false
		return
	_trainings_label.visible = true
	_trainings_list.visible = true
	_trainings_label.text = "Trainings"
	var trainings := unit_data.weapon_trainings
	if trainings.is_empty():
		var none_row := _make_detail_row(null, "None")
		none_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		_trainings_list.add_child(none_row)
		return
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var count := mini(trainings.size(), 2)
	for i in range(count):
		if i > 0:
			row.add_child(_make_training_separator())
		var school := int(trainings[i])
		var weapon := WeaponSchool.load_weapon(WeaponSchool.base_weapon_path(school))
		var icon := TextureRect.new()
		icon.custom_minimum_size = _ROW_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if weapon != null:
			icon.texture = weapon.icon
		row.add_child(icon)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color(0.2, 0.22, 0.18, 1))
		label.text = WeaponSchool.display_name(school)
		row.add_child(label)
	_trainings_list.add_child(row)


func _make_training_separator() -> Label:
	var plus := Label.new()
	plus.text = "+"
	plus.add_theme_font_size_override("font_size", 26)
	plus.add_theme_color_override("font_color", Color(0.2, 0.22, 0.18, 1))
	return plus


func _make_detail_row(icon: TextureRect, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if icon != null:
		row.add_child(icon)
	var label := Label.new()
	label.custom_minimum_size = Vector2(280, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.2, 0.22, 0.18, 1))
	label.text = text
	row.add_child(label)
	return row


func _clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()


func _refresh_mutation_chip() -> void:
	if _mutation_chip != null:
		if is_instance_valid(_mutation_chip):
			_mutation_chip.queue_free()
		_mutation_chip = null
	if unit_data == null or _atk_chip == null:
		return
	var info := unit_data.get_identity_stat_chip()
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
	_mutation_chip = chip


func _refresh_mutation_meta() -> void:
	if unit_data.enemy_unit_data != null:
		_type_label.text = unit_data.enemy_unit_data.display_name
		if _mutations_list != null:
			_mutations_list.visible = false
	else:
		_type_label.text = "Mutations"
		if _mutations_list != null:
			_mutations_list.visible = true
		_set_mutation_row_label(_cap_label, unit_data.cap_mutation)
		_set_mutation_row_label(_body_label, unit_data.body_mutation)


func _set_mutation_row_label(label: Label, mutation: MutationData) -> void:
	if label == null:
		return
	if mutation == null:
		label.text = "None"
		return
	var effect := mutation.subtitle_text()
	if effect.is_empty():
		label.text = mutation.display_name
	else:
		label.text = "%s — %s" % [mutation.display_name, effect]


func _refresh_tags() -> void:
	if unit_data.is_adult_stage():
		_stage_tag.set_text("Adult")
	else:
		_stage_tag.set_text("Child")
	var generation := maxi(unit_data.generation, 1)
	_tier_tag.set_text(UnitNames.format_generation_label(generation))
	_tier_tag.set_fill_color(UnitStatsData.tint_for_generation(generation))


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
