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
const _SPORE_CARD_SCENE := preload("res://assets/base/nursery/spore_card/spore_card.tscn")
const _READY_BADGE_TEXTURE := preload("res://assets/asset_packs/Cila - Paper UI stylized/square/square border 6.png")

@onready var _camera: Camera2D = %BaseCamera
@onready var _tab_bar: HBoxContainer = %TabBar
@onready var _day_label: Label = %DayLabel
@onready var _biomass_chip: BiomassChip = %BiomassChip
@onready var _debug_advance_day_button: Button = %DebugAdvanceDayButton
@onready var _start_combat_button: Button = %StartCombatButton
@onready var _undo_button: Button = %UndoButton
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
var _early_stock_button: Button
var _early_stock_popup: PanelContainer


func _ready() -> void:
	Audio.play_base_music()
	if not GameState.run_started:
		GameState.reset_run()
	GameState.ensure_guided_preparation()
	GameState.ensure_seal_choice_offers()
	GameState.ensure_guided_preparation_checkpoint()
	GameState.base_undo.begin_visit()
	GameState.base_undo.changed.connect(_refresh_undo_button)
	GameState.base_undo.restored.connect(_on_base_state_restored)
	_undo_button.pressed.connect(_on_undo_pressed)
	BiomassPreview.bind(_undo_button, _undo_biomass_preview)
	_refresh_undo_button()
	_camera.make_current()
	_wire_progress_tracks()
	GameState.nursery.changed.connect(_refresh_nursery_readiness)
	GameState.nursery.changed.connect(_refresh_early_stock_access)
	_refresh_hud()
	_build_tab_bar()
	_build_early_stock_button()
	_start_combat_button.pressed.connect(_on_start_combat_pressed)
	BiomassPreview.bind(_start_combat_button, _battle_biomass_preview, "On victory")
	_debug_advance_day_button.pressed.connect(_on_debug_advance_day_pressed)
	_debug_advance_day_button.visible = GameState.debug_mode_active
	GameState.debug_mode_changed.connect(_on_debug_mode_changed)
	set_start_combat_enabled(_colony_screen.can_start_combat())
	_ensure_start_arrow()
	var initial := TabId.COLONY
	if GameState.consume_prefer_nursery_tab() and not GameState.is_guided_run:
		initial = TabId.NURSERY
	_select_tab(initial, true)
	_colony_screen.ensure_pending_modals()
	var guide := GuidedRunGuide.new()
	guide.name = "GuidedRunGuide"
	guide.resolve_target = _resolve_guided_hint
	guide.is_blocked = _is_guided_hint_blocked
	$HudLayer/HudRoot.add_child(guide)
	Analytics.maybe_start_day()


func _exit_tree() -> void:
	GameState.base_undo.end_visit()


func _process(_delta: float) -> void:
	# Drag payloads hold live references; wait for the drag to end before restoring.
	_undo_button.disabled = not _can_undo()


func _can_undo() -> bool:
	return (
		GameState.base_undo.can_undo()
		and not get_tree().paused
		and not get_viewport().gui_is_dragging()
		and not SceneTransition.is_transitioning()
	)


func _shortcut_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_Z:
		return
	if not key.is_command_or_control_pressed() or key.shift_pressed or key.alt_pressed:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	if _can_undo():
		_on_undo_pressed()
		get_viewport().set_input_as_handled()


func _on_undo_pressed() -> void:
	if _can_undo():
		GameState.base_undo.undo()


func _refresh_undo_button() -> void:
	if _undo_button == null:
		return
	var platform_key := InputEventKey.new()
	platform_key.command_or_control_autoremap = true
	var shortcut := "⌘Z" if platform_key.meta_pressed else "Ctrl+Z"
	_undo_button.disabled = not _can_undo()
	var action := GameState.base_undo.next_action_name()
	_undo_button.tooltip_text = "Undo %s (%s)" % [action, shortcut] if not action.is_empty() else "Nothing to undo. Rerolls and Battles clear undo history."


