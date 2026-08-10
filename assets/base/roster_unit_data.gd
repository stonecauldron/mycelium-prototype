class_name RosterUnitData
extends Resource

## Natural (untrained) imago maturity bonus per stat.
const IMAGO_STAT_BONUS := 1
const DAYS_TO_IMAGO := 2
const NO_LIFE_EXPECTANCY := -1
const STAGE_JUVENILE := &"juvenile"
const STAGE_IMAGO := &"imago"
const STAGE_FULLY_EVOLVED := &"fully_evolved"

@export var display_name: String = "Unit"
## Base name without generation suffix (e.g. "Darwin"). Used for death-spore naming.
@export var lineage_name: String = ""
## 1 = founding unit (no roman suffix); 2+ → "Darwin II", …
@export var generation: int = 1
@export var stats: UnitStatsData
@export var weapon: WeaponData
@export var combat: CombatProfile
@export var enemy_unit_data: EnemyUnitData
## Body mutation slot (empty allowed). Starters begin with none.
@export var body_mutation: MutationData
## Cap mutation slot (empty allowed). Starters begin with none.
@export var cap_mutation: MutationData
@export var power_tier: UnitStatsData.PowerTier = UnitStatsData.PowerTier.COMMON
@export var days_alive: int = 0
@export var life_stage_id: StringName = STAGE_JUVENILE
@export var is_imago: bool = false
## Ordered weapon-school trainings (0–2). Lookup treats as unordered multiset.
@export var weapon_trainings: Array[int] = []
## -1 = no age-out death.
@export var max_days_alive: int = NO_LIFE_EXPECTANCY
## Banked biomass for Piñata-style mutations (Bank Cap).
@export var biomass_bank: int = 0
## Biomass paid out on the most recent Bank Cap death; used by UI / day summary.
var last_death_biomass_yield: int = 0
## Set when this unit's true death emitted a lineage spore (day summary).
var emitted_death_spore: bool = false
## When set, overrides weapon engagement stance in combat (Amok fertiliser).
@export var forced_engagement_stance: int = -1
## Zombie Cap: true after the one-time combat respawn.
@export var has_revived: bool = false
## Favourite Child seal: permanent 1.5x ATK/HP from first hatch of a day.
@export var favourite_child_buff: bool = false
## Baked cocoon duration in days (−1 = use WeaponSchool.COCOON_DURATION_DAYS).
@export var cocoon_duration_days: int = -1
## Multiplier for pupation school stat gains (Cocooning fertiliser).
@export var pupation_stat_multiplier: int = 1
## Flat −all stats applied each day while in troop (Stimulants).
@export var daily_stat_decay: int = 0
## One-shot +all stats granted on promote_to_imago (Late Bloomer).
@export var pending_adult_stat_bonus: int = 0
## Fertilizers applied in the nursery plot that produced this unit (display / lineage).
@export var applied_fertilizers: Array[FertilizerData] = []


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


func call_mutation_effects(method_name: StringName, args: Array = []) -> void:
	if body_mutation != null:
		body_mutation.call_effect(method_name, args)
	if cap_mutation != null:
		cap_mutation.call_effect(method_name, args)


## Hatch / day / imago / death hooks for Body/Cap mutations.
func call_lifecycle_effect(method_name: StringName, args: Array = []) -> void:
	call_mutation_effects(method_name, args)


func call_combat_effect(method_name: StringName, args: Array = []) -> void:
	call_mutation_effects(method_name, args)
	if enemy_unit_data != null:
		enemy_unit_data.call_effect(method_name, args)


func get_identity_stat_chip() -> Dictionary:
	if cap_mutation != null:
		var cap_info := cap_mutation.get_stat_chip(self)
		if not cap_info.is_empty():
			return cap_info
	if body_mutation != null:
		var body_info := body_mutation.get_stat_chip(self)
		if not body_info.is_empty():
			return body_info
	return {}


func mutation_summary_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	if body_mutation != null:
		lines.append(
			"Body: %s — %s" % [body_mutation.display_name, body_mutation.subtitle_text()]
		)
	else:
		lines.append("Body: —")
	if cap_mutation != null:
		lines.append(
			"Cap: %s — %s" % [cap_mutation.display_name, cap_mutation.subtitle_text()]
		)
	else:
		lines.append("Cap: —")
	return lines


func is_fully_evolved() -> bool:
	return life_stage_id == STAGE_FULLY_EVOLVED


func is_adult_stage() -> bool:
	return is_imago or is_fully_evolved()


func can_promote_to_imago() -> bool:
	if is_imago or is_fully_evolved():
		return false
	return days_alive >= DAYS_TO_IMAGO


func has_exceeded_life_expectancy() -> bool:
	return max_days_alive >= 0 and days_alive > max_days_alive


