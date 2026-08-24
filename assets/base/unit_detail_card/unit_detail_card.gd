class_name UnitDetailCard
extends Control

const CARD_WIDTH := 390.0
const PORTRAIT_HOST_HEIGHT := 140.0

var unit_data: RosterUnitData
var show_portrait: bool = true
var interactive: bool = true

@onready var _card_panel: PanelContainer = $CardPanel
## Typed at runtime via unit_detail_card_content.gd (class_name UnitDetailCardContent).
@onready var _content = %UnitDetailCardContent


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
		_sync_content()
		fit_to_content()
	else:
		ready.connect(_on_setup_ready, CONNECT_ONE_SHOT)


func _on_setup_ready() -> void:
	_apply_interaction_mode()
	_sync_content()
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
	if _content != null:
		_content.apply_portrait_layout()
	DetailCardFit.apply(self, _card_panel, CARD_WIDTH)


func _ready() -> void:
	_set_children_mouse_filter_ignore(self)
	_apply_interaction_mode()
	if unit_data == null and get_tree().current_scene == self:
		unit_data = _make_mock_unit()
	_sync_content()
	fit_to_content()


func _make_mock_unit() -> RosterUnitData:
	return RosterUnitData.create(
		"Mock Capling",
		UnitStatsData.create_for_tier(UnitStatsData.PowerTier.COMMON),
		WeaponSchool.sword(),
		UnitStatsData.PowerTier.COMMON,
	)


func _sync_content() -> void:
	if _content == null:
		return
	if unit_data != null:
		_content.setup(unit_data, show_portrait)
	else:
		_content.show_portrait = show_portrait
		_content.apply_portrait_layout()


func _apply_interaction_mode() -> void:
	mouse_filter = (
		Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	)


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)
