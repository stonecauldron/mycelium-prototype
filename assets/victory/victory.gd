extends Control

const _BASE_SCENE_PATH := "res://assets/base/base.tscn"
const _FEEDBACK_URL := "https://forms.gle/zWwB86ZGcmRpucoT7"

@onready var _restart_button: Button = %RestartButton
@onready var _feedback_button: Button = %FeedbackButton


func _ready() -> void:
	_restart_button.pressed.connect(_on_restart_pressed)
	_feedback_button.pressed.connect(_on_feedback_pressed)
	_restart_button.grab_focus()


func _on_restart_pressed() -> void:
	GameState.reset_run()
	SceneTransition.change_scene(_BASE_SCENE_PATH)


func _on_feedback_pressed() -> void:
	_open_feedback_url()


func _open_feedback_url() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.open('%s', '_blank');" % _FEEDBACK_URL)
	else:
		OS.shell_open(_FEEDBACK_URL)
