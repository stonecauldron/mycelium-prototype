class_name HitboxComponent
extends Area2D

signal charge_ended

@export var damage: int = 0
@export var knockback_force: float = 0.0
@export var owner_unit: Unit

const MAX_CHARGE_UNIT_HITS := 3

var _targeting_mode: WeaponData.TargetingMode = WeaponData.TargetingMode.SINGLE
var _damage_type: WeaponData.DamageType = WeaponData.DamageType.SLASHING
var _hit_combatants: Dictionary = {}
var _is_charge_strike: bool = false
var _charge_unit_hits: int = 0
var _charge_active: bool = false


func _ready() -> void:
	monitoring = false
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func enable_for_attack(
	attack_damage: int,
	attack_knockback: float,
	targeting_mode: WeaponData.TargetingMode,
	damage_type: WeaponData.DamageType = WeaponData.DamageType.SLASHING,
	is_charge_strike: bool = false
) -> void:
	damage = attack_damage
	knockback_force = attack_knockback
	_targeting_mode = targeting_mode
	_damage_type = damage_type
	_is_charge_strike = is_charge_strike
	_charge_unit_hits = 0
	_hit_combatants.clear()
	monitoring = true
	_charge_active = is_charge_strike
	if is_charge_strike:
		# Catch anything already overlapping when the rush starts.
		call_deferred("poll_charge_overlaps")


func disable() -> void:
	if monitoring and not _is_charge_strike:
		_resolve_hits()
	# Must defer: disable() can run from area_entered → charge_ended → finish_attack.
	set_deferred("monitoring", false)
	_charge_active = false
	_is_charge_strike = false
	_hit_combatants.clear()
	_charge_unit_hits = 0


func _on_area_entered(area: Area2D) -> void:
	if not _charge_active or not _is_charge_strike or not monitoring:
		return
	_try_charge_hit(area)


func poll_charge_overlaps() -> void:
	if not _charge_active or not monitoring:
		return
	for area in get_overlapping_areas():
		_try_charge_hit(area)


func _try_charge_hit(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox == null:
		return
	var target := _get_valid_target(hurtbox, false)
	if target == null:
		return
	if _hit_combatants.has(target):
		return

	var hit_damage := damage
	var hit_knockback := knockback_force
	var end_charge := false

	if target is FlagBearer:
		end_charge = true
	elif target is Unit:
		var unit := target as Unit
		if unit.combat != null and unit.combat.blocks_charges:
			hit_damage = maxi(roundi(float(damage) * 0.5), 0)
			hit_knockback = knockback_force * 0.5
			end_charge = true
		else:
			_charge_unit_hits += 1
			if _charge_unit_hits >= MAX_CHARGE_UNIT_HITS:
				end_charge = true

	_hit_combatants[target] = true
	var from_pos := owner_unit.global_position if owner_unit != null else global_position
	hurtbox.receive_hit(hit_damage, from_pos, hit_knockback, owner_unit, _damage_type)
	if owner_unit != null:
		owner_unit.grant_hit_biomass(target as Node2D)
		if owner_unit.roster_data != null:
			owner_unit.roster_data.call_combat_effect(
				&"on_hit_dealt",
				[owner_unit, target, hit_damage]
			)
	if end_charge:
		_charge_active = false
		# Defer so finish_attack → disable() is not inside area_entered.
		call_deferred("_emit_charge_ended")


func _emit_charge_ended() -> void:
	charge_ended.emit()


func _resolve_hits() -> void:
	if _targeting_mode == WeaponData.TargetingMode.AOE:
		for area in get_overlapping_areas():
			_apply_hit_to_area(area)
		return

	_hit_single_target()


func _hit_single_target() -> void:
	var closest_unit: HurtboxComponent = null
	var closest_unit_distance := INF
	var flag_hurtboxes: Array[HurtboxComponent] = []

	for area in get_overlapping_areas():
		var hurtbox := area as HurtboxComponent
		var target := _get_valid_target(hurtbox, false)
		if target == null:
			continue
		if target is FlagBearer:
			flag_hurtboxes.append(hurtbox)
			continue
		var distance := owner_unit.global_position.distance_squared_to(
			(target as Node2D).global_position
		)
		if distance < closest_unit_distance:
			closest_unit_distance = distance
			closest_unit = hurtbox

	# Prefer a unit for the single-target slot; flag always gets hit if present.
	if closest_unit != null:
		_apply_hit(closest_unit)
	for hurtbox in flag_hurtboxes:
		_apply_hit(hurtbox)


func _apply_hit_to_area(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if _get_valid_target(hurtbox, false) == null:
		return
	_apply_hit(hurtbox)


func _apply_hit(hurtbox: HurtboxComponent) -> void:
	var target := hurtbox.get_combatant()
	if target == null or _hit_combatants.has(target):
		return
	_hit_combatants[target] = true
	var from_pos := owner_unit.global_position if owner_unit != null else global_position
	hurtbox.receive_hit(damage, from_pos, knockback_force, owner_unit, _damage_type)
	if owner_unit != null:
		owner_unit.grant_hit_biomass(target as Node2D)
		if owner_unit.roster_data != null:
			owner_unit.roster_data.call_combat_effect(
				&"on_hit_dealt",
				[owner_unit, target, damage]
			)


func _get_valid_target(hurtbox: HurtboxComponent, allow_allies: bool) -> Node:
	if hurtbox == null or owner_unit == null:
		return null

	var target: Node = hurtbox.get_combatant()
	if target == null or target == owner_unit:
		return null
	if target.has_method("is_combat_obstacle") and target.call("is_combat_obstacle"):
		if _hit_combatants.has(target):
			return null
		# Friendly walls are not valid hit targets.
		var owner_troop: Troop = owner_unit._troop
		if owner_troop != null and bool(target.get("is_enemy")) == owner_troop.is_enemy:
			return null
		return target
	if not allow_allies and _is_ally(target):
		return null
	if _hit_combatants.has(target):
		return null
	return target


func _is_ally(target: Node) -> bool:
	var owner_troop: Troop = owner_unit._troop
	var target_troop := _get_troop(target)
	if owner_troop == null or target_troop == null:
		return true
	return owner_troop.is_enemy == target_troop.is_enemy


func _get_troop(target: Node) -> Troop:
	if target is Unit:
		return (target as Unit)._troop
	if target is FlagBearer:
		return (target as FlagBearer).get_parent() as Troop
	return null
