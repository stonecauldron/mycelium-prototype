class_name UnitStrain
extends Resource

@export var display_name: String = "Capling"
@export var appearance_scene: PackedScene


func instantiate_appearance() -> UnitAppearance:
	if appearance_scene == null:
		return null
	return appearance_scene.instantiate() as UnitAppearance
