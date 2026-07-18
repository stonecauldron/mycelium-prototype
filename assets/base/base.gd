extends Node2D

enum TabId { COLONY, NURSERY, RIBOFORGE }

## Left-to-right world order; matches zone positions on X.
const TAB_DEFS := [
	{"id": TabId.NURSERY, "label": "Nursery"},
	{"id": TabId.RIBOFORGE, "label": "Riboforge"},
	{"id": TabId.COLONY, "label": "Colony"},
]

const VIEWPORT_SIZE := Vector2(1920, 1080)
const CAMERA_TWEEN_SECONDS := 0.35
const _BIOMASS_DIGITS := 4

@onready var _camera: Camera2D = %BaseCamera
@onready var _tab_bar: HBoxContainer = %TabBar
@onready var _day_label: Label = %DayLabel
@onready var _biomass_amount: Label = %BiomassAmount
@onready var _start_combat_button: Button = %StartCombatButton
@onready var _nursery_zone: Node2D = %NurseryZone
@onready var _riboforge_zone: Node2D = %RiboforgeZone
@onready var _colony_zone: Node2D = %ColonyZone
@onready var _nursery_screen: BaseScreen = %NurseryScreen
@onready var _riboforge_screen: BaseScreen = %RiboforgeScreen
@onready var _colony_screen: TroopSelectionScreen = %ColonyScreen

var _current_tab: TabId = TabId.COLONY
var _current_screen: BaseScreen
var _tab_buttons: Dictionary = {}
var _tab_underlines: Dictionary = {}
var _camera_tween: Tween


func _ready() -> void:
	_camera.make_current()
	_refresh_hud()
	_build_tab_bar()
	_start_combat_button.pressed.connect(_on_start_combat_pressed)
	set_start_combat_enabled(_colony_screen.can_start_combat())
	var initial := TabId.COLONY
	if GameState.consume_prefer_riboforge_tab():
		initial = TabId.RIBOFORGE
	elif GameState.consume_prefer_nursery_tab():
		initial = TabId.NURSERY
	_select_tab(initial, true)


func set_start_combat_enabled(enabled: bool) -> void:
	# Colony screen _ready can run before this node's @onready vars are set.
	if _start_combat_button == null:
		return
	_start_combat_button.disabled = not enabled


func _on_start_combat_pressed() -> void:
	_colony_screen.start_combat()


func _refresh_hud() -> void:
	var day := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	_day_label.text = "Day %d / %d" % [day, GameState.WIN_DAYS]
	_biomass_amount.text = "%0*d kg" % [_BIOMASS_DIGITS, GameState.biomass.amount]


func _is_tab_visible(tab_id: TabId) -> bool:
	match tab_id:
		TabId.NURSERY:
			return GameState.is_nursery_unlocked()
		TabId.RIBOFORGE:
			return GameState.is_riboforge_unlocked()
		_:
			return true


func _zone_for_tab(tab_id: TabId) -> Node2D:
	match tab_id:
		TabId.NURSERY:
			return _nursery_zone
		TabId.RIBOFORGE:
			return _riboforge_zone
		_:
			return _colony_zone


func _screen_for_tab(tab_id: TabId) -> BaseScreen:
	match tab_id:
		TabId.NURSERY:
			return _nursery_screen
		TabId.RIBOFORGE:
			return _riboforge_screen
		_:
			return _colony_screen


func _camera_position_for_zone(zone: Node2D) -> Vector2:
	return zone.global_position + VIEWPORT_SIZE * 0.5


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
		button.pressed.connect(_select_tab.bind(tab_id, false))
		column.add_child(button)

		var underline := ColorRect.new()
		underline.custom_minimum_size = Vector2(0, 4)
		underline.color = Color(0.92, 0.92, 0.9, 1.0)
		underline.visible = false
		column.add_child(underline)

		_tab_bar.add_child(column)
		_tab_buttons[tab_id] = button
		_tab_underlines[tab_id] = underline


func _select_tab(tab_id: TabId, instant: bool = false) -> void:
	if not _is_tab_visible(tab_id):
		return
	if _current_screen != null and _current_tab == tab_id and not instant:
		return

	var previous := _current_screen
	_current_tab = tab_id
	_update_tab_visuals()

	var zone := _zone_for_tab(tab_id)
	var target := _camera_position_for_zone(zone)
	var next_screen := _screen_for_tab(tab_id)

	if previous != null and previous != next_screen:
		previous.on_screen_hidden()

	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()

	if instant:
		_camera.position = target
		_current_screen = next_screen
		_current_screen.on_screen_shown()
		_refresh_hud()
		return

	_camera_tween = create_tween()
	_camera_tween.set_ease(Tween.EASE_OUT)
	_camera_tween.set_trans(Tween.TRANS_CUBIC)
	_camera_tween.tween_property(_camera, "position", target, CAMERA_TWEEN_SECONDS)
	_camera_tween.finished.connect(
		func() -> void:
			_current_screen = next_screen
			_current_screen.on_screen_shown()
			_refresh_hud(),
		CONNECT_ONE_SHOT
	)


func _update_tab_visuals() -> void:
	for tab_id in _tab_underlines:
		var underline: ColorRect = _tab_underlines[tab_id]
		underline.visible = tab_id == _current_tab
		var button: Button = _tab_buttons[tab_id]
		if tab_id == _current_tab:
			button.modulate = Color(1, 1, 1, 1)
		else:
			button.modulate = Color(0.8, 0.8, 0.8, 1)
