extends Node2D

enum TabId { COLONY, NURSERY }

## Left-to-right world order; matches zone positions on X.
const TAB_DEFS := [
	{"id": TabId.NURSERY, "label": "Nursery"},
	{"id": TabId.COLONY, "label": "War Chamber"},
]

const VIEWPORT_SIZE := Vector2(1920, 1080)
const CAMERA_TWEEN_SECONDS := 0.35
const _FLOATING_ARROW_SCENE := preload("res://assets/ui/floating_arrow/floating_arrow.tscn")
const _TEXT_TOOLTIP_SCRIPT := preload("res://assets/ui/detail_tooltip/text_tooltip.gd")

@onready var _camera: Camera2D = %BaseCamera
@onready var _tab_bar: HBoxContainer = %TabBar
@onready var _day_label: Label = %DayLabel
@onready var _biomass_amount: Label = %BiomassChip.get_node("%BiomassAmount")
@onready var _debug_advance_day_button: Button = %DebugAdvanceDayButton
@onready var _start_combat_button: Button = %StartCombatButton
@onready var _nursery_zone: Node2D = %NurseryZone
@onready var _colony_zone: Node2D = %ColonyZone
@onready var _nursery_screen: BaseScreen = %NurseryScreen
@onready var _colony_screen: TroopSelectionScreen = %ColonyScreen

var _current_tab: TabId = TabId.COLONY
var _current_screen: BaseScreen
var _tab_buttons: Dictionary = {}
var _tab_underlines: Dictionary = {}
var _tab_key_order: Array[TabId] = []
var _nursery_ready_badge: Label
var _camera_tween: Tween
var _start_arrow: FloatingArrow = null
var _progress_tracks: Array[CombatProgressTrack] = []


func _ready() -> void:
	Audio.play_base_music()
	if not GameState.run_started:
		GameState.reset_run()
	_camera.make_current()
	_wire_progress_tracks()
	GameState.biomass.changed.connect(_refresh_biomass_amount)
	GameState.nursery.changed.connect(_refresh_nursery_readiness)
	_refresh_hud()
	_build_tab_bar()
	_start_combat_button.pressed.connect(_on_start_combat_pressed)
	_debug_advance_day_button.pressed.connect(_on_debug_advance_day_pressed)
	_debug_advance_day_button.visible = GameState.debug_mode_active
	GameState.debug_mode_changed.connect(_on_debug_mode_changed)
	set_start_combat_enabled(_colony_screen.can_start_combat())
	_ensure_start_arrow()
	var initial := TabId.COLONY
	if GameState.consume_prefer_nursery_tab():
		initial = TabId.NURSERY
	_select_tab(initial, true)
	_colony_screen.ensure_pending_modals()
	Analytics.maybe_start_day()


func _on_debug_mode_changed(is_active: bool) -> void:
	_debug_advance_day_button.visible = is_active
	_build_tab_bar()
	if not _is_tab_visible(_current_tab):
		_select_tab(TabId.COLONY)
		return
	_update_tab_visuals()
	if _current_screen != null:
		_current_screen.on_screen_shown()
	_colony_screen.ensure_pending_modals()
	_refresh_hud()


func _on_debug_advance_day_pressed() -> void:
	GameState.debug_advance_day()
	_build_tab_bar()
	_update_tab_visuals()
	if _current_screen != null:
		_current_screen.on_screen_shown()
	_colony_screen.ensure_pending_modals()
	_refresh_hud()


func _on_start_combat_pressed() -> void:
	if GameState.pending_seal_choice:
		_colony_screen.toggle_seal_choice()
		return
	GameState.show_start_combat_hint = false
	if _start_arrow != null:
		_start_arrow.hide_arrow()
	_colony_screen.start_combat()


## RunMenu gives Escape to the visible chooser before opening its pause menu.
func hide_pending_seal_choice() -> bool:
	if not _colony_screen.is_seal_choice_visible():
		return false
	_colony_screen.hide_seal_choice()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	var index := -1
	match key:
		KEY_1:
			index = 0
		KEY_2:
			index = 1
		_:
			return
	if _tab_key_order.size() < 2:
		return
	if index < 0 or index >= _tab_key_order.size():
		return
	_select_tab(_tab_key_order[index], false)
	get_viewport().set_input_as_handled()


