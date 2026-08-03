class_name RosterUnitData
extends Resource

const IMAGO_STAT_BONUS := 2
const _DEFAULT_STRAIN_PATH := "res://assets/units/generalist/generalist_strain.tres"
const NO_LIFE_EXPECTANCY := -1

@export var display_name: String = "Unit"
@export var stats: UnitStatsData
@export var weapon: WeaponData
@export var combat: CombatProfile
@export var enemy_unit_data: EnemyUnitData
@export var strain: UnitStrain
@export var power_tier: UnitStatsData.PowerTier = UnitStatsData.PowerTier.COMMON
@export var days_alive: int = 0
@export var life_stage_id: StringName = &"juvenile"
@export var is_imago: bool = false
## -1 = no age-out death.
@export var max_days_alive: int = NO_LIFE_EXPECTANCY
## Banked biomass for Piñata-style strains.
@export var biomass_bank: int = 0
## Biomass paid out on the most recent strain death (Bank Cap); used by UI / day summary.
var last_death_biomass_yield: int = 0
## When set, overrides weapon engagement stance in combat (Amok fertiliser).
@export var forced_engagement_stance: int = -1
## Zombie Cap: true after the one-time combat respawn.
@export var has_revived: bool = false


func resolve_combat_profile() -> CombatProfile:
	if enemy_unit_data != null:
		return enemy_unit_data.get_combat_profile()
	if weapon != null:
		return weapon.get_combat_profile()
	if combat != null:
		return combat
	return CombatProfile.new()


## Always re-sync from weapon / enemy data so equip/unequip cannot leave a stale profile.
func ensure_combat_profile() -> CombatProfile:
	combat = resolve_combat_profile()
	return combat


func get_formation_line() -> WeaponData.FormationLine:
	return ensure_combat_profile().formation_line


func get_attack_style() -> WeaponData.AttackStyle:
	return ensure_combat_profile().attack_style


func get_damage_stat() -> WeaponData.DamageStat:
	return ensure_combat_profile().damage_stat


func get_engagement_stance() -> WeaponData.EngagementStance:
	if forced_engagement_stance >= 0:
		return forced_engagement_stance as WeaponData.EngagementStance
	return ensure_combat_profile().engagement_stance


func call_combat_effect(method_name: StringName, args: Array = []) -> void:
	if strain != null:
		strain.call_effect(method_name, args)
		return
	if enemy_unit_data != null:
		enemy_unit_data.call_effect(method_name, args)


func can_promote_to_imago() -> bool:
	if is_imago or strain == null:
		return false
	return days_alive >= strain.days_to_imago


func has_exceeded_life_expectancy() -> bool:
	return max_days_alive >= 0 and days_alive > max_days_alive


func promote_to_imago() -> bool:
	if is_imago:
		return false
	if stats != null:
		stats.strength = clampi(stats.strength + IMAGO_STAT_BONUS, 1, 99)
		stats.dex = clampi(stats.dex + IMAGO_STAT_BONUS, 1, 99)
		stats.con = clampi(stats.con + IMAGO_STAT_BONUS, 1, 99)
		stats.spd = clampi(stats.spd + IMAGO_STAT_BONUS, 1, 99)
		if strain != null and strain.imago_stat_delta != 0:
			var d := strain.imago_stat_delta
			stats.strength = clampi(stats.strength + d, 1, 99)
			stats.dex = clampi(stats.dex + d, 1, 99)
			stats.con = clampi(stats.con + d, 1, 99)
			stats.spd = clampi(stats.spd + d, 1, 99)
	life_stage_id = UnitStrain.STAGE_IMAGO
	is_imago = true
	if strain != null:
		strain.call_effect(&"on_imago", [self])
	return true


