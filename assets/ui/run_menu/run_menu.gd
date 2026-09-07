class_name RunMenu
extends CanvasLayer

signal returning_to_title

enum Page { MENU, SETTINGS, RETURN_TO_TITLE, QUIT }

const _TITLE_SCENE := "res://assets/title/title.tscn"

@export var intent_scene: String = "base"

@onready var _gear: Button = %GearButton
@onready var _overlay: Control = %Overlay
@onready var _heading: Label = %Heading
@onready var _menu_panel: PanelContainer = %Panel
@onready var _confirmation_heading: Label = %ConfirmationHeading
@onready var _menu_page: VBoxContainer = %MenuPage
@onready var _settings_page: VBoxContainer = %SettingsPage
@onready var _confirmation_page: Control = %ConfirmationPage
@onready var _settings_button: Button = %SettingsButton
@onready var _fullscreen_button: Button = %FullscreenButton
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton

var _page: Page = Page.MENU
var _open: bool = false
var _available: bool = true
var _was_paused: bool = false
var _leaving: bool = false
var _focus_buttons: Array[Control] = []


func _ready() -> void:
	_gear.pressed.connect(open_menu)
	%Dim.gui_input.connect(_on_dim_gui_input)
	_settings_button.pressed.connect(_show_page.bind(Page.SETTINGS))
	%ResumeButton.pressed.connect(close_menu)
	%TitleButton.pressed.connect(_show_page.bind(Page.RETURN_TO_TITLE))
	%QuitButton.pressed.connect(_show_page.bind(Page.QUIT))
	%QuitButton.visible = not OS.has_feature("web")
	%BackButton.pressed.connect(_show_page.bind(Page.MENU))
	_cancel_button.pressed.connect(_show_page.bind(Page.MENU))
	_confirm_button.pressed.connect(_confirm_exit)
	# Press on input-down so web fullscreen runs within the browser's user gesture.
	_fullscreen_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_fullscreen_button.pressed.connect(_toggle_fullscreen)
	_overlay.hide()


func _exit_tree() -> void:
	if _open:
		get_tree().paused = _was_paused


func _input(event: InputEvent) -> void:
	if not _available or SceneTransition.is_transitioning():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if not _open:
				open_menu()
			elif _page != Page.MENU:
				_show_page(Page.MENU)
			else:
				close_menu()


func _shortcut_input(event: InputEvent) -> void:
	# Let the panel handle keyboard navigation, but block gameplay/debug shortcuts.
	if _open:
		# Start focus only after an explicit navigation key, never when opening a page.
		if get_viewport().gui_get_focus_owner() == null and not _focus_buttons.is_empty():
			if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
				_focus_buttons.front().grab_focus()
			elif event.is_action_pressed("ui_focus_prev") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
				_focus_buttons.back().grab_focus()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _open and _page == Page.SETTINGS:
		_fullscreen_button.set_pressed_no_signal(SettingsServer.is_fullscreen())


func set_available(available: bool) -> void:
	_available = available
	visible = available
	if not available:
		close_menu()


func open_menu() -> void:
	if _open or not _available or SceneTransition.is_transitioning():
		return
	var viewport := get_viewport()
	viewport.gui_cancel_drag()
	viewport.gui_release_focus()
	ActionFeedback.dismiss()
	_was_paused = get_tree().paused
	_open = true
	get_tree().paused = true
	_gear.focus_mode = Control.FOCUS_NONE
	_overlay.show()
	_show_page(Page.MENU)


func close_menu() -> void:
	if not _open or _leaving:
		return
	_open = false
	_overlay.hide()
	_gear.focus_mode = Control.FOCUS_ALL
	get_tree().paused = _was_paused


func _show_page(page: Page) -> void:
	if _leaving:
		return
	_page = page
	_menu_page.visible = page == Page.MENU
	_settings_page.visible = page == Page.SETTINGS
	_confirmation_page.visible = page in [Page.RETURN_TO_TITLE, Page.QUIT]
	_menu_panel.visible = not _confirmation_page.visible
	match page:
		Page.MENU:
			_confine_focus(_menu_page)
			_heading.text = "Paused"
		Page.SETTINGS:
			_confine_focus(_settings_page)
			_heading.text = "Settings"
			_fullscreen_button.set_pressed_no_signal(SettingsServer.is_fullscreen())
		Page.RETURN_TO_TITLE, Page.QUIT:
			_confine_focus(%ConfirmationActions)
			var action := "Return to title" if page == Page.RETURN_TO_TITLE else "Quit"
			_confirmation_heading.text = "%s?" % action
			_confirm_button.text = action


func _confine_focus(page: Control) -> void:
	_focus_buttons.clear()
	for child in page.get_children():
		if child is BaseButton and child.visible:
			_focus_buttons.append(child)
	for i in _focus_buttons.size():
		var button := _focus_buttons[i]
		var previous := button.get_path_to(_focus_buttons[(i - 1 + _focus_buttons.size()) % _focus_buttons.size()])
		var next := button.get_path_to(_focus_buttons[(i + 1) % _focus_buttons.size()])
		button.focus_previous = previous
		button.focus_next = next
		button.focus_neighbor_top = previous
		button.focus_neighbor_bottom = next
		button.focus_neighbor_left = previous
		button.focus_neighbor_right = next


func _toggle_fullscreen() -> void:
	SettingsServer.set_fullscreen(not SettingsServer.is_fullscreen())


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			close_menu()


func _confirm_exit() -> void:
	if _leaving:
		return
	if _page == Page.QUIT:
		_leaving = true
		Analytics.request_quit(intent_scene)
	elif _page == Page.RETURN_TO_TITLE:
		_leaving = true
		Analytics.intent("title", intent_scene)
		returning_to_title.emit()
		# Keep gameplay paused through the fade; _exit_tree releases the pause.
		SceneTransition.change_scene(_TITLE_SCENE)