func _ensure_start_arrow() -> void:
	if _start_arrow != null or _start_combat_button == null:
		return
	_start_arrow = _FLOATING_ARROW_SCENE.instantiate() as FloatingArrow
	_start_combat_button.add_child(_start_arrow)
	_start_arrow.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_start_arrow.offset_left = -FloatingArrow.ARROW_SIZE.x * 0.5
	_start_arrow.offset_right = FloatingArrow.ARROW_SIZE.x * 0.5
	_start_arrow.offset_top = -FloatingArrow.ARROW_SIZE.y - 4.0
	_start_arrow.offset_bottom = -4.0
	_refresh_start_arrow()


func _refresh_start_arrow() -> void:
	if _start_arrow == null:
		return
	if (
		GameState.show_start_combat_hint
		and not GameState.pending_seal_choice
		and not _start_combat_button.disabled
		and _colony_screen.get_training_hint_unit() == null
	):
		_start_arrow.show_arrow()
	else:
		_start_arrow.hide_arrow()


func set_start_combat_enabled(enabled: bool) -> void:
	# War Chamber screen _ready can run before this node's @onready vars are set.
	if _start_combat_button == null:
		return
	var pending := GameState.pending_seal_choice
	var chooser_visible := _colony_screen.is_seal_choice_visible()
	_start_combat_button.text = ("Hide" if chooser_visible else "Select Seal") if pending else "Start Battle"
	_start_combat_button.disabled = not pending and not enabled
	# The chooser leaves this button's hit area open; draw it above the dimmer too.
	_start_combat_button.z_index = 101 if chooser_visible else 0
	_refresh_start_arrow()


func _refresh_hud() -> void:
	var day := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	_day_label.text = "Day %d / %d" % [day, GameState.WIN_DAYS]
	_refresh_biomass_amount()
	_refresh_nursery_readiness()
	for track in _progress_tracks:
		track.refresh()
	if _colony_screen != null:
		_colony_screen.refresh_unlock_affordability()


func _refresh_biomass_amount() -> void:
	_biomass_amount.text = BiomassDisplay.number(GameState.biomass.amount)


func _wire_progress_tracks() -> void:
	_progress_tracks.clear()
	if _colony_screen == null:
		return
	var track := _colony_screen.get_node_or_null("HeaderBlock/CombatProgressTrack") as CombatProgressTrack
	if track == null:
		return
	_progress_tracks.append(track)
	if not track.elite_hovered.is_connected(_on_elite_track_hovered):
		track.elite_hovered.connect(_on_elite_track_hovered)
	if not track.elite_unhovered.is_connected(_on_elite_track_unhovered):
		track.elite_unhovered.connect(_on_elite_track_unhovered)


func _on_elite_track_hovered(day: int) -> void:
	var scout := _scout_bubble()
	if scout != null:
		scout.preview_elite_for_day(day)


func _on_elite_track_unhovered() -> void:
	var scout := _scout_bubble()
	if scout != null:
		scout.clear_preview()


func _scout_bubble() -> ScoutBubble:
	if _colony_screen == null:
		return null
	return _colony_screen.get_node_or_null("ScoutBubble") as ScoutBubble


func _is_tab_visible(tab_id: TabId) -> bool:
	match tab_id:
		TabId.NURSERY:
			return GameState.is_nursery_unlocked()
		_:
			return true


func _zone_for_tab(tab_id: TabId) -> Node2D:
	match tab_id:
		TabId.NURSERY:
			return _nursery_zone
		_:
			return _colony_zone


func _screen_for_tab(tab_id: TabId) -> BaseScreen:
	match tab_id:
		TabId.NURSERY:
			return _nursery_screen
		_:
			return _colony_screen