## shadow_clearance: detail-card only — space below feet for ground shadow (scaled).
## Leave 0 for compact UnitCard / day-summary portraits (feet near clip bottom).
func mount_portrait(
	host: Control,
	portrait_scale: float = 0.55,
	shadow_clearance: float = 0.0
) -> UnitAppearance:
	if host == null:
		return null
	var appearance: UnitAppearance = null
	if enemy_unit_data != null:
		appearance = enemy_unit_data.instantiate_appearance()
	elif strain != null:
		appearance = strain.instantiate_appearance(life_stage_id)
	if appearance == null:
		return null
	host.add_child(appearance)
	appearance.scale *= Vector2(portrait_scale, portrait_scale)
	appearance.modulate = UnitStatsData.tint_for_tier(power_tier)
	host.set_meta("_portrait_shadow_clearance", shadow_clearance)
	_ensure_portrait_host_sync(host)
	_sync_portrait_in_host(host)
	var held := enemy_unit_data.held_weapon if enemy_unit_data != null else weapon
	if held != null:
		appearance.mount_weapon_appearance(held)
	appearance.play_idle(true)
	return appearance


static func _ensure_portrait_host_sync(host: Control) -> void:
	if host.has_meta("_portrait_sync"):
		return
	var sync := func() -> void:
		_sync_portrait_in_host(host)
	host.set_meta("_portrait_sync", sync)
	host.resized.connect(sync)


static func _sync_portrait_in_host(host: Control) -> void:
	if not is_instance_valid(host):
		return
	var shadow_clearance := 0.0
	if host.has_meta("_portrait_shadow_clearance"):
		shadow_clearance = float(host.get_meta("_portrait_shadow_clearance"))
	## 1.0 = feet at bottom (default). Lower values raise the portrait (e.g. 0.72 for scout).
	var y_factor := 1.0
	if host.has_meta("_portrait_y_factor"):
		y_factor = clampf(float(host.get_meta("_portrait_y_factor")), 0.0, 1.0)
	for child in host.get_children():
		if child is UnitAppearance:
			var appearance := child as UnitAppearance
			var bottom_pad := 4.0
			if shadow_clearance > 0.0:
				# Feet-pivoted: origin at soles; shadow extends below +Y.
				bottom_pad = maxf(shadow_clearance * absf(appearance.scale.y), 16.0)
			var feet_y := host.size.y * y_factor - bottom_pad
			appearance.position = Vector2(host.size.x * 0.5, feet_y)


static func create(
	unit_name: String,
	unit_stats: UnitStatsData,
	unit_weapon: WeaponData,
	unit_strain: UnitStrain = null,
	unit_tier: UnitStatsData.PowerTier = UnitStatsData.PowerTier.COMMON
) -> RosterUnitData:
	var data := RosterUnitData.new()
	data.display_name = unit_name
	data.stats = unit_stats
	data.weapon = unit_weapon
	if unit_weapon != null:
		data.combat = unit_weapon.get_combat_profile()
	data.strain = unit_strain if unit_strain != null else _default_strain()
	data.power_tier = unit_tier
	data.days_alive = 0
	data.life_stage_id = UnitStrain.STAGE_JUVENILE
	data.is_imago = false
	if data.strain != null:
		data.max_days_alive = data.strain.roll_max_days_alive()
	return data


static func create_enemy(
	unit_name: String,
	unit_stats: UnitStatsData,
	unit_data: EnemyUnitData,
	unit_tier: UnitStatsData.PowerTier = UnitStatsData.PowerTier.FEEBLE
) -> RosterUnitData:
	var data := RosterUnitData.new()
	data.display_name = unit_name
	data.stats = unit_stats
	data.enemy_unit_data = unit_data
	data.weapon = null
	data.strain = null
	if unit_data != null:
		data.combat = unit_data.get_combat_profile()
	data.power_tier = unit_tier
	data.days_alive = 0
	data.life_stage_id = &""
	data.is_imago = false
	data.max_days_alive = NO_LIFE_EXPECTANCY
	return data


static func _default_strain() -> UnitStrain:
	# load() (not preload): strain.tres → appearance → Unit would cycle at compile time.
	return load(_DEFAULT_STRAIN_PATH) as UnitStrain
