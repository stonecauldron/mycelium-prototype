class_name WeaponData
extends Resource

enum FormationLine { FRONT, MID, BACK }
enum EngagementStance { REFORM, HOLD, SKIRMISH }
enum AttackStyle { MELEE_LUNGE, SPEAR_THROW, BOW_SHOT }
enum TargetingMode { SINGLE, AOE }

const SQUAD_OFFSET := {
	FormationLine.FRONT: 48.0,
	FormationLine.MID: 52.0,
	FormationLine.BACK: -140.0,
}

const FORMATION_LINE_LABELS := {
	FormationLine.FRONT: "Melee",
	FormationLine.MID: "Mid",
	FormationLine.BACK: "Ranged",
}

@export var display_name: String = ""
@export var formation_line: FormationLine = FormationLine.FRONT
@export var engagement_stance: EngagementStance = EngagementStance.REFORM
@export var attack_style: AttackStyle = AttackStyle.MELEE_LUNGE
@export var targeting_mode: TargetingMode = TargetingMode.SINGLE
@export var base_damage: int = 5
@export var attack_range: float = 48.0
## When SKIRMISH: stop attacking and retreat if an enemy is this close.
@export var skirmish_distance: float = 160.0
@export var knockback_force: float = 280.0
@export var biomass_cost: int = 5
## Scales total outgoing attack damage (base + stat bonus). 1.0 = normal.
@export var outgoing_damage_multiplier: float = 1.0
## Scales all incoming hit damage while this weapon is equipped. 1.0 = normal.
@export var incoming_damage_multiplier: float = 1.0
## Scales knockback force received while this weapon is equipped. 1.0 = normal.
@export var incoming_knockback_multiplier: float = 1.0
@export var appearance_scene: PackedScene
## Card icon shown in shop/stock UI. Lives on the resource itself so it
## survives duplicate() (unlike matching on resource_path, which is cleared
## on duplicated resources).
@export var icon: Texture2D


func instantiate_appearance() -> Node2D:
	if appearance_scene == null:
		return null
	return appearance_scene.instantiate() as Node2D


func get_squad_offset(squad_index: int) -> float:
	var base: float = SQUAD_OFFSET.get(formation_line, 0.0)
	if formation_line == FormationLine.MID:
		return base * (float(squad_index) - 1.5)
	if formation_line == FormationLine.FRONT:
		# Start just past the forwardmost mid home (4 mids centered: ±1.5 steps).
		var mid_forward_extent: float = SQUAD_OFFSET[FormationLine.MID] * 1.5
		return mid_forward_extent + base * float(squad_index + 1)
	if base == 0.0:
		return 0.0
	return base * float(squad_index + 1)
