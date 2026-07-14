extends Control

enum TabId { BARRACKS, NURSERY }

## Left-to-right order; Barracks stays rightmost when Nursery is visible.
const TAB_DEFS := [
	{"id": TabId.NURSERY, "label": "Nursery"},
	{"id": TabId.BARRACKS, "label": "Barracks"},
]

const SCREEN_SCENES := {
	TabId.BARRACKS: preload("res://assets/base/troop_selection/troop_selection_screen.tscn"),
	TabId.NURSERY: preload("res://assets/base/nursery/nursery_screen.tscn"),
}

const _BIOMASS_DIGITS := 4

@onready var _content_host: Control = %ContentHost
@onready var _tab_bar: HBoxContainer = %TabBar
@onready var _day_label: Label = %DayLabel
@onready var _biomass_amount: Label = %BiomassAmount

var _current_tab: TabId = TabId.BARRACKS
var _current_screen: BaseScreen
var _tab_buttons: Dictionary = {}
var _tab_underlines: Dictionary = {}


func _ready() -> void:
	_refresh_hud()
	_build_tab_bar()
	if GameState.consume_prefer_nursery_tab():
		_select_tab(TabId.NURSERY)
	else:
		_select_tab(TabId.BARRACKS)


func _refresh_hud() -> void:
	var day := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	_day_label.text = "Day %d / %d" % [day, GameState.WIN_DAYS]
	_biomass_amount.text = "%0*d kg" % [_BIOMASS_DIGITS, GameState.biomass.amount]


func _is_tab_visible(tab_id: TabId) -> bool:
	match tab_id:
		TabId.NURSERY:
			return GameState.is_nursery_unlocked()
		_:
			return true


func _build_tab_bar() -> void:
	for child in _tab_bar.get_children():
		child.queue_free()
	_tab_buttons.clear()
	_tab_underlines.clear()

	for def in TAB_DEFS:
		var tab_id: TabId = def["id"]
		if not _is_tab_visible(tab_id):
			continue

		var column := VBoxContainer.new()
		column.theme_type_variation = &"TabColumn"
		column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var button := Button.new()
		button.theme_type_variation = &"NavButton"
		button.text = str(def["label"])
		button.custom_minimum_size = Vector2(96, 56)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select_tab.bind(tab_id))
		column.add_child(button)

		var underline := ColorRect.new()
		underline.custom_minimum_size = Vector2(0, 4)
		underline.color = Color(0.92, 0.92, 0.9, 1.0)
		underline.visible = false
		column.add_child(underline)

		_tab_bar.add_child(column)
		_tab_buttons[tab_id] = button
		_tab_underlines[tab_id] = underline


func _select_tab(tab_id: TabId) -> void:
	if not _is_tab_visible(tab_id):
		return
	_current_tab = tab_id
	_update_tab_visuals()
	_show_screen_for_tab(tab_id)


func _update_tab_visuals() -> void:
	for tab_id in _tab_underlines:
		var underline: ColorRect = _tab_underlines[tab_id]
		underline.visible = tab_id == _current_tab
		var button: Button = _tab_buttons[tab_id]
		if tab_id == _current_tab:
			button.modulate = Color(1, 1, 1, 1)
		else:
			button.modulate = Color(0.8, 0.8, 0.8, 1)


func _show_screen_for_tab(tab_id: TabId) -> void:
	if _current_screen != null:
		_current_screen.on_screen_hidden()
		_current_screen = null
	_clear_content_host()

	var packed: PackedScene = SCREEN_SCENES.get(tab_id) as PackedScene
	if packed == null:
		var placeholder := Label.new()
		placeholder.text = "%s — coming soon" % _tab_label(tab_id)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_content_host.add_child(placeholder)
		return

	var screen := packed.instantiate() as BaseScreen
	_content_host.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_current_screen = screen
	screen.on_screen_shown()


func _clear_content_host() -> void:
	for child in _content_host.get_children():
		_content_host.remove_child(child)
		child.queue_free()


func _tab_label(tab_id: TabId) -> String:
	for def in TAB_DEFS:
		if def["id"] == tab_id:
			return str(def["label"])
	return "Base"