func _undo_biomass_preview() -> Variant:
	if not _can_undo():
		return null
	var delta := GameState.base_undo.next_biomass_delta()
	if delta == 0:
		return null
	return delta


func _on_base_state_restored() -> void:
	ActionFeedback.dismiss()
	_colony_screen.refresh_after_undo()
	(_nursery_screen as NurseryScreen).refresh_after_undo()
	_refresh_hud()


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
	(_nursery_screen as NurseryScreen).dismiss_hatch_results()
	GameState.debug_advance_day()
	GameState.ensure_guided_preparation()
	GameState.ensure_seal_choice_offers()
	GameState.ensure_guided_preparation_checkpoint()
	_build_tab_bar()
	_update_tab_visuals()
	if _current_screen != null:
		_current_screen.on_screen_shown()
	_colony_screen.ensure_pending_modals()
	_refresh_hud()


func _on_start_combat_pressed() -> void:
	(_nursery_screen as NurseryScreen).dismiss_hatch_results()
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
		not GameState.is_guided_run
		and GameState.show_start_combat_hint
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
	var day := clampi(GameState.get_upcoming_day(), 1, GameState.get_run_length())
	_day_label.text = "Day %d / %d" % [day, GameState.get_run_length()]
	_refresh_biomass_amount()
	_refresh_nursery_readiness()
	_refresh_early_stock_access()
	for track in _progress_tracks:
		track.refresh()
	if _colony_screen != null:
		_colony_screen.refresh_unlock_affordability()


func _refresh_biomass_amount() -> void:
	_biomass_chip.refresh()


func _battle_biomass_preview() -> Variant:
	if _start_combat_button.disabled or not _colony_screen.can_start_combat():
		return null
	return EnemyComposer.battle_reward_for(GameState.get_upcoming_day(), GameState.upcoming_enemy_formation)


func _wire_progress_tracks() -> void:
	_progress_tracks.clear()
	if _colony_screen == null:
		return
	var track := _colony_screen.get_node_or_null("HeaderBlock/CombatProgressTrack") as CombatProgressTrack
	if track == null:
		return
	_progress_tracks.append(track)
	if not track.day_hovered.is_connected(_on_day_track_hovered):
		track.day_hovered.connect(_on_day_track_hovered)
	if not track.day_unhovered.is_connected(_on_day_track_unhovered):
		track.day_unhovered.connect(_on_day_track_unhovered)
	if not track.day_pressed.is_connected(_on_day_track_pressed):
		track.day_pressed.connect(_on_day_track_pressed)
	var scout := _scout_bubble()
	if scout != null and not scout.preview_focus_changed.is_connected(track.set_focused_day):
		scout.preview_focus_changed.connect(track.set_focused_day)


func _on_day_track_hovered(day: int) -> void:
	var scout := _scout_bubble()
	if scout != null:
		scout.preview_day(day)


func _on_day_track_unhovered() -> void:
	var scout := _scout_bubble()
	if scout != null:
		scout.clear_preview()


func _on_day_track_pressed(day: int) -> void:
	var scout := _scout_bubble()
	if scout == null:
		return
	if scout.focused_day() == day:
		scout.return_to_next_battle()
	else:
		scout.pin_day(day)


func _scout_bubble() -> ScoutBubble:
	if _colony_screen == null:
		return null
	return _colony_screen.get_node_or_null("ScoutBubble") as ScoutBubble


func _is_tab_visible(tab_id: TabId) -> bool:
	match tab_id:
		TabId.NURSERY:
			return GameState.is_feature_available(&"nursery") and GameState.is_nursery_unlocked()
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
	var style := StyleBoxTexture.new()
	style.texture = _READY_BADGE_TEXTURE
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


func is_tab_transitioning() -> bool:
	return _camera_tween != null and _camera_tween.is_valid() and _camera_tween.is_running()


func _is_guided_hint_blocked() -> bool:
	return (
		get_tree().paused or SceneTransition.is_transitioning()
		or get_viewport().gui_is_dragging() or is_tab_transitioning()
		or (is_instance_valid(_early_stock_popup) and _early_stock_popup.visible)
		or _colony_screen.is_guided_hint_blocked()
		or (_nursery_screen as NurseryScreen).is_guided_hint_blocked()
	)


