extends Control

enum TabId { TAVERN, BARRACKS, STOCKPILE, WILDS, SHRINE, CAMP, RUINS }

const TAB_DEFS := [
	{"id": TabId.TAVERN, "label": "Tavern", "enabled": false},
	{"id": TabId.BARRACKS, "label": "Barracks", "enabled": true},
	{"id": TabId.STOCKPILE, "label": "Stockpile", "enabled": false},
	{"id": TabId.WILDS, "label": "Wilds", "enabled": false},
	{"id": TabId.SHRINE, "label": "Shrine", "enabled": false},
	{"id": TabId.CAMP, "label": "Camp", "enabled": false},
	{"id": TabId.RUINS, "label": "Ruins", "enabled": false},
]

const SCREEN_SCENES := {
	TabId.BARRACKS: preload("res://scenes/base/screens/ArmySelectionScreen.tscn"),
}

@onready var _content_host: Control = %ContentHost
@onready var _tab_bar: HBoxContainer = %TabBar

var _current_tab: TabId = TabId.BARRACKS
var _current_screen: BaseScreen
var _tab_buttons: Dictionary = {}
var _tab_underlines: Dictionary = {}


func _ready() -> void:
	_build_tab_bar()
	_select_tab(TabId.BARRACKS)


func _build_tab_bar() -> void:
	for child in _tab_bar.get_children():
		child.queue_free()
	_tab_buttons.clear()
	_tab_underlines.clear()

	for def in TAB_DEFS:
		var tab_id: TabId = def["id"]
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var button := Button.new()
		button.text = str(def["label"])
		button.custom_minimum_size = Vector2(96, 56)
		button.disabled = not bool(def["enabled"])
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
		elif button.disabled:
			button.modulate = Color(0.55, 0.55, 0.55, 1)
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
