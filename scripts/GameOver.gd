extends Control

const _BASE_SCENE_PATH := "res://scenes/base/Base.tscn"

@onready var _restart_button: Button = %RestartButton


func _ready() -> void:
	_restart_button.pressed.connect(_on_restart_pressed)
	_restart_button.grab_focus()


func _on_restart_pressed() -> void:
	GameState.troop.reset()
	SceneTransition.change_scene(_BASE_SCENE_PATH)