## Resolve world-space targets only on the shown tab; first suggest navigation otherwise.
func _resolve_guided_hint(hint: Dictionary) -> Dictionary:
	var target: Control
	if StringName(hint.get("target", &"")) == &"battle":
		target = _start_combat_button
	else:
		var tab := TabId.NURSERY if StringName(hint.get("tab", &"war")) == &"nursery" else TabId.COLONY
		if not _is_tab_visible(tab):
			return {}
		if _current_tab != tab:
			return {"control": _tab_buttons.get(tab), "navigation": true}
		match StringName(hint.get("target", &"")):
			&"progression":
				if not _progress_tracks.is_empty():
					target = _progress_tracks[0]
			&"scout":
				var scout := _scout_bubble()
				if scout != null:
					target = scout.get_node_or_null("ScoutPanel") as Control
			_:
				if tab == TabId.NURSERY:
					target = (_nursery_screen as NurseryScreen).get_guided_hint_target(hint)
				else:
					target = _colony_screen.get_guided_hint_target(hint)
	return {"control": target, "navigation": false}


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


func _build_early_stock_button() -> void:
	_early_stock_button = Button.new()
	_early_stock_button.name = "EarlyStockButton"
	_early_stock_button.text = "Stock"
	_early_stock_button.theme_type_variation = &"NavButton"
	_early_stock_button.custom_minimum_size = Vector2(160, 56)
	var left_pad := $HudLayer/HudRoot/RootMargin/RootVBox/BottomBar/BottomMargin/BottomRow/LeftPad
	left_pad.add_child(_early_stock_button)
	_early_stock_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_early_stock_button.position.x = 96.0
	_early_stock_button.pressed.connect(_open_early_stock)
	_refresh_early_stock_access()


func _refresh_early_stock_access() -> void:
	if not is_instance_valid(_early_stock_button):
		return
	var available := (
		GameState.is_guided_run
		and not GameState.is_feature_available(&"nursery")
		and GameState.nursery.has_spore_in_stock()
	)
	_early_stock_button.visible = available
	if not available:
		hide_early_stock()


func _open_early_stock() -> void:
	if not _early_stock_button.visible:
		return
	if is_instance_valid(_early_stock_popup):
		_early_stock_popup.free()
	_early_stock_popup = PanelContainer.new()
	_early_stock_popup.name = "EarlyStockPopup"
	_early_stock_popup.z_index = 100
	PaperStyles.apply_tooltip(_early_stock_popup)
	$HudLayer/HudRoot.add_child(_early_stock_popup)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	_early_stock_popup.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Stock"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", PaperStyles.INK)
	title.add_theme_font_size_override("font_size", 32)
	header.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide_early_stock)
	header.add_child(close)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	for item in GameState.nursery.stock.slots:
		var spore := item as SporeData
		if spore == null:
			continue
		var card := _SPORE_CARD_SCENE.instantiate() as SporeCard
		card.setup(spore, -1)
		row.add_child(card)
		# Keep the existing item tooltip, without exposing Nursery actions early.
		card.set_drag_forwarding(_read_only_stock_drag, Callable(), Callable())
		card.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_center_early_stock.call_deferred()


func _read_only_stock_drag(_position: Vector2) -> Variant:
	return null


func hide_early_stock() -> bool:
	if not is_instance_valid(_early_stock_popup) or not _early_stock_popup.visible:
		return false
	DetailTooltipPopup.dismiss_current()
	_early_stock_popup.hide()
	return true


func _center_early_stock() -> void:
	if not is_instance_valid(_early_stock_popup):
		return
	_early_stock_popup.reset_size()
	_early_stock_popup.position = (VIEWPORT_SIZE - _early_stock_popup.size) * 0.5


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_early_stock_popup) or not _early_stock_popup.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if not _early_stock_popup.get_global_rect().has_point(event.position):
			hide_early_stock()
