extends Control

@onready var _new_run_button: Button = %NewRunButton
@onready var _wishlist_button: Button = %WishlistButton
@onready var _credits_button: Button = %CreditsButton
@onready var _quit_button: Button = %QuitButton
@onready var _menu_page: VBoxContainer = %MenuPage
@onready var _credits_page: VBoxContainer = %CreditsPage
@onready var _credits_back_button: Button = %CreditsBackButton
@onready var _run_menu: RunMenu = $RunMenu


func _ready() -> void:
	Audio.play_base_music()
	_new_run_button.pressed.connect(_on_new_run_pressed)
	_wishlist_button.pressed.connect(_on_wishlist_pressed)
	_credits_button.pressed.connect(_set_credits_visible.bind(true))
	_credits_back_button.pressed.connect(_set_credits_visible.bind(false))
	_quit_button.pressed.connect(_on_quit_pressed)
	ExternalLinks.arm_web_open(_wishlist_button, ExternalLinks.STEAM_WISHLIST_URL)
	_quit_button.visible = not OS.has_feature("web")


func _unhandled_input(event: InputEvent) -> void:
	if _credits_page.visible and event.is_action_pressed("ui_cancel"):
		_set_credits_visible(false)
		get_viewport().set_input_as_handled()


func _set_credits_visible(show_credits: bool) -> void:
	get_viewport().gui_release_focus()
	_menu_page.visible = not show_credits
	_credits_page.visible = show_credits
	_run_menu.set_available(not show_credits)
	Audio.play_ui_cue(Sfx.Cue.UI_OPEN if show_credits else Sfx.Cue.UI_CLOSE)


func _on_new_run_pressed() -> void:
	GameState.start_new_run()


func _on_wishlist_pressed() -> void:
	Analytics.intent("wishlist", "title")
	ExternalLinks.open(ExternalLinks.STEAM_WISHLIST_URL)


func _on_quit_pressed() -> void:
	Analytics.request_quit("title")
