class_name BaseScreen
extends Control

## Modular base content screens implement this and are hosted by Base.
## Override for enter/exit hooks when tabs switch.


func on_screen_shown() -> void:
	pass


func on_screen_hidden() -> void:
	pass
