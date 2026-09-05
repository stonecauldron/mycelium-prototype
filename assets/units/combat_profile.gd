class_name CombatProfile
extends Resource

## Shared attack / engagement behaviour for player weapons and enemy unit data.
## Enums stay on WeaponData so existing call sites and .tres ints keep working.

const _DEFAULT_ARROW_PROJECTILE := "res://assets/weapons/bow/arrow_projectile.tscn"
const _DEFAULT_SPEAR_PROJECTILE := "res://assets/weapons/spear/spear_projectile.tscn"

## Minimum melee overlap box thickness (facing +X). Long weapons grow past this.
const MELEE_HITBOX_WIDTH := 28.0
const MELEE_HITBOX_HEIGHT := 100.0
const MELEE_HITBOX_Y := -20.0
## Near edge of the melee volume in unit space (after lunge). Keeps long-reach
## weapons (spears) able to connect when a PRESS_FORWARD foe closes inside tip range.
const MELEE_HITBOX_NEAR := 20.0

@export var formation_line: WeaponData.FormationLine = WeaponData.FormationLine.FRONT
@export var engagement_stance: WeaponData.EngagementStance = WeaponData.EngagementStance.FORMATION_FIGHT
@export var attack_style: WeaponData.AttackStyle = WeaponData.AttackStyle.MELEE_LUNGE
@export var damage_stat: WeaponData.DamageStat = WeaponData.DamageStat.STRENGTH
@export var damage_type: WeaponData.DamageType = WeaponData.DamageType.SLASHING
@export var targeting_mode: WeaponData.TargetingMode = WeaponData.TargetingMode.SINGLE
@export var base_damage: int = 5
## Max throw/shot distance for PROJECTILE_THROW / BOW_SHOT (and HYBRID throw band).
@export var projectile_range: float = 48.0
## Seconds between attacks. Lower = faster attacks.
@export var attack_interval: float = 0.75
## SKIRMISH: kite when an enemy is this close.
## HYBRID: switch from throw to melee at this distance.
@export var skirmish_distance: float = 80.0
@export var knockback_force: float = 280.0
## Scales total outgoing attack damage (base + stat bonus). 1.0 = normal.
@export var outgoing_damage_multiplier: float = 1.0
## Scales incoming SLASHING hit damage. 1.0 = normal. BLUNT ignores this.
@export var incoming_damage_multiplier: float = 1.0
## Scales knockback force received. 1.0 = normal.
@export var incoming_knockback_multiplier: float = 1.0
## When true, a lance charge that contacts this unit stops and deals half damage/knockback.
@export var blocks_charges: bool = false
## Center-to-center melee engage distance (facing +X). Hitbox is derived from this.
@export var melee_range: float = 96.0
## Scene spawned for PROJECTILE_THROW / BOW_SHOT. Null = style fallback.
@export var projectile_scene: PackedScene


func resolve_projectile_scene() -> PackedScene:
	if projectile_scene != null:
		return projectile_scene
	if uses_throw_projectile():
		return load(_DEFAULT_SPEAR_PROJECTILE) as PackedScene
	if attack_style == WeaponData.AttackStyle.BOW_SHOT:
		return load(_DEFAULT_ARROW_PROJECTILE) as PackedScene
	return null


func uses_throw_projectile() -> bool:
	return attack_style == WeaponData.AttackStyle.PROJECTILE_THROW


func uses_projectile() -> bool:
	return (
		uses_throw_projectile()
		or attack_style == WeaponData.AttackStyle.BOW_SHOT
	)


func is_hybrid_engagement() -> bool:
	return engagement_stance == WeaponData.EngagementStance.HYBRID


func uses_melee_hitbox() -> bool:
	return (
		attack_style == WeaponData.AttackStyle.MELEE_LUNGE
		or is_hybrid_engagement()
	)


func get_melee_hitbox_size() -> Vector2:
	return Vector2(_melee_hitbox_width(), MELEE_HITBOX_HEIGHT)


## Cover [MELEE_HITBOX_NEAR, melee_range] in unit space after the lunge completes.
## Tip-only boxes miss when enemies press inside the weapon's designed tip range.
func get_melee_hitbox_offset(lunge_distance: float) -> Vector2:
	var width := _melee_hitbox_width()
	var center_x := (MELEE_HITBOX_NEAR + melee_range) * 0.5 - lunge_distance
	# Guard short weapons so the box still reaches the tip after lunge.
	if width <= MELEE_HITBOX_WIDTH + 0.01:
		center_x = melee_range - lunge_distance - width * 0.5
	return Vector2(center_x, MELEE_HITBOX_Y)


func _melee_hitbox_width() -> float:
	return maxf(melee_range - MELEE_HITBOX_NEAR, MELEE_HITBOX_WIDTH)


static func from_weapon(weapon: WeaponData) -> CombatProfile:
	var profile := CombatProfile.new()
	if weapon == null:
		return profile
	profile.formation_line = weapon.formation_line
	profile.engagement_stance = weapon.engagement_stance
	profile.attack_style = weapon.attack_style
	profile.damage_stat = weapon.damage_stat
	profile.damage_type = weapon.damage_type
	profile.targeting_mode = weapon.targeting_mode
	profile.base_damage = weapon.base_damage
	profile.projectile_range = weapon.projectile_range
	profile.attack_interval = weapon.attack_interval
	profile.skirmish_distance = weapon.skirmish_distance
	profile.knockback_force = weapon.knockback_force
	profile.outgoing_damage_multiplier = weapon.outgoing_damage_multiplier
	profile.incoming_damage_multiplier = weapon.incoming_damage_multiplier
	profile.incoming_knockback_multiplier = weapon.incoming_knockback_multiplier
	profile.blocks_charges = weapon.blocks_charges
	profile.melee_range = weapon.melee_range
	profile.projectile_scene = weapon.projectile_scene
	return profile
