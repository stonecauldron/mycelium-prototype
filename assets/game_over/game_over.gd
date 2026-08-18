extends Control

const _TITLE_SCENE_PATH := "res://assets/title/title.tscn"

@onready var _new_run_button: Button = %NewRunButton
@onready var _feedback_button: Button = %FeedbackButton
@onready var _wishlist_button: Button = %WishlistButton
@onready var _back_to_title_button: Button = %BackToTitleButton


func _ready() -> void:
	_new_run_button.pressed.connect(_on_new_run_pressed)
	_feedback_button.pressed.connect(_on_feedback_pressed)
	_wishlist_button.pressed.connect(_on_wishlist_pressed)
	_back_to_title_button.pressed.connect(_on_back_to_title_pressed)
	_new_run_button.grab_focus()


func _on_new_run_pressed() -> void:
	GameState.start_new_run()


func _on_feedback_pressed() -> void:
	Analytics.intent("feedback", "gameover")
	ExternalLinks.open(ExternalLinks.FEEDBACK_URL)


func _on_wishlist_pressed() -> void:
	Analytics.intent("wishlist", "gameover")
	ExternalLinks.open(ExternalLinks.STEAM_WISHLIST_URL)


func _on_back_to_title_pressed() -> void:
	Analytics.intent("title", "gameover")
	SceneTransition.change_scene(_TITLE_SCENE_PATH)
