extends Control

const _BASE_SCENE_PATH := "res://assets/base/base.tscn"
const _FEEDBACK_URL := "https://forms.gle/zWwB86ZGcmRpucoT7"
const _STEAM_WISHLIST_URL := "https://store.steampowered.com/app/4963670/Auto_Shrooms/"

@onready var _restart_button: Button = %RestartButton
@onready var _feedback_button: Button = %FeedbackButton
@onready var _wishlist_button: Button = %WishlistButton


func _ready() -> void:
	_restart_button.pressed.connect(_on_restart_pressed)
	_feedback_button.pressed.connect(_on_feedback_pressed)
	_wishlist_button.pressed.connect(_on_wishlist_pressed)
	_restart_button.grab_focus()


func _on_restart_pressed() -> void:
	GameState.reset_run()
	SceneTransition.change_scene(_BASE_SCENE_PATH)


func _on_feedback_pressed() -> void:
	_open_url(_FEEDBACK_URL)


func _on_wishlist_pressed() -> void:
	_open_url(_STEAM_WISHLIST_URL)


func _open_url(url: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open('%s', '_blank');" % url)
	else:
		OS.shell_open(url)
