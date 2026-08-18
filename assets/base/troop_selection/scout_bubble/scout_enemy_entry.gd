class_name ScoutEnemyEntry
extends HBoxContainer

## Enemy art is shorter above the feet origin than player portraits.
const _PORTRAIT_SCALE := 0.6
## Raise feet above the host bottom so the body lines up with the count label.
const _PORTRAIT_Y_FACTOR := 0.82
const _TOOLTIP_WIDTH := 260.0
const _CHIP_SIZE := Vector2(40, 40)
const _CHIP_FONT_SIZE := 24

const _STAT_CHIP_SCENE: PackedScene = preload("res://assets/ui/stat_chip/stat_chip.tscn")
const _TAG_CHIP_SCENE: PackedScene = preload("res://assets/ui/tag_chip/tag_chip.tscn")
const _SWORD_ICON: Texture2D = preload("res://assets/base/unit_card/sword_icon.png")
const _HP_ICON: Texture2D = preload("res://assets/base/unit_card/hp_icon.png")

@onready var _count_label: Label = %CountLabel
@onready var _portrait_host: Control = %PortraitHost

var _portrait_instance: Node2D = null
var _unit_data: EnemyUnitData = null


func setup(count: int, unit_data: EnemyUnitData) -> void:
	if is_node_ready():
		_apply(count, unit_data)
	else:
		ready.connect(_apply.bind(count, unit_data), CONNECT_ONE_SHOT)


func _apply(count: int, unit_data: EnemyUnitData) -> void:
	_unit_data = unit_data
	_count_label.text = "%d ×" % count
	if _portrait_instance != null:
		_portrait_instance.queue_free()
		_portrait_instance = null
	if unit_data == null or _portrait_host == null:
		tooltip_text = ""
		return
	var data := RosterUnitData.create_enemy(
		unit_data.display_name,
		null,
		unit_data
	)
	_portrait_host.set_meta("_portrait_y_factor", _PORTRAIT_Y_FACTOR)
	_portrait_instance = data.mount_portrait(_portrait_host, _PORTRAIT_SCALE)
	if _portrait_instance != null:
		# Face left like combat enemies; keep feet-anchored portrait sync.
		_portrait_instance.scale.x = -absf(_portrait_instance.scale.x)
		RosterUnitData._sync_portrait_in_host(_portrait_host)
	tooltip_text = unit_data.display_name


func _make_custom_tooltip(_for_text: String) -> Object:
	if _unit_data == null:
		return null
	var tip := _build_enemy_tooltip(_unit_data)
	return DetailTooltipPopup.configure(tip)


func _build_enemy_tooltip(unit_data: EnemyUnitData) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PaperStyles.apply_tooltip(panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = unit_data.display_name
	name_label.add_theme_color_override("font_color", PaperStyles.INK)
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(_TOOLTIP_WIDTH, 0)
	vbox.add_child(name_label)

	var combat := unit_data.get_combat_profile()
	var atk: int = combat.base_damage
	if unit_data.stats != null:
		atk += unit_data.stats.get_damage_bonus(combat.damage_stat)
	atk = maxi(roundi(float(atk) * combat.outgoing_damage_multiplier), 1)
	var hp: int = unit_data.stats.get_max_hp() if unit_data.stats != null else 0

	var combat_row := HBoxContainer.new()
	combat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_row.add_theme_constant_override("separation", 10)
	combat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(combat_row)

	combat_row.add_child(_make_stat_chip(_SWORD_ICON, atk))
	combat_row.add_child(_make_stat_chip(_HP_ICON, hp))

	var speed_label := Label.new()
	speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_label.text = "Speed %s secs" % str(combat.attack_interval)
	speed_label.add_theme_color_override("font_color", PaperStyles.INK)
	speed_label.add_theme_font_size_override("font_size", 24)
	combat_row.add_child(speed_label)

	var show_blunt := combat.damage_type == WeaponData.DamageType.BLUNT
	var show_aoe := combat.targeting_mode == WeaponData.TargetingMode.AOE
	if show_blunt or show_aoe:
		var tag_row := HBoxContainer.new()
		tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag_row.add_theme_constant_override("separation", 4)
		tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(tag_row)
		if show_blunt:
			tag_row.add_child(_make_tag_chip("Blunt"))
		if show_aoe:
			tag_row.add_child(_make_tag_chip("AOE"))

	var description := unit_data.short_description.strip_edges()
	if not description.is_empty():
		var desc_label := Label.new()
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc_label.text = description
		desc_label.add_theme_color_override("font_color", PaperStyles.INK_MUTED)
		desc_label.add_theme_font_size_override("font_size", 24)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(_TOOLTIP_WIDTH, 0)
		vbox.add_child(desc_label)

	panel.reset_size()
	return panel


func _make_stat_chip(icon: Texture2D, value: int) -> StatChip:
	var chip: StatChip = _STAT_CHIP_SCENE.instantiate()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.icon = icon
	chip.chip_size = _CHIP_SIZE
	chip.value_font_size = _CHIP_FONT_SIZE
	if chip.is_node_ready():
		chip.set_value(value)
	else:
		chip.ready.connect(chip.set_value.bind(value), CONNECT_ONE_SHOT)
	return chip


func _make_tag_chip(text: String) -> TagChip:
	var tag: TagChip = _TAG_CHIP_SCENE.instantiate()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.set_text(text)
	return tag

