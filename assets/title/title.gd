extends Control

@onready var _new_run_button: Button = %NewRunButton
@onready var _wishlist_button: Button = %WishlistButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_new_run_button.pressed.connect(_on_new_run_pressed)
	_wishlist_button.pressed.connect(_on_wishlist_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_quit_button.visible = not OS.has_feature("web")
	_new_run_button.grab_focus()


func _on_new_run_pressed() -> void:
	GameState.start_new_run()


func _on_wishlist_pressed() -> void:
	Analytics.intent("wishlist", "title")
	ExternalLinks.open(ExternalLinks.STEAM_WISHLIST_URL)


func _on_quit_pressed() -> void:
	Analytics.intent("quit", "title")
	get_tree().quit()
