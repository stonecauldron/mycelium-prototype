class_name UnitStrain
extends Resource

const STAGE_JUVENILE := &"juvenile"
const STAGE_IMAGO := &"imago"

@export var display_name: String = "Generalist"
@export_multiline var short_description: String = ""
@export_range(0, 99, 1) var days_to_imago: int = 2
@export var life_stages: Array[StrainLifeStage] = []


func get_stage(stage_id: StringName) -> StrainLifeStage:
	for stage in life_stages:
		if stage != null and stage.id == stage_id:
			return stage
	return null


func appearance_for(stage_id: StringName) -> PackedScene:
	var stage := get_stage(stage_id)
	if stage == null:
		return null
	return stage.appearance_scene


func stage_after(stage_id: StringName) -> StrainLifeStage:
	for i in life_stages.size():
		var stage := life_stages[i]
		if stage != null and stage.id == stage_id:
			if i + 1 < life_stages.size():
				return life_stages[i + 1]
			return null
	return null


func instantiate_appearance(stage_id: StringName = STAGE_JUVENILE) -> UnitAppearance:
	var scene := appearance_for(stage_id)
	if scene == null:
		for stage in life_stages:
			if stage != null and stage.appearance_scene != null:
				scene = stage.appearance_scene
				break
	if scene == null:
		return null
	return scene.instantiate() as UnitAppearance