## Natural age / pupation promotion. Applies +1-all and Scythe if untrained.
## Maturity bonuses scale with generation (same falloff as pupation training gains).
func promote_to_imago(apply_maturity_stats: bool = true) -> bool:
	if is_imago or is_fully_evolved():
		return false
	if apply_maturity_stats and stats != null:
		var bonus := maturity_stat_bonus()
		stats.strength = clampi(stats.strength + bonus, 1, 99)
		stats.dex = clampi(stats.dex + bonus, 1, 99)
		stats.con = clampi(stats.con + bonus, 1, 99)
		stats.spd = clampi(stats.spd + bonus, 1, 99)
	_apply_pending_adult_stat_bonus()
	life_stage_id = STAGE_IMAGO
	is_imago = true
	sync_weapon_from_trainings()
	call_lifecycle_effect(&"on_imago", [self])
	return true


func _apply_pending_adult_stat_bonus() -> void:
	if pending_adult_stat_bonus == 0 or stats == null:
		return
	var bonus := pending_adult_stat_bonus
	pending_adult_stat_bonus = 0
	stats.strength = clampi(stats.strength + bonus, 1, 99)
	stats.dex = clampi(stats.dex + bonus, 1, 99)
	stats.con = clampi(stats.con + bonus, 1, 99)
	stats.spd = clampi(stats.spd + bonus, 1, 99)


## Cocoon wait in days. 0 or less means instant emerge on place.
func effective_cocoon_days() -> int:
	if cocoon_duration_days >= 0:
		return cocoon_duration_days
	return WeaponSchool.COCOON_DURATION_DAYS


## Scaled IMAGO_STAT_BONUS for this unit's generation (toward zero).
func maturity_stat_bonus() -> int:
	return WeaponSchool.scale_stat_delta(IMAGO_STAT_BONUS, generation)


## Legacy alias — Adult/Evolved collapsed; dual training no longer uses a separate stage.
func promote_to_fully_evolved() -> bool:
	if is_fully_evolved():
		life_stage_id = STAGE_IMAGO
		is_imago = true
		return true
	return promote_to_imago(false)


func can_pupate() -> bool:
	if enemy_unit_data != null:
		return false
	return life_stage_id == STAGE_JUVENILE


func sync_weapon_from_trainings() -> void:
	if enemy_unit_data != null:
		return
	weapon = WeaponSchool.resolve_weapon(weapon_trainings, is_adult_stage())
	ensure_combat_profile()


## Apply one school training from pupation emerge. Returns false if illegal.
## At 2 trainings, evicts oldest (weapon list only; prior school stats stay).
func apply_pupation_training(school: int) -> bool:
	if not can_pupate():
		return false
	if school < 0 or school >= WeaponSchool.COUNT:
		return false
	if weapon_trainings.size() >= 2:
		weapon_trainings.pop_front()
	WeaponSchool.apply_school_stats(stats, school, generation, pupation_stat_multiplier)
	weapon_trainings.append(school)
	promote_to_imago(false)
	sync_weapon_from_trainings()
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
	else:
		# Composed base + body + cap appearance.
		appearance = UnitAppearance.compose_player(
			is_adult_stage(),
			body_mutation,
			cap_mutation
		)
	if appearance == null:
		return null
	host.add_child(appearance)
	# Portrait scale is a host-local multiply; avoid reset_body_scale() on portraits.
	appearance.scale *= Vector2(portrait_scale, portrait_scale)
	if enemy_unit_data == null:
		# Tier multiplies body and cap layers (per-layer tints stay on sprites/cap).
		appearance.modulate = UnitStatsData.tint_for_tier(power_tier)
	host.set_meta("_portrait_shadow_clearance", shadow_clearance)
	_ensure_portrait_host_sync(host)
	_sync_portrait_in_host(host)
	var held: WeaponData = null
	if enemy_unit_data != null:
		if enemy_unit_data.show_held_weapon:
			held = enemy_unit_data.held_weapon
	else:
		held = weapon
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
	unit_tier: UnitStatsData.PowerTier = UnitStatsData.PowerTier.COMMON
) -> RosterUnitData:
	var data := RosterUnitData.new()
	data.display_name = unit_name
	data.lineage_name = unit_name
	data.generation = 1
	data.stats = unit_stats
	data.weapon = unit_weapon
	if unit_weapon != null:
		data.combat = unit_weapon.get_combat_profile()
	data.power_tier = unit_tier
	data.days_alive = 0
	data.life_stage_id = STAGE_JUVENILE
	data.is_imago = false
	data.weapon_trainings = []
	data.max_days_alive = NO_LIFE_EXPECTANCY
	return data


static func create_enemy(
	unit_name: String,
	unit_stats: UnitStatsData,
	unit_data: EnemyUnitData
) -> RosterUnitData:
	var data := RosterUnitData.new()
	data.display_name = unit_name
	data.lineage_name = unit_name
	data.generation = 1
	data.stats = unit_stats
	data.enemy_unit_data = unit_data
	data.weapon = null
	if unit_data != null:
		data.combat = unit_data.get_combat_profile()
	data.power_tier = UnitStatsData.PowerTier.COMMON
	data.days_alive = 0
	data.life_stage_id = &""
	data.is_imago = false
	data.weapon_trainings = []
	data.max_days_alive = NO_LIFE_EXPECTANCY
	return data