func _camera_position_for_zone(zone: Node2D) -> Vector2:
	return zone.global_position + VIEWPORT_SIZE * 0.5


func _build_tab_bar() -> void:
	for child in _tab_bar.get_children():
		child.queue_free()
	_tab_buttons.clear()
	_tab_underlines.clear()
	_tab_key_order.clear()
	_nursery_ready_badge = null

	var key_index := 1
	for def in TAB_DEFS:
		var tab_id: TabId = def["id"]
		if not _is_tab_visible(tab_id):
			continue

		var column := VBoxContainer.new()
		column.theme_type_variation = &"TabColumn"
		column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var button := Button.new()
		button.set_script(_TEXT_TOOLTIP_SCRIPT)
		button.theme_type_variation = &"NavButton"
		button.text = "%d  %s" % [key_index, str(def["label"])]
		button.custom_minimum_size = Vector2(180, 72)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select_tab.bind(tab_id, false))
		column.add_child(button)
		if tab_id == TabId.NURSERY:
			_add_nursery_ready_badge(button)

		var underline := ColorRect.new()
		underline.custom_minimum_size = Vector2(0, 4)
		underline.color = Color(0.94, 0.94, 0.88, 1.0)
		underline.visible = false
		column.add_child(underline)

		_tab_bar.add_child(column)
		_tab_buttons[tab_id] = button
		_tab_underlines[tab_id] = underline
		_tab_key_order.append(tab_id)
		key_index += 1

	_tab_bar.visible = _tab_key_order.size() >= 2
	_refresh_nursery_readiness()


func _add_nursery_ready_badge(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.43, 0.19, 0.22, 1)
	style.border_color = PaperStyles.CREAM
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	_nursery_ready_badge = Label.new()
	_nursery_ready_badge.name = "ReadyBadge"
	_nursery_ready_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nursery_ready_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nursery_ready_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_nursery_ready_badge.add_theme_stylebox_override("normal", style)
	_nursery_ready_badge.add_theme_color_override("font_color", PaperStyles.CREAM)
	_nursery_ready_badge.add_theme_font_size_override("font_size", 20)
	button.add_child(_nursery_ready_badge)
	_nursery_ready_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_nursery_ready_badge.offset_left = -26.0
	_nursery_ready_badge.offset_right = 6.0
	_nursery_ready_badge.offset_top = -10.0
	_nursery_ready_badge.offset_bottom = 22.0


func _refresh_nursery_readiness() -> void:
	var button := _tab_buttons.get(TabId.NURSERY) as Button
	if button == null:
		return
	var count := GameState.nursery.ready_plot_count()
	_nursery_ready_badge.text = str(count)
	_nursery_ready_badge.visible = count > 0
	button.tooltip_text = "%d Plot%s ready to harvest" % [count, "" if count == 1 else "s"] if count > 0 else ""


func _select_tab(tab_id: TabId, instant: bool = false) -> void:
	if not _is_tab_visible(tab_id):
		return
	if _current_screen != null and _current_tab == tab_id and not instant:
		return
	if not instant:
		Audio.play_ui_cue(Sfx.Cue.UI_OPEN)
	ActionFeedback.dismiss()

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

	# Rebuild destination UI at transition start so heavy work overlaps the camera move.
	_current_screen = next_screen
	_current_screen.on_screen_shown()
	_refresh_hud()

	if instant:
		_camera.position = target
		return

	_camera_tween = create_tween()
	_camera_tween.set_ease(Tween.EASE_OUT)
	_camera_tween.set_trans(Tween.TRANS_CUBIC)
	_camera_tween.tween_property(_camera, "position", target, CAMERA_TWEEN_SECONDS)


func _update_tab_visuals() -> void:
	for tab_id in _tab_underlines:
		var underline: ColorRect = _tab_underlines[tab_id]
		underline.visible = tab_id == _current_tab
		var button: Button = _tab_buttons[tab_id]
		if tab_id == _current_tab:
			button.modulate = Color(1, 1, 1, 1)
		else:
			button.modulate = Color(0.8, 0.8, 0.8, 1)
