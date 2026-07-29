class_name WeaponData
extends Resource

enum FormationLine { FRONT, MID, BACK }
enum EngagementStance { FORMATION_FIGHT, CHARGE, HOLD_LINE, SKIRMISH, HYBRID }
enum AttackStyle { MELEE_LUNGE, PROJECTILE_THROW, BOW_SHOT }
enum TargetingMode { SINGLE, AOE }
## Which unit stat feeds this weapon's damage bonus (independent of attack style / line).
enum DamageStat { STRENGTH, DEX, FINESSE }
enum DamageType { SLASHING, BLUNT }

const FORMATION_LINE_LABELS := {
	FormationLine.FRONT: "Melee",
	FormationLine.MID: "Mid",
	FormationLine.BACK: "Ranged",
}

const DAMAGE_STAT_LABELS := {
	DamageStat.STRENGTH: "STR",
	DamageStat.DEX: "DEX",
	DamageStat.FINESSE: "STR or DEX",
}

## Shared melee overlap box thickness (facing +X). Independent of strain WeaponMount art.
const MELEE_HITBOX_WIDTH := 28.0
const MELEE_HITBOX_HEIGHT := 100.0
const MELEE_HITBOX_Y := -20.0

@export var display_name: String = ""
@export_multiline var short_description: String = ""
@export var formation_line: FormationLine = FormationLine.FRONT
@export var engagement_stance: EngagementStance = EngagementStance.FORMATION_FIGHT
@export var attack_style: AttackStyle = AttackStyle.MELEE_LUNGE
## Stat used for outgoing damage bonus. Not tied to formation line or attack style.
@export var damage_stat: DamageStat = DamageStat.STRENGTH
@export var damage_type: DamageType = DamageType.SLASHING
@export var targeting_mode: TargetingMode = TargetingMode.SINGLE
@export var base_damage: int = 5
## Max throw/shot distance for PROJECTILE_THROW / BOW_SHOT (and HYBRID throw band).
@export var projectile_range: float = 48.0
## Seconds between attacks before SPD scaling. Lower = faster attacks.
@export var attack_interval: float = 0.75
## SKIRMISH: kite when an enemy is this close.
## HYBRID: switch from throw to melee at this distance.
@export var skirmish_distance: float = 160.0
@export var knockback_force: float = 280.0
@export var biomass_cost: int = 5
## Scales total outgoing attack damage (base + stat bonus). 1.0 = normal.
@export var outgoing_damage_multiplier: float = 1.0
## Scales all incoming hit damage while this weapon is equipped. 1.0 = normal.
@export var incoming_damage_multiplier: float = 1.0
## Scales knockback force received while this weapon is equipped. 1.0 = normal.
@export var incoming_knockback_multiplier: float = 1.0
## Center-to-center melee engage distance (facing +X). Hitbox is derived from this.
## Pure MELEE_LUNGE uses this as attack start range; HYBRID uses it for close stick range
## while projectile_range stays the throw/shot range.
@export var melee_range: float = 96.0
## Scene spawned for PROJECTILE_THROW / BOW_SHOT. Null = style fallback (spear/bow defaults).
@export var projectile_scene: PackedScene
@export var appearance_scene: PackedScene
## Card icon shown in shop/stock UI. Lives on the resource itself so it
## survives duplicate() (unlike matching on resource_path, which is cleared
## on duplicated resources).
@export var icon: Texture2D

const _DEFAULT_ARROW_PROJECTILE := "res://assets/weapons/bow/arrow_projectile.tscn"
const _DEFAULT_SPEAR_PROJECTILE := "res://assets/weapons/spear/spear_projectile.tscn"


func instantiate_appearance() -> Node2D:
	if appearance_scene == null:
		return null
	return appearance_scene.instantiate() as Node2D


func resolve_projectile_scene() -> PackedScene:
	if projectile_scene != null:
		return projectile_scene
	if uses_throw_projectile():
		return load(_DEFAULT_SPEAR_PROJECTILE) as PackedScene
	if attack_style == AttackStyle.BOW_SHOT:
		return load(_DEFAULT_ARROW_PROJECTILE) as PackedScene
	return null


func uses_throw_projectile() -> bool:
	return attack_style == AttackStyle.PROJECTILE_THROW


func uses_projectile() -> bool:
	return (
		uses_throw_projectile()
		or attack_style == AttackStyle.BOW_SHOT
	)


func is_hybrid_engagement() -> bool:
	return engagement_stance == EngagementStance.HYBRID


## True when this weapon can enable the unit-owned melee hitbox.
func uses_melee_hitbox() -> bool:
	return (
		attack_style == AttackStyle.MELEE_LUNGE
		or is_hybrid_engagement()
	)


func get_melee_hitbox_size() -> Vector2:
	return Vector2(MELEE_HITBOX_WIDTH, MELEE_HITBOX_HEIGHT)


## Place the box so its forward edge after `lunge_distance` lands at `melee_range`.
func get_melee_hitbox_offset(lunge_distance: float) -> Vector2:
	return Vector2(
		melee_range - lunge_distance - MELEE_HITBOX_WIDTH * 0.5,
		MELEE_HITBOX_Y
	)
