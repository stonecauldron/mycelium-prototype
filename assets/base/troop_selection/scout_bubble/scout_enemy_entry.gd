class_name ScoutEnemyEntry
extends HBoxContainer

## Larger than strain scout portraits — enemy art is shorter above the feet origin.
const _PORTRAIT_SCALE := 0.7
## Raise feet above the host bottom so the body lines up with the count label.
const _PORTRAIT_Y_FACTOR := 0.82
const _TOOLTIP_WIDTH := 260.0

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
	tip.tree_entered.connect(_configure_tooltip_popup.bind(tip), CONNECT_ONE_SHOT)
	return tip


func _build_enemy_tooltip(unit_data: EnemyUnitData) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.92156863, 0.9098039, 0.87058824, 1)
	style.border_color = Color(0, 0, 0, 1)
	style.set_border_width_all(5)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14.0
	style.content_margin_top = 12.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = unit_data.display_name
	name_label.add_theme_color_override("font_color", Color(0.03137255, 0.03529412, 0.02745098, 1))
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(_TOOLTIP_WIDTH, 0)
	vbox.add_child(name_label)

	var description := unit_data.short_description.strip_edges()
	if not description.is_empty():
		var desc_label := Label.new()
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc_label.text = description
		desc_label.add_theme_color_override("font_color", Color(0.15, 0.18, 0.14, 1))
		desc_label.add_theme_font_size_override("font_size", 24)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(_TOOLTIP_WIDTH, 0)
		vbox.add_child(desc_label)

	panel.reset_size()
	return panel


func _configure_tooltip_popup(tip: Control) -> void:
	var node: Node = tip.get_parent()
	while node != null:
		if node is PopupPanel:
			var popup := node as PopupPanel
			popup.transparent = true
			popup.transparent_bg = true
			popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			var tip_size := tip.get_combined_minimum_size()
			popup.size = Vector2i(ceili(tip_size.x), ceili(tip_size.y))
			return
		node = node.get_parent()
