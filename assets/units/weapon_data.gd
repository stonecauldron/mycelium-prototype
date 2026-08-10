class_name WeaponData
extends Resource

enum FormationLine { FRONT, MID, BACK }
enum EngagementStance { FORMATION_FIGHT, PRESS_FORWARD, HOLD_LINE, SKIRMISH, HYBRID, LANCE_CHARGE }
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

## Shared melee overlap box thickness (facing +X). Independent of WeaponMount art.
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
@export var biomass_cost: int = 3
## Biomass granted to the player each time this weapon lands a hit. 0 = none.
@export var biomass_on_hit: int = 0
## Scales total outgoing attack damage (base + stat bonus). 1.0 = normal.
@export var outgoing_damage_multiplier: float = 1.0
## Scales incoming SLASHING hit damage while equipped. 1.0 = normal.
## BLUNT ignores this (shield tanking does not apply).
@export var incoming_damage_multiplier: float = 1.0
## Scales knockback force received while this weapon is equipped. 1.0 = normal.
@export var incoming_knockback_multiplier: float = 1.0
## When true, a lance charge that contacts this unit stops and deals half damage/knockback.
@export var blocks_charges: bool = false
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

var _combat_profile_cache: CombatProfile = null


func instantiate_appearance() -> Node2D:
	if appearance_scene == null:
		return null
	return appearance_scene.instantiate() as Node2D


## Adapter so Unit can share CombatProfile with EnemyUnitData without rewriting .tres.
func get_combat_profile() -> CombatProfile:
	if _combat_profile_cache == null:
		_combat_profile_cache = CombatProfile.from_weapon(self)
	return _combat_profile_cache


func resolve_projectile_scene() -> PackedScene:
	return get_combat_profile().resolve_projectile_scene()


func uses_throw_projectile() -> bool:
	return get_combat_profile().uses_throw_projectile()


func uses_projectile() -> bool:
	return get_combat_profile().uses_projectile()


func is_hybrid_engagement() -> bool:
	return get_combat_profile().is_hybrid_engagement()


## True when this weapon can enable the unit-owned melee hitbox.
func uses_melee_hitbox() -> bool:
	return get_combat_profile().uses_melee_hitbox()


func get_melee_hitbox_size() -> Vector2:
	return get_combat_profile().get_melee_hitbox_size()


## Place the box so its forward edge after `lunge_distance` lands at `melee_range`.
func get_melee_hitbox_offset(lunge_distance: float) -> Vector2:
	return get_combat_profile().get_melee_hitbox_offset(lunge_distance)
