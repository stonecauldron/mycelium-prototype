class_name RosterUnitData
extends Resource

const IMAGO_STAT_BONUS := 2
const _DEFAULT_STRAIN_PATH := "res://assets/units/generalist/generalist_strain.tres"
const NO_LIFE_EXPECTANCY := -1

@export var display_name: String = "Unit"
@export var stats: UnitStatsData
@export var weapon: WeaponData
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


func get_formation_line() -> WeaponData.FormationLine:
	if weapon == null:
		return WeaponData.FormationLine.FRONT
	return weapon.formation_line


func get_attack_style() -> WeaponData.AttackStyle:
	if weapon == null:
		return WeaponData.AttackStyle.MELEE_LUNGE
	return weapon.attack_style


func get_damage_stat() -> WeaponData.DamageStat:
	if weapon == null:
		return WeaponData.DamageStat.STRENGTH
	return weapon.damage_stat


func get_engagement_stance() -> WeaponData.EngagementStance:
	if forced_engagement_stance >= 0:
		return forced_engagement_stance as WeaponData.EngagementStance
	if weapon == null:
		return WeaponData.EngagementStance.FORMATION_FIGHT
	return weapon.engagement_stance


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
	if host == null or strain == null:
		return null
	var appearance := strain.instantiate_appearance(life_stage_id)
	if appearance == null:
		return null
	host.add_child(appearance)
	appearance.scale *= Vector2(portrait_scale, portrait_scale)
	appearance.modulate = UnitStatsData.tint_for_tier(power_tier)
	host.set_meta("_portrait_shadow_clearance", shadow_clearance)
	_ensure_portrait_host_sync(host)
	_sync_portrait_in_host(host)
	appearance.mount_weapon_appearance(weapon)
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
	for child in host.get_children():
		if child is UnitAppearance:
			var appearance := child as UnitAppearance
			var bottom_pad := 4.0
			if shadow_clearance > 0.0:
				# Feet-pivoted: origin at soles; shadow extends below +Y.
				bottom_pad = maxf(shadow_clearance * appearance.scale.y, 16.0)
			appearance.position = Vector2(
				host.size.x * 0.5,
				host.size.y - bottom_pad
			)


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
	data.strain = unit_strain if unit_strain != null else _default_strain()
	data.power_tier = unit_tier
	data.days_alive = 0
	data.life_stage_id = UnitStrain.STAGE_JUVENILE
	data.is_imago = false
	if data.strain != null:
		data.max_days_alive = data.strain.roll_max_days_alive()
	return data


static func _default_strain() -> UnitStrain:
	# load() (not preload): strain.tres → appearance → Unit would cycle at compile time.
	return load(_DEFAULT_STRAIN_PATH) as UnitStrain
