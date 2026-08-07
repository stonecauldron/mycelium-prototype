class_name Unit
extends CharacterBody2D

signal died(unit: Unit)
signal health_changed(current: int, maximum: int)

enum CombatPhase { READY, APPROACHING, ATTACKING, RETURNING }
enum ChargePhase { NONE, WINDUP, RUSHING }

const BASE_MOVE_SPEED := 180.0
const RETREAT_SPEED_FACTOR := 0.5
const LANCE_CHARGE_SPEED_MULT := 3.0
const LANCE_CHARGE_MAX_DURATION := 2.5
const HOME_ARRIVE_THRESHOLD := 4.0
const WALK_SPEED_EPSILON := 8.0
## Ignore facing updates when the aim/travel delta is within this many pixels.
const FACE_FLIP_DEADZONE := 12.0
## Keep the current target unless a new one is closer by at least this much.
const TARGET_SWITCH_SLACK := 32.0
## Skirmish chase/retreat hysteresis so units don't oscillate on range edges.
const SKIRMISH_RANGE_DEADZONE := 48.0
const LUNGE_DISTANCE := 48.0
const LUNGE_OUT_TIME := 0.08
const LUNGE_BACK_TIME := 0.12
## Start melee inside max reach so retreating targets still overlap at lunge apex.
const MELEE_ENGAGE_SLACK := 18.0
const THROW_JUMP_VELOCITY := -520.0
const THROW_RELEASE_DELAY := 0.22
const THROW_RECOVERY_TIME := 0.28
const THROW_MAX_DURATION := 1.4
const THROW_WINDUP_DEG := -15.0
const THROW_STRIKE_DEG := 95.0
const THROW_WINDUP_TIME := 0.18
const THROW_STRIKE_TIME := 0.1
const THROW_SETTLE_TIME := 0.2
const THROW_AIM_JITTER_X := 40.0
const THROW_AIM_JITTER_Y := 20.0
const THROW_ORIGIN_HEIGHT := -48.0
const RANGED_RELEASE_DELAY := 0.22
const RANGED_RECOVERY_TIME := 0.42
const RANGED_ORIGIN_HEIGHT := -40.0
const BOW_AIM_LEAN_DEG := 36.0
const BOW_AIM_RELEASE_KICK_DEG := 14.0
const BOW_AIM_LEAN_TIME := 0.16
const BOW_AIM_RELEASE_TIME := 0.08
const BOW_AIM_SETTLE_TIME := 0.2
const KNOCKBACK_UP_RATIO := 0.5
const HURT_FLASH_COLOR := Color(1.0, 0.35, 0.35, 1.0)
const HURT_FLASH_TIME := 0.12
const HURT_SQUASH := Vector2(1.25, 0.75)
const HURT_SQUASH_IN := 0.04
const HURT_SQUASH_OUT := 0.12
const DEATH_POP_TIME := 0.05
const DEATH_FADE_TIME := 0.28
const DEATH_HOP := Vector2(150.0, -95.0)
const DEATH_KNOCKBACK_HOP_SCALE := 0.5
const DEATH_SPORE_MOMENTUM_SCALE := 0.7
const SHAKE_ON_HIT := 0.1
const SHAKE_ON_DEATH := 0.22
const SPORE_COLOR := Color("b7b08d")
const ENEMY_SPORE_COLOR := Color(0.85, 0.28, 0.18, 1.0)
const CALLOUT_HEIGHT := -140.0
const SWING_WINDUP_DEG := -120.0
const SWING_STRIKE_DEG := 120.0
const SWING_OUT_TIME := 0.14
const SWING_BACK_TIME := 0.18

const _DAMAGE_NUMBER_SCENE := preload("res://assets/vfx/damage_number/damage_number.tscn")
const _BIOMASS_NUMBER_SCENE := preload("res://assets/vfx/biomass_number/biomass_number.tscn")
const _HIT_BURST_SCENE := preload("res://assets/vfx/hit_burst/hit_burst.tscn")
const _SPORE_CLOUD_SCENE := preload("res://assets/vfx/spore_cloud/spore_cloud.tscn")
const _COMBAT_CALLOUT_SCENE := preload("res://assets/vfx/combat_callout/combat_callout.tscn")
const _SPEAR_PROJECTILE_FALLBACK := preload("res://assets/weapons/spear/spear_projectile.tscn")
const _ARROW_PROJECTILE_FALLBACK := preload("res://assets/weapons/bow/arrow_projectile.tscn")
const _STAT_CHIP_SCENE := preload("res://assets/ui/stat_chip/stat_chip.tscn")
const _HP_ICON := preload("res://assets/base/unit_card/hp_icon.png")
const HP_CHIP_GAP := 4.0

const COLLISION_WORLD := 1
const COLLISION_PLAYER_UNITS := 2
const COLLISION_ENEMY_UNITS := 16
const COLLISION_PLAYER_WALLS := 32
const COLLISION_ENEMY_WALLS := 64

@export var stats: UnitStatsData
@export var weapon: WeaponData
## Resolved attack behaviour (from weapon or EnemyUnitData). Set at spawn / ready.
var combat: CombatProfile = null
@export var roll_random_stats: bool = true
@export var squad_index: int = 0
@export var body_color: Color = Color.WHITE

var current_hp: int
var process_tiebreak: int = 0
var roster_data: RosterUnitData = null
var kill_streak: int = 0
var damage_dealt: int = 0
var damage_taken: int = 0
var _attack_timer: float = 0.0
var _target: Node2D
var _troop: Troop
var _combat_phase: CombatPhase = CombatPhase.READY
var _charge_phase: ChargePhase = ChargePhase.NONE
var _charge_timer: float = 0.0
var _hurt_tween: Tween
var _squash_tween: Tween
var _swing_tween: Tween
var _flip_tween: Tween
var _in_knockback: bool = false
var _knockback_left_ground: bool = false
var _throw_released: bool = false
var _throw_landed: bool = false
var _throw_left_ground: bool = false
var _throw_timer: float = 0.0
## True while a spear throw or bow shot attack is in progress (not spear melee).
var _projectile_attack_active: bool = false
var _ranged_aim: Vector2 = Vector2.ZERO
var _bow_lean_angle: float = 0.0
var _dying: bool = false
var _celebrating: bool = false
var _last_hit_from: Vector2 = Vector2.ZERO
## Runtime engagement range from weapon data (strain-invariant).
var _attack_range: float = 0.0
var _statuses: Array[StatusEffect] = []
## Combat-only modifiers (strains / statuses compose on top).
var _move_speed_multiplier: float = 1.0
var _outgoing_damage_multiplier: float = 1.0
var _blunt_resist: float = 0.0
var _incoming_knockback_multiplier: float = 1.0
var _attack_rate_multiplier: float = 1.0

@onready var _visual: Node2D = $Visual

var _hitbox: HitboxComponent = null
var _melee_hitbox: HitboxComponent = null
var _melee_hitbox_shape: RectangleShape2D = null
var _appearance: UnitAppearance = null
var _body_shape: CollisionShape2D = null
var _hp_chip: StatChip = null


func _ready() -> void:
	if roll_random_stats and stats == null:
		stats = UnitStatsData.create_random()
	elif stats != null:
		stats = stats.duplicate()

	_ensure_combat_profile()
	if combat == null:
		push_error("Unit requires a CombatProfile (via weapon or enemy unit data).")
		return

	_initialize_runtime()


func apply_power_tier(tier: UnitStatsData.PowerTier) -> void:
	_cancel_attack()
	stats = UnitStatsData.create_for_tier(tier)
	process_tiebreak = randi()
	current_hp = get_effective_max_hp()
	health_changed.emit(current_hp, get_effective_max_hp())
	_attack_timer = 0.0
	_target = null
	_combat_phase = CombatPhase.READY
	_in_knockback = false
	_knockback_left_ground = false
	kill_streak = 0
	damage_dealt = 0
	damage_taken = 0
	_apply_body_color()


func _ensure_combat_profile() -> void:
	if roster_data != null:
		if weapon == null and roster_data.weapon != null:
			weapon = roster_data.weapon
		# Prefer roster weapon over any combat assigned at spawn (may be stale).
		combat = roster_data.ensure_combat_profile()
		return
	if weapon != null:
		combat = weapon.get_combat_profile()


func _initialize_runtime() -> void:
	process_tiebreak = randi()
	damage_dealt = 0
	damage_taken = 0

	add_to_group("units")
	_troop = get_parent().get_parent() as Troop
	if _troop == null:
		push_error("Unit must be a child of Troop/Units.")
		return
	current_hp = get_effective_max_hp()
	health_changed.emit(current_hp, get_effective_max_hp())

	# Start on formation home so the army doesn't pile on the flag then fan out.
	global_position = _get_home_global()

	_setup_collision()
	_mount_appearance()
	_apply_body_color()
	_ensure_hp_chip()


func _mount_appearance() -> void:
	_clear_visual_children()
	if _body_shape != null and is_instance_valid(_body_shape):
		_body_shape.queue_free()
		_body_shape = null
	_appearance = null
	_hitbox = null

	_appearance = _instantiate_body_appearance()
	if _appearance == null:
		_configure_melee_hitbox()
		_refresh_attack_range()
		return

	_visual.add_child(_appearance)
	_visual.move_child(_appearance, 0)

	var body := _appearance.get_node_or_null("BodyShape") as CollisionShape2D
	if body != null:
		var global_xform := body.global_transform
		body.reparent(self)
		body.global_transform = global_xform
		_body_shape = body

	var held := _held_weapon_for_appearance()
	if held != null:
		_appearance.mount_weapon_appearance(held)
	_configure_melee_hitbox()
	_refresh_attack_range()
	_appearance.play_idle(true)


func _held_weapon_for_appearance() -> WeaponData:
	if roster_data != null and roster_data.enemy_unit_data != null:
		var enemy := roster_data.enemy_unit_data
		if not enemy.show_held_weapon:
			return null
		return enemy.held_weapon
	return weapon


func _instantiate_body_appearance() -> UnitAppearance:
	if roster_data != null and roster_data.enemy_unit_data != null:
		return roster_data.enemy_unit_data.instantiate_appearance()
	var strain: UnitStrain = roster_data.strain if roster_data != null else null
	if strain == null:
		# load() (not preload): breaks Unit↔strain appearance compile cycle on export.
		strain = load("res://assets/units/generalist/generalist_strain.tres") as UnitStrain
	if strain == null:
		return null
	var stage_id := UnitStrain.STAGE_JUVENILE
	if roster_data != null:
		stage_id = roster_data.life_stage_id
	return strain.instantiate_appearance(stage_id)


func _clear_visual_children() -> void:
	for child in _visual.get_children():
		if child == _melee_hitbox:
			continue
		_visual.remove_child(child)
		child.free()


func _ensure_melee_hitbox() -> void:
	if _melee_hitbox != null and is_instance_valid(_melee_hitbox):
		if _melee_hitbox.get_parent() != _visual:
			_visual.add_child(_melee_hitbox)
		return
	_melee_hitbox = HitboxComponent.new()
	_melee_hitbox.name = "MeleeHitbox"
	_melee_hitbox.collision_layer = 8
	_melee_hitbox.collision_mask = 4
	_melee_hitbox.monitoring = false
	_melee_hitbox.monitorable = false
	var shape_node := CollisionShape2D.new()
	_melee_hitbox_shape = RectangleShape2D.new()
	shape_node.shape = _melee_hitbox_shape
	_melee_hitbox.add_child(shape_node)
	_visual.add_child(_melee_hitbox)


func _configure_melee_hitbox() -> void:
	_hitbox = null
	_ensure_melee_hitbox()
	if combat == null or not combat.uses_melee_hitbox():
		_melee_hitbox.visible = false
		_melee_hitbox.monitoring = false
		return
	_melee_hitbox.visible = true
	_melee_hitbox.position = combat.get_melee_hitbox_offset(LUNGE_DISTANCE)
	if _melee_hitbox_shape == null:
		var shape_node := _melee_hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node != null:
			_melee_hitbox_shape = shape_node.shape as RectangleShape2D
	if _melee_hitbox_shape != null:
		_melee_hitbox_shape.size = combat.get_melee_hitbox_size()
	_melee_hitbox.owner_unit = self
	_hitbox = _melee_hitbox


func _refresh_attack_range() -> void:
	if combat == null:
		_attack_range = 0.0
		return
	if combat.attack_style == WeaponData.AttackStyle.MELEE_LUNGE:
		_attack_range = _get_melee_engage_range()
	else:
		_attack_range = combat.projectile_range


func _get_attack_range() -> float:
	return _attack_range


## Close-range melee reach (hitbox forward edge after lunge).
func _get_melee_range() -> float:
	if combat == null:
		return 96.0
	return combat.melee_range


## Distance at which melee commits — inside `_get_melee_range()` by MELEE_ENGAGE_SLACK.
func _get_melee_engage_range() -> float:
	return maxf(_get_melee_range() - MELEE_ENGAGE_SLACK, 1.0)

func _preferred_skirmish_distance() -> float:
	if combat == null:
		return 0.0
	var spacing := _troop.get_home_slot_spacing() if _troop != null else Troop.HOME_SLOT_SPACING
	var preferred := combat.skirmish_distance - spacing * float(squad_index)
	return clampf(preferred, SKIRMISH_RANGE_DEADZONE, combat.skirmish_distance)


func _preferred_attack_distance() -> float:
	var base := _get_attack_range()
	var skirmish := _preferred_skirmish_distance()
	var spacing := _troop.get_home_slot_spacing() if _troop != null else Troop.HOME_SLOT_SPACING
	var preferred := base - spacing * float(squad_index)
	var floor_dist := minf(skirmish + SKIRMISH_RANGE_DEADZONE, base)
	return clampf(preferred, floor_dist, base)


## HYBRID: melee when inside personal skirmish band.
## Combat obstacles are always smashed up close (projectiles fly over them).
func _wants_close_melee() -> bool:
	if _is_combat_obstacle_target(_target):
		return true
	if combat == null or get_engagement_stance() != WeaponData.EngagementStance.HYBRID:
		return false
	if _target == null or not is_instance_valid(_target):
		return false
	var distance := global_position.distance_to(_target.global_position)
	return distance <= _preferred_skirmish_distance()


func _disable_hitbox() -> void:
	if _hitbox != null:
		_hitbox.disable()


func _apply_body_color() -> void:
	if _appearance:
		_appearance.modulate = body_color


func _setup_collision() -> void:
	if _troop.is_enemy:
		collision_layer = COLLISION_ENEMY_UNITS
		collision_mask = COLLISION_WORLD | COLLISION_PLAYER_UNITS | COLLISION_PLAYER_WALLS
	else:
		collision_layer = COLLISION_PLAYER_UNITS
		collision_mask = COLLISION_WORLD | COLLISION_ENEMY_UNITS | COLLISION_ENEMY_WALLS


func _physics_process(delta: float) -> void:
	if _dying or stats == null or combat == null or _troop == null:
		return

	_tick_statuses(delta)
	velocity += get_gravity() * delta

	if _celebrating:
		if _in_knockback:
			move_and_slide()
			if not is_on_floor():
				_knockback_left_ground = true
			elif _knockback_left_ground and velocity.y >= 0.0:
				_in_knockback = false
				_knockback_left_ground = false
				velocity.x = 0.0
			_update_locomotion_animation()
			return
		_free_march_toward_enemy()
		move_and_slide()
		_update_locomotion_animation()
		return

	if _in_knockback:
		move_and_slide()
		if not is_on_floor():
			_knockback_left_ground = true
		elif _knockback_left_ground and velocity.y >= 0.0:
			_in_knockback = false
			_knockback_left_ground = false
			velocity.x = 0.0
		_update_locomotion_animation()
		return

	if _charge_phase != ChargePhase.NONE:
		_process_lance_charge(delta)
		move_and_slide()
		_update_locomotion_animation()
		return

	if _combat_phase == CombatPhase.ATTACKING:
		velocity.x = 0.0
		if _projectile_attack_active:
			if combat.uses_throw_projectile():
				_process_throw_attack(delta)
			elif combat.attack_style == WeaponData.AttackStyle.BOW_SHOT:
				_process_ranged_attack(delta)
		move_and_slide()
		_update_locomotion_animation()
		return

	_process_combat(delta)
	move_and_slide()
	_update_locomotion_animation()


func _update_locomotion_animation() -> void:
	if _appearance == null:
		return
	if (
		_dying
		or _combat_phase == CombatPhase.ATTACKING
		or _charge_phase == ChargePhase.WINDUP
		or not is_on_floor()
		or absf(velocity.x) <= WALK_SPEED_EPSILON
	):
		_appearance.play_idle(false)
		return
	_appearance.play_walk(false)


func display_name_for_errors() -> String:
	if roster_data != null and not roster_data.display_name.is_empty():
		return roster_data.display_name
	if weapon != null and not weapon.display_name.is_empty():
		return weapon.display_name
	return name


func get_move_speed(retreating: bool = false) -> float:
	var speed := BASE_MOVE_SPEED * _move_speed_multiplier * _status_move_mult()
	if retreating:
		return speed * RETREAT_SPEED_FACTOR
	return speed


func get_engagement_stance() -> WeaponData.EngagementStance:
	var stance := _configured_engagement_stance()
	# All-HOLD armies deadlock: nobody marches into range. Promote to formation
	# fight so the remaining holders advance like FORMATION_FIGHT.
	if (
		stance == WeaponData.EngagementStance.HOLD_LINE
		and _all_living_allies_hold_line()
	):
		return WeaponData.EngagementStance.FORMATION_FIGHT
	return stance


func _configured_engagement_stance() -> WeaponData.EngagementStance:
	if roster_data != null:
		return roster_data.get_engagement_stance()
	if combat != null:
		return combat.engagement_stance
	return WeaponData.EngagementStance.FORMATION_FIGHT


func _all_living_allies_hold_line() -> bool:
	if _troop == null:
		return true
	for ally in _troop.get_living_units():
		if ally._configured_engagement_stance() != WeaponData.EngagementStance.HOLD_LINE:
			return false
	return true


func notify_battle_start(context: BattleStartContext = null) -> void:
	if roster_data != null:
		roster_data.call_combat_effect(&"on_battle_start", [self, context])


func notify_battle_end() -> void:
	_celebrating = false
	if roster_data != null:
		roster_data.call_combat_effect(&"on_battle_end", [self])


## Enter celebrate-march mode; weapon toss VFX is owned by VictoryCelebrationDirector.
func begin_victory_celebration() -> void:
	if _dying or _troop == null or _troop.is_enemy:
		return
	_celebrating = true
	_cancel_attack()
	_set_held_weapon_visible(true)
	_target = null
	_charge_phase = ChargePhase.NONE
	_in_knockback = false
	_knockback_left_ground = false


func is_celebrating() -> bool:
	return _celebrating


func can_victory_toss() -> bool:
	return _celebrating and not _dying and is_inside_tree() and current_hp > 0


func get_victory_facing() -> float:
	if _troop != null:
		return _troop.get_facing()
	return 1.0


func is_player_controlled() -> bool:
	return _troop != null and not _troop.is_enemy


func get_weapon_mount_for_vfx() -> Node2D:
	return _get_weapon_mount()


func apply_status(effect: StatusEffect, replace_existing: bool = true) -> void:
	if effect == null:
		return
	if replace_existing:
		for i in range(_statuses.size() - 1, -1, -1):
			if _statuses[i].id == effect.id:
				_statuses.remove_at(i)
	_statuses.append(effect)


func _status_move_mult() -> float:
	var mult := 1.0
	for status in _statuses:
		mult *= status.move_mult
	return mult


func _status_attack_rate_mult() -> float:
	var mult := 1.0
	for status in _statuses:
		mult *= status.attack_rate_mult
	return mult


func _tick_statuses(delta: float) -> void:
	for i in range(_statuses.size() - 1, -1, -1):
		_statuses[i].remaining -= delta
		if _statuses[i].remaining <= 0.0:
			_statuses.remove_at(i)


func _free_march_toward_enemy() -> void:
	_combat_phase = CombatPhase.READY
	if _troop.march_speed <= 0.0:
		velocity.x = 0.0
		return
	var facing := _troop.get_facing()
	velocity.x = facing * get_move_speed()
	_face_march_direction()


func _process_combat(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer = maxf(_attack_timer - delta, 0.0)
		_refresh_target()
		if _target == null:
			_hold_or_march()
		elif _should_skirmish_retreat():
			_skirmish_kite_away()
		elif _should_chase():
			_chase_target()
		elif get_engagement_stance() == WeaponData.EngagementStance.SKIRMISH:
			_hold_skirmish_position()
		elif (
			get_engagement_stance() == WeaponData.EngagementStance.FORMATION_FIGHT
			or get_engagement_stance() == WeaponData.EngagementStance.LANCE_CHARGE
		):
			_return_home()
		elif get_engagement_stance() == WeaponData.EngagementStance.HOLD_LINE:
			_hold_line_position()
		elif get_engagement_stance() == WeaponData.EngagementStance.HYBRID:
			_hold_skirmish_position()
		else:
			_hold_or_march()
		return

	_refresh_target()
	if _target == null:
		_hold_or_march()
		return

	if get_engagement_stance() == WeaponData.EngagementStance.LANCE_CHARGE:
		_start_lance_windup()
		return

	var distance := global_position.distance_to(_target.global_position)
	if _should_skirmish_retreat():
		_skirmish_kite_away()
		return

	if _wants_close_melee():
		if distance <= _get_melee_engage_range():
			velocity.x = 0.0
			_face_toward(_target.global_position)
			_start_attack()
		else:
			_chase_target()
		return

	if distance <= _get_attack_range():
		# Projectiles only fire at combat units, never the flag bearer.
		# Obstacles are melee-only (they block the lane).
		if _uses_projectile_attack() and not (_target is Unit):
			if _is_combat_obstacle_target(_target):
				if distance > _get_melee_engage_range():
					_chase_target()
					return
			else:
				_hold_or_march()
				return
		velocity.x = 0.0
		_face_toward(_target.global_position)
		_start_attack()
		return

	if _should_chase():
		_chase_target()
		return

	_hold_or_march()


func _effective_attack_interval() -> float:
	var interval := combat.attack_interval if combat != null else 0.75
	var rate := 1.0
	if stats != null:
		rate = stats.get_speed_multiplier() * _attack_rate_multiplier * _status_attack_rate_mult()
	return interval / maxf(rate, 0.01)


func _start_lance_windup() -> void:
	_charge_phase = ChargePhase.WINDUP
	_charge_timer = _effective_attack_interval()
	_combat_phase = CombatPhase.ATTACKING
	velocity.x = 0.0
	if _target != null and is_instance_valid(_target):
		_face_toward(_target.global_position)


func _process_lance_charge(delta: float) -> void:
	match _charge_phase:
		ChargePhase.WINDUP:
			velocity.x = 0.0
			_refresh_target()
			if _target != null and is_instance_valid(_target):
				_face_toward(_target.global_position)
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_begin_lance_rush()
		ChargePhase.RUSHING:
			_charge_timer -= delta
			var facing := _troop.get_facing() if _troop != null else 1.0
			velocity.x = facing * get_move_speed() * LANCE_CHARGE_SPEED_MULT
			_face_march_direction()
			if _hitbox != null:
				_hitbox.poll_charge_overlaps()
			if _charge_timer <= 0.0:
				_end_lance_charge()
		_:
			_end_lance_charge()


func _begin_lance_rush() -> void:
	_charge_phase = ChargePhase.RUSHING
	_charge_timer = LANCE_CHARGE_MAX_DURATION
	if _hitbox != null:
		if not _hitbox.charge_ended.is_connected(_on_lance_charge_ended):
			_hitbox.charge_ended.connect(_on_lance_charge_ended)
		_hitbox.enable_for_attack(
			_get_attack_damage(false),
			combat.knockback_force if combat != null else 0.0,
			WeaponData.TargetingMode.SINGLE,
			combat.damage_type if combat != null else WeaponData.DamageType.SLASHING,
			true
		)


func _on_lance_charge_ended() -> void:
	if _charge_phase == ChargePhase.RUSHING:
		_end_lance_charge()


func _end_lance_charge() -> void:
	if _charge_phase == ChargePhase.NONE:
		return
	_charge_phase = ChargePhase.NONE
	_charge_timer = 0.0
	if _hitbox != null and _hitbox.charge_ended.is_connected(_on_lance_charge_ended):
		_hitbox.charge_ended.disconnect(_on_lance_charge_ended)
	_finish_attack()


func _hold_skirmish_position() -> void:
	_combat_phase = CombatPhase.READY
	velocity.x = 0.0
	if _target != null and is_instance_valid(_target):
		_face_toward(_target.global_position)


func _should_skirmish_retreat() -> bool:
	if combat == null or _target == null or not is_instance_valid(_target):
		return false
	if get_engagement_stance() != WeaponData.EngagementStance.SKIRMISH:
		return false
	var distance := global_position.distance_to(_target.global_position)
	var skirmish := _preferred_skirmish_distance()
	# Hysteresis: once kiting, keep going until clear of the danger zone.
	if _combat_phase == CombatPhase.RETURNING:
		return distance < skirmish + SKIRMISH_RANGE_DEADZONE
	return distance <= skirmish


## Kite away from the threat to the personal stand-off band — not formation home
## (home is often still inside skirmish range once the fight has closed).
func _skirmish_kite_away() -> void:
	_combat_phase = CombatPhase.RETURNING
	if _target == null or not is_instance_valid(_target):
		velocity.x = 0.0
		return
	var facing := _troop.get_facing()
	# Preferred X puts the unit at preferred_attack_distance from the target.
	var stand_x := _target.global_position.x - facing * _preferred_attack_distance()
	velocity.x = _axis_velocity(global_position.x, stand_x, get_move_speed(true))
	_face_toward(_target.global_position)


func _should_chase() -> bool:
	if combat == null or _troop == null:
		return false
	if _target == null or not is_instance_valid(_target):
		return false
	if _wants_close_melee():
		return global_position.distance_to(_target.global_position) > _get_melee_engage_range()
	match get_engagement_stance():
		WeaponData.EngagementStance.PRESS_FORWARD:
			return true
		WeaponData.EngagementStance.LANCE_CHARGE:
			return false
		WeaponData.EngagementStance.SKIRMISH, WeaponData.EngagementStance.HYBRID:
			var distance := global_position.distance_to(_target.global_position)
			var preferred := _preferred_attack_distance()
			if _combat_phase == CombatPhase.APPROACHING:
				return distance > preferred - SKIRMISH_RANGE_DEADZONE
			return distance > preferred
		WeaponData.EngagementStance.FORMATION_FIGHT, WeaponData.EngagementStance.HOLD_LINE:
			return false
		_:
			return false


func _chase_target() -> void:
	if _target == null or not is_instance_valid(_target):
		_refresh_target()
	if _target == null:
		_hold_or_march()
		return

	_combat_phase = CombatPhase.APPROACHING
	var distance := global_position.distance_to(_target.global_position)
	var stop_range := _get_attack_range()
	if _wants_close_melee():
		stop_range = _get_melee_engage_range()
	elif (
		get_engagement_stance() == WeaponData.EngagementStance.SKIRMISH
		or get_engagement_stance() == WeaponData.EngagementStance.HYBRID
	):
		var preferred := _preferred_attack_distance()
		var skirmish := _preferred_skirmish_distance()
		stop_range = maxf(skirmish + SKIRMISH_RANGE_DEADZONE, preferred - SKIRMISH_RANGE_DEADZONE)
	if distance <= stop_range:
		velocity.x = 0.0
	else:
		velocity.x = _axis_velocity(global_position.x, _target.global_position.x, get_move_speed())
	_face_toward(_target.global_position)


func _hold_or_march() -> void:
	if get_engagement_stance() == WeaponData.EngagementStance.HOLD_LINE:
		_hold_line_position()
		return
	_free_march_toward_enemy()


## HOLD_LINE: stay at formation home, but never fall behind allies with a lower
## squad_index — advance to keep HOME_SLOT_SPACING * index_delta ahead of them.
func _hold_line_position() -> void:
	_combat_phase = CombatPhase.RETURNING
	var hold := _get_hold_line_global()
	velocity.x = _axis_velocity(global_position.x, hold.x, get_move_speed())
	if _target != null and is_instance_valid(_target):
		_face_toward(_target.global_position)
	elif is_zero_approx(velocity.x):
		_face_march_direction()
	else:
		_face_travel_direction()


func _get_hold_line_global() -> Vector2:
	var home := _get_home_global()
	if _troop == null:
		return home
	var facing := _troop.get_facing()
	var target_x := home.x
	for ally in _troop.get_living_units():
		if ally == self or ally.squad_index >= squad_index:
			continue
		var spacing := _troop.get_home_slot_spacing()
		var required_x := (
			ally.global_position.x
			+ facing * spacing * float(squad_index - ally.squad_index)
		)
		if facing * (required_x - target_x) > 0.0:
			target_x = required_x
	return Vector2(target_x, home.y)


func _return_home(retreating: bool = false) -> void:
	_combat_phase = CombatPhase.RETURNING
	var home := _get_home_global()
	velocity.x = _axis_velocity(global_position.x, home.x, get_move_speed(retreating))
	# Prefer facing the threat so home overshoot doesn't reverse the sprite.
	if _target != null and is_instance_valid(_target):
		_face_toward(_target.global_position)
	elif is_zero_approx(velocity.x):
		_face_march_direction()
	else:
		_face_travel_direction()


func _start_attack() -> void:
	if _combat_phase == CombatPhase.ATTACKING:
		return

	_combat_phase = CombatPhase.ATTACKING
	if get_engagement_stance() == WeaponData.EngagementStance.HYBRID and combat.uses_throw_projectile():
		var distance := (
			global_position.distance_to(_target.global_position)
			if _target != null and is_instance_valid(_target)
			else INF
		)
		if distance <= _get_melee_engage_range():
			_start_melee_lunge_attack()
		else:
			_start_throw_attack()
		return
	if combat.uses_throw_projectile():
		_start_throw_attack()
		return
	if combat.attack_style == WeaponData.AttackStyle.BOW_SHOT:
		_start_ranged_attack()
		return

	_start_melee_lunge_attack()


func _start_melee_lunge_attack() -> void:
	if _hitbox != null:
		_hitbox.enable_for_attack(
			_get_attack_damage(false),
			combat.knockback_force,
			combat.targeting_mode,
			combat.damage_type
		)

	var direction := signf(_visual.scale.x)
	if direction == 0.0:
		direction = 1.0

	var forward := Vector2(direction * LUNGE_DISTANCE, 0.0)
	_play_melee_swing()
	var tween := create_tween()
	tween.tween_property(_visual, "position", forward, LUNGE_OUT_TIME)
	tween.tween_callback(_disable_hitbox)
	tween.tween_property(_visual, "position", Vector2.ZERO, LUNGE_BACK_TIME)
	tween.tween_callback(_finish_attack)


func _start_throw_attack() -> void:
	_projectile_attack_active = true
	_throw_released = false
	_throw_landed = false
	_throw_left_ground = false
	_throw_timer = 0.0
	velocity.y = THROW_JUMP_VELOCITY
	_play_throw_body_swing()


func _process_throw_attack(delta: float) -> void:
	_throw_timer += delta
	if not _throw_released and _throw_timer >= THROW_RELEASE_DELAY:
		_throw_released = true
		_spawn_spear_projectile()

	if not is_on_floor():
		_throw_left_ground = true
	elif _throw_released and _throw_left_ground and not _throw_landed:
		_throw_landed = true
		_throw_timer = 0.0
		_set_held_weapon_visible(true)
		_reset_throw_flip()

	if _throw_landed and _throw_timer >= THROW_RECOVERY_TIME:
		_finish_attack()
		return

	if _throw_released and _throw_timer >= THROW_MAX_DURATION:
		_finish_attack()


func _spawn_spear_projectile() -> void:
	var opponent := _troop.get_opponent() if _troop != null else null
	if opponent == null or opponent.get_living_unit_count() == 0:
		return
	var aim := _pick_ranged_aim_target(opponent)
	aim += Vector2(
		randf_range(-THROW_AIM_JITTER_X, THROW_AIM_JITTER_X),
		randf_range(-THROW_AIM_JITTER_Y, THROW_AIM_JITTER_Y)
	)
	_spawn_weapon_projectile(
		global_position + Vector2(0.0, THROW_ORIGIN_HEIGHT),
		aim
	)
	_set_held_weapon_visible(false)


func _start_ranged_attack() -> void:
	_projectile_attack_active = true
	_throw_released = false
	_throw_timer = 0.0
	_ranged_aim = _pick_ranged_aim_with_jitter()
	_play_bow_aim_lean(_ranged_aim)


func _process_ranged_attack(delta: float) -> void:
	_throw_timer += delta
	if not _throw_released and _throw_timer >= RANGED_RELEASE_DELAY:
		_throw_released = true
		_spawn_arrow_projectile()
		_release_bow_aim_lean()
		_throw_timer = 0.0
		return

	if _throw_released and _throw_timer >= RANGED_RECOVERY_TIME:
		_finish_attack()


func _pick_ranged_aim_with_jitter() -> Vector2:
	var opponent := _troop.get_opponent() if _troop != null else null
	if opponent == null or opponent.get_living_unit_count() == 0:
		return _get_forward_aim_fallback()
	var aim := _pick_ranged_aim_target(opponent)
	aim += Vector2(
		randf_range(-THROW_AIM_JITTER_X, THROW_AIM_JITTER_X),
		randf_range(-THROW_AIM_JITTER_Y, THROW_AIM_JITTER_Y)
	)
	return aim


func _get_forward_aim_fallback() -> Vector2:
	var face := signf(_visual.scale.x) if _visual != null else 1.0
	if face == 0.0:
		face = -1.0 if _troop != null and _troop.is_enemy else 1.0
	return global_position + Vector2(face * 240.0, -80.0)


func _spawn_arrow_projectile() -> void:
	var aim := _ranged_aim
	if aim == Vector2.ZERO:
		aim = _pick_ranged_aim_with_jitter()
	_spawn_weapon_projectile(_get_ranged_spawn_global(), aim)


func _spawn_weapon_projectile(from_global: Vector2, aim_global: Vector2) -> void:
	var world := _get_world_node()
	if world == null or combat == null:
		return
	var scene := combat.resolve_projectile_scene()
	if scene == null:
		if combat.uses_throw_projectile():
			scene = _SPEAR_PROJECTILE_FALLBACK
		elif combat.attack_style == WeaponData.AttackStyle.BOW_SHOT:
			scene = _ARROW_PROJECTILE_FALLBACK
	if scene == null:
		return
	var projectile := scene.instantiate() as Projectile
	if projectile == null:
		var label := display_name_for_errors()
		push_error("Combat projectile_scene must use Projectile script: %s" % label)
		return
	world.add_child(projectile)
	if projectile.homing and _target != null and is_instance_valid(_target):
		projectile.set_homing_target(_target)
	projectile.launch(
		from_global,
		aim_global,
		_get_attack_damage(true),
		combat.knockback_force,
		self
	)


func _get_ranged_spawn_global() -> Vector2:
	var mount := _get_weapon_mount()
	if mount != null:
		return mount.global_position
	return global_position + Vector2(0.0, RANGED_ORIGIN_HEIGHT)


func _play_bow_aim_lean(aim: Vector2) -> void:
	if _appearance == null or _visual == null:
		return
	if _flip_tween:
		_flip_tween.kill()
	# Windup: lean into the lobbed shot (local -angle = upward).
	_bow_lean_angle = deg_to_rad(-BOW_AIM_LEAN_DEG)
	var from_global := _get_ranged_spawn_global()
	var local_dir := _visual.to_local(aim) - _visual.to_local(from_global)
	if local_dir.length_squared() > 0.0001:
		var aim_lean := clampf(local_dir.angle(), deg_to_rad(-55.0), deg_to_rad(10.0))
		_bow_lean_angle = lerpf(_bow_lean_angle, aim_lean, 0.35)
	_appearance.rotation = 0.0
	_flip_tween = create_tween()
	_flip_tween.tween_property(
		_appearance,
		"rotation",
		_bow_lean_angle,
		BOW_AIM_LEAN_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _release_bow_aim_lean() -> void:
	if _appearance == null:
		return
	if _flip_tween:
		_flip_tween.kill()
	var lean_sign := -1.0 if _bow_lean_angle <= 0.0 else 1.0
	var release_angle := _bow_lean_angle + lean_sign * deg_to_rad(BOW_AIM_RELEASE_KICK_DEG)
	_flip_tween = create_tween()
	_flip_tween.tween_property(
		_appearance,
		"rotation",
		release_angle,
		BOW_AIM_RELEASE_TIME
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_flip_tween.tween_property(_appearance, "rotation", 0.0, BOW_AIM_SETTLE_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_callback(func() -> void:
		_flip_tween = null
	)


func _finish_attack() -> void:
	_disable_hitbox()
	_visual.position = Vector2.ZERO
	_reset_throw_flip()
	if combat != null and combat.uses_throw_projectile():
		_set_held_weapon_visible(true)
	_projectile_attack_active = false
	_throw_released = false
	_throw_landed = false
	_throw_left_ground = false
	_throw_timer = 0.0
	_charge_phase = ChargePhase.NONE
	_charge_timer = 0.0
	_attack_timer = _effective_attack_interval()
	_combat_phase = CombatPhase.RETURNING


func _cancel_attack() -> void:
	if _combat_phase != CombatPhase.ATTACKING and _charge_phase == ChargePhase.NONE:
		return
	if _hitbox != null and _hitbox.charge_ended.is_connected(_on_lance_charge_ended):
		_hitbox.charge_ended.disconnect(_on_lance_charge_ended)
	_disable_hitbox()
	_visual.position = Vector2.ZERO
	_reset_weapon_swing()
	_reset_throw_flip()
	_projectile_attack_active = false
	_throw_released = false
	_throw_landed = false
	_throw_left_ground = false
	_throw_timer = 0.0
	_charge_phase = ChargePhase.NONE
	_charge_timer = 0.0
	_combat_phase = CombatPhase.RETURNING


func _get_home_global() -> Vector2:
	# Homes follow squad slot order (anchor/flag at rear). Aim priority still uses
	# formation_line as role tags — spatial retargeting is a follow-up.
	if _troop == null:
		return global_position
	var anchor_pos := _troop.get_formation_anchor_global()
	var facing := _troop.get_facing()
	# Slot 0 stands FLAG_REAR_CLEARANCE ahead of the anchor; later slots step forward.
	var offset := (
		Troop.FLAG_REAR_CLEARANCE
		+ _troop.get_home_slot_spacing() * float(squad_index)
	)
	return Vector2(anchor_pos.x + facing * offset, anchor_pos.y)


func _axis_velocity(current: float, target: float, speed: float) -> float:
	var delta_pos := target - current
	if absf(delta_pos) <= HOME_ARRIVE_THRESHOLD:
		return 0.0
	return signf(delta_pos) * speed


func _uses_projectile_attack() -> bool:
	if combat == null:
		return false
	return combat.uses_projectile()


func _refresh_target() -> void:
	var previous := _target
	_target = null
	var opponent: Troop = _troop.get_opponent() if _troop != null else null
	var closest_distance := INF

	if opponent != null and not opponent.is_wiped_out():
		for unit in opponent.get_units():
			if unit.current_hp <= 0:
				continue
			var distance := global_position.distance_squared_to(unit.global_position)
			if distance < closest_distance:
				closest_distance = distance
				_target = unit

		# Projectile weapons never engage the flag bearer — only combat units.
		var allow_flag_target := not _uses_projectile_attack()
		if allow_flag_target:
			var flag := opponent.flag_bearer
			if flag != null and is_instance_valid(flag):
				var flag_distance := global_position.distance_squared_to(flag.global_position)
				if flag_distance < closest_distance:
					closest_distance = flag_distance
					_target = flag

	# Melee units smash combat obstacles (walls) that sit ahead of them.
	# Projectiles arc over, so ranged units keep focusing living foes.
	if not _uses_projectile_attack():
		var obstacle := _closest_blocking_obstacle()
		if obstacle != null:
			var obstacle_distance := global_position.distance_squared_to(obstacle.global_position)
			if obstacle_distance < closest_distance:
				closest_distance = obstacle_distance
				_target = obstacle

	# Sticky target: avoid left/right thrashing when two foes are nearly equidistant.
	if (
		previous != null
		and is_instance_valid(previous)
		and previous != _target
		and _is_valid_sticky_target(previous)
	):
		var previous_distance := global_position.distance_squared_to(
			(previous as Node2D).global_position
		)
		var slack_sq := TARGET_SWITCH_SLACK * TARGET_SWITCH_SLACK
		if previous_distance <= closest_distance + slack_sq:
			_target = previous
			closest_distance = previous_distance

	# Free-march until an enemy (or blocking wall) enters engage range.
	if _target != null:
		var engage_sq := Troop.ENGAGE_RANGE * Troop.ENGAGE_RANGE
		if closest_distance > engage_sq:
			_target = null


func _is_valid_sticky_target(candidate: Node) -> bool:
	if candidate is Unit:
		return (candidate as Unit).current_hp > 0
	if candidate is FlagBearer and not _uses_projectile_attack():
		return true
	if (
		not _uses_projectile_attack()
		and candidate.has_method("is_combat_obstacle")
		and candidate.call("is_combat_obstacle")
	):
		if _troop != null and bool(candidate.get("is_enemy")) == _troop.is_enemy:
			return false
		if candidate.get("current_hp") != null and int(candidate.get("current_hp")) <= 0:
			return false
		return true
	return false


func _is_combat_obstacle_target(candidate: Node) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and candidate.has_method("is_combat_obstacle")
		and candidate.call("is_combat_obstacle")
	)


## Nearest living combat obstacle ahead toward the enemy side.
func _closest_blocking_obstacle() -> Node2D:
	if not is_inside_tree() or _troop == null:
		return null
	var toward_enemy := -1.0 if _troop.is_enemy else 1.0
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("combat_obstacles"):
		if node == null or not is_instance_valid(node):
			continue
		var obstacle := node as Node2D
		if obstacle == null:
			continue
		if not obstacle.has_method("is_combat_obstacle") or not obstacle.call("is_combat_obstacle"):
			continue
		# Never engage walls from our own army.
		if bool(obstacle.get("is_enemy")) == _troop.is_enemy:
			continue
		if obstacle.get("current_hp") != null and int(obstacle.get("current_hp")) <= 0:
			continue
		var dx := obstacle.global_position.x - global_position.x
		# Only consider walls ahead on the march toward the foe.
		if dx * toward_enemy <= 0.0:
			continue
		var distance := global_position.distance_squared_to(obstacle.global_position)
		if distance < best_distance:
			best_distance = distance
			best = obstacle
	return best


func _get_ranged_aim_priority() -> Array[WeaponData.FormationLine]:
	var line := (
		combat.formation_line if combat != null else WeaponData.FormationLine.FRONT
	)
	match line:
		WeaponData.FormationLine.MID:
			return [
				WeaponData.FormationLine.FRONT,
				WeaponData.FormationLine.MID,
				WeaponData.FormationLine.BACK,
			]
		WeaponData.FormationLine.BACK:
			return [
				WeaponData.FormationLine.MID,
				WeaponData.FormationLine.FRONT,
				WeaponData.FormationLine.BACK,
			]
		_:
			return [
				WeaponData.FormationLine.FRONT,
				WeaponData.FormationLine.MID,
				WeaponData.FormationLine.BACK,
			]


func _pick_ranged_aim_target(opponent: Troop) -> Vector2:
	var from_global := _get_ranged_spawn_global()
	var projectile_range := _get_attack_range()
	for formation_line in _get_ranged_aim_priority():
		var candidates: Array[Unit] = []
		var weights: Array[float] = []
		var total_weight := 0.0
		for unit in opponent.get_living_units():
			if unit.combat == null or unit.combat.formation_line != formation_line:
				continue
			# Horizontal range only — jump height during spear throw must not
			# invalidate an otherwise valid aim target.
			var distance := absf(global_position.x - unit.global_position.x)
			if distance > projectile_range:
				continue
			candidates.append(unit)
			var weight := 1.0 / maxf(distance, 1.0)
			weights.append(weight)
			total_weight += weight
		if candidates.is_empty():
			continue

		var roll := randf() * total_weight
		var cumulative := 0.0
		for i in candidates.size():
			cumulative += weights[i]
			if roll <= cumulative:
				return _lead_aim_point(from_global, candidates[i])
		return _lead_aim_point(from_global, candidates[candidates.size() - 1])

	# Prefer any remaining combatant over flag bearer / self (floor throws).
	var closest: Unit = null
	var closest_distance := INF
	for unit in opponent.get_living_units():
		var distance := absf(global_position.x - unit.global_position.x)
		if distance < closest_distance:
			closest_distance = distance
			closest = unit
	if closest != null:
		return _lead_aim_point(from_global, closest)

	return _get_forward_aim_fallback()


## Lead aim by target velocity using an approximate ballistic flight time.
func _lead_aim_point(from_global: Vector2, target: Unit) -> Vector2:
	var aim := target.global_position
	var launch_angle_deg := 45.0
	var fallback_speed := 600.0
	if combat != null:
		var scene := combat.resolve_projectile_scene()
		if scene == null and combat.uses_throw_projectile():
			scene = _SPEAR_PROJECTILE_FALLBACK
		elif scene == null and combat.attack_style == WeaponData.AttackStyle.BOW_SHOT:
			scene = _ARROW_PROJECTILE_FALLBACK
		if scene != null:
			var probe := scene.instantiate() as Projectile
			if probe != null:
				launch_angle_deg = probe.launch_angle_deg
				fallback_speed = probe.fallback_speed
				probe.free()
	var gravity_y := get_gravity().y
	if gravity_y <= 0.0:
		gravity_y = 980.0
	for _i in 2:
		var displacement := aim - from_global
		var dx := absf(displacement.x)
		var dy := displacement.y
		var launch_angle := deg_to_rad(launch_angle_deg)
		var cos_a := cos(launch_angle)
		var tan_a := tan(launch_angle)
		var denominator := 2.0 * cos_a * cos_a * (dy + dx * tan_a)
		var speed := fallback_speed
		if denominator > 1.0:
			speed = sqrt(gravity_y * dx * dx / denominator)
		var vx := maxf(speed * cos_a, 1.0)
		var flight_t := dx / vx
		# Lead only on horizontal motion (ignore jump/knockback Y).
		aim = target.global_position + Vector2(target.velocity.x * flight_t, 0.0)
	return aim


func _get_attack_damage(is_projectile_attack: bool) -> int:
	var raw: int = combat.base_damage + stats.get_damage_bonus(combat.damage_stat)
	var mult := combat.outgoing_damage_multiplier * _outgoing_damage_multiplier
	return SealModifiers.combat_attack_damage(self, raw, mult, is_projectile_attack)


func get_effective_max_hp() -> int:
	if is_player_controlled() and roster_data != null:
		return SealModifiers.effective_max_hp(roster_data)
	if stats == null:
		return 0
	return stats.get_max_hp()


func take_damage(
	amount: int,
	knockback_from: Vector2 = Vector2.ZERO,
	knockback_force: float = 0.0,
	killer: Unit = null,
	damage_type: WeaponData.DamageType = WeaponData.DamageType.SLASHING
) -> void:
	if _dying:
		return
	var incoming_mult: float = 1.0
	var knockback_mult: float = _incoming_knockback_multiplier
	if combat != null:
		# Blunt punches through shield / tank weapon damage soak.
		if damage_type != WeaponData.DamageType.BLUNT:
			incoming_mult = combat.incoming_damage_multiplier
		knockback_mult *= combat.incoming_knockback_multiplier
	if damage_type == WeaponData.DamageType.BLUNT and _blunt_resist > 0.0:
		incoming_mult *= maxf(1.0 - _blunt_resist, 0.0)
	var pre_mitigation := amount
	amount = roundi(float(amount) * incoming_mult)
	if pre_mitigation > 0:
		amount = maxi(amount, 1)
	else:
		amount = maxi(amount, 0)
	if amount > 0:
		damage_taken += amount
		if killer != null and is_instance_valid(killer):
			killer.damage_dealt += amount
	if roster_data != null:
		roster_data.call_combat_effect(&"on_hit_taken", [self, amount, damage_type])
	_last_hit_from = knockback_from
	_play_hurt_highlight()
	_spawn_damage_number(amount)
	_spawn_hit_burst()
	_add_camera_shake(SHAKE_ON_HIT)
	current_hp = maxi(current_hp - amount, 0)
	health_changed.emit(current_hp, get_effective_max_hp())
	if _charge_phase != ChargePhase.NONE:
		_end_lance_charge()
	if current_hp <= 0:
		_die(knockback_from, knockback_force * knockback_mult, killer)
		return
	if knockback_from != Vector2.ZERO and knockback_force > 0.0:
		_apply_knockback(knockback_from, knockback_force * knockback_mult)


func grant_hit_biomass(hit_at: Node2D = null) -> void:
	if weapon == null or weapon.biomass_on_hit <= 0:
		return
	if _troop == null or _troop.is_enemy:
		return
	var amount := weapon.biomass_on_hit
	GameState.biomass.add(amount)
	var spawn_at := hit_at.global_position if hit_at != null else global_position
	var stage := _find_combat_stage()
	if stage != null:
		if stage.has_method("record_biomass_yield"):
			stage.record_biomass_yield(amount)
		elif stage.has_method("_refresh_biomass_hud"):
			stage._refresh_biomass_hud()
		if stage.has_method("_spawn_biomass_number"):
			stage._spawn_biomass_number(spawn_at, amount)
			return
	_spawn_biomass_number_at(spawn_at, amount)


func _spawn_biomass_number(amount: int) -> void:
	_spawn_biomass_number_at(global_position, amount)


func _spawn_biomass_number_at(at_global: Vector2, amount: int) -> void:
	var world := _get_world_node()
	if world == null or amount <= 0:
		return
	var number: BiomassNumber = _BIOMASS_NUMBER_SCENE.instantiate()
	world.add_child(number)
	number.global_position = at_global + Vector2(0, -128)
	number.display(amount)


func _find_combat_stage() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("_award_kill_biomass"):
			return node
		node = node.get_parent()
	return null


func register_kill(victim: Unit = null) -> void:
	if _dying or current_hp <= 0 or not is_inside_tree():
		return
	kill_streak += 1
	if roster_data != null and victim != null:
		roster_data.call_combat_effect(&"on_kill", [self, victim])
	# Enemy streaks never show — player killers only.
	if _troop == null or _troop.is_enemy:
		return
	if kill_streak < 2:
		return
	var title := _halo_title_for_streak(kill_streak)
	if title.is_empty():
		return
	var unit_name := "Unit"
	if roster_data != null and not roster_data.display_name.is_empty():
		unit_name = roster_data.display_name
	_spawn_combat_callout(
		"%s: %s" % [unit_name, title],
		CombatCallout.Kind.STREAK
	)


func _halo_title_for_streak(streak: int) -> String:
	match streak:
		2:
			return "Double Kill"
		3:
			return "Triple Kill"
		4:
			return "Overkill"
		5:
			return "Killtacular"
		6:
			return "Killtrocity"
		7:
			return "Killimanjaro"
		8:
			return "Killtastrophe"
		9:
			return "Killpocalypse"
		_:
			if streak >= 10:
				return "Killionaire"
			return ""


func _die(
	knockback_from: Vector2 = Vector2.ZERO,
	knockback_force: float = 0.0,
	killer: Unit = null
) -> void:
	if _dying:
		return
	_dying = true
	kill_streak = 0
	if killer != null and is_instance_valid(killer):
		killer.register_kill(self)

	if roster_data != null:
		roster_data.call_combat_effect(
			&"on_death",
			[roster_data, StrainEffect.DeathContext.COMBAT, self]
		)
		if roster_data.last_death_biomass_yield > 0:
			_spawn_biomass_number(roster_data.last_death_biomass_yield)
			var stage := _find_combat_stage()
			if stage != null and stage.has_method("record_biomass_yield"):
				stage.record_biomass_yield(roster_data.last_death_biomass_yield)

	died.emit(self)

	_cancel_attack()
	_in_knockback = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if _hitbox != null:
		_hitbox.monitoring = false
	_disable_hurtbox()
	if _hp_chip != null and is_instance_valid(_hp_chip):
		_hp_chip.queue_free()
		_hp_chip = null

	_add_camera_shake(SHAKE_ON_DEATH)
	if _troop != null and not _troop.is_enemy:
		_spawn_fallen_callout()

	if _hurt_tween:
		_hurt_tween.kill()
		_hurt_tween = null
	if _squash_tween:
		_squash_tween.kill()
		_squash_tween = null
	if _appearance != null:
		_appearance.reset_body_scale()
		if _appearance.animation_player != null:
			_appearance.animation_player.stop()

	var face := signf(_visual.scale.x)
	if face == 0.0:
		face = 1.0
	var hop_dir := face
	if knockback_from != Vector2.ZERO:
		_last_hit_from = knockback_from
	if _last_hit_from != Vector2.ZERO:
		var away := signf(global_position.x - _last_hit_from.x)
		if away != 0.0:
			hop_dir = away

	var hop := DEATH_HOP
	if knockback_force > 0.0:
		hop = Vector2(
			maxf(DEATH_HOP.x, knockback_force * DEATH_KNOCKBACK_HOP_SCALE),
			minf(DEATH_HOP.y, -knockback_force * DEATH_KNOCKBACK_HOP_SCALE * KNOCKBACK_UP_RATIO)
		)

	var hop_offset := Vector2(hop_dir * hop.x, hop.y)
	var spore_momentum := hop_offset / maxf(DEATH_FADE_TIME, 0.001) * DEATH_SPORE_MOMENTUM_SCALE
	var spore_delay := DEATH_FADE_TIME * 0.5

	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector2(face * 1.35, 1.35), DEATH_POP_TIME)
	tween.set_parallel(true)
	tween.tween_property(_visual, "scale", Vector2(face * 1.5, 0.18), DEATH_FADE_TIME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_visual, "modulate", Color(0.15, 0.1, 0.15, 0.0), DEATH_FADE_TIME)
	tween.tween_property(_visual, "position", hop_offset, DEATH_FADE_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_spawn_spore_cloud.bind(spore_momentum)).set_delay(spore_delay)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)


func _disable_hurtbox() -> void:
	if _appearance == null:
		return
	var hurtbox := _appearance.hurtbox
	if hurtbox == null:
		return
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("collision_layer", 0)
	hurtbox.set_deferred("collision_mask", 0)


func _apply_knockback(from_global: Vector2, knockback_force: float) -> void:
	if not is_inside_tree() or current_hp <= 0 or knockback_force <= 0.0:
		return
	var direction := signf(global_position.x - from_global.x)
	if direction == 0.0:
		direction = 1.0
	velocity.x = direction * knockback_force
	velocity.y = -knockback_force * KNOCKBACK_UP_RATIO
	_in_knockback = true
	_knockback_left_ground = false


func _play_hurt_highlight() -> void:
	if _appearance == null:
		return
	if _hurt_tween:
		_hurt_tween.kill()
	_appearance.modulate = HURT_FLASH_COLOR
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(_appearance, "modulate", body_color, HURT_FLASH_TIME)

	if _squash_tween:
		_squash_tween.kill()
	var body_scale := _appearance.get_body_scale()
	_appearance.reset_body_scale()
	_squash_tween = create_tween()
	_squash_tween.tween_property(_appearance, "scale", HURT_SQUASH * body_scale, HURT_SQUASH_IN)
	_squash_tween.tween_property(_appearance, "scale", body_scale, HURT_SQUASH_OUT)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _get_world_node() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("combat_world")


func _add_camera_shake(amount: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var camera := tree.get_first_node_in_group("battle_camera")
	if camera != null and camera.has_method("add_shake"):
		camera.add_shake(amount)


func _spawn_damage_number(amount: int) -> void:
	var world := _get_world_node()
	if world == null:
		return

	var number: DamageNumber = _DAMAGE_NUMBER_SCENE.instantiate()
	world.add_child(number)
	number.global_position = global_position + Vector2(0, -72)
	number.display(amount)


func _spawn_fallen_callout() -> void:
	var unit_name := "Unit"
	if roster_data != null and not roster_data.display_name.is_empty():
		unit_name = roster_data.display_name
	_spawn_combat_callout("%s has fallen" % unit_name, CombatCallout.Kind.FALLEN)


func _spawn_combat_callout(text: String, kind: CombatCallout.Kind) -> void:
	var world := _get_world_node()
	if world == null:
		return
	var callout: CombatCallout = _COMBAT_CALLOUT_SCENE.instantiate()
	world.add_child(callout)
	callout.global_position = global_position + Vector2(0.0, CALLOUT_HEIGHT)
	callout.display(text, kind)


func _play_melee_swing() -> void:
	var mount := _get_weapon_mount()
	if mount == null:
		return
	if _swing_tween:
		_swing_tween.kill()
	mount.rotation = deg_to_rad(SWING_WINDUP_DEG)
	_swing_tween = create_tween()
	_swing_tween.tween_property(
		mount,
		"rotation",
		deg_to_rad(SWING_STRIKE_DEG),
		SWING_OUT_TIME
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_swing_tween.tween_property(mount, "rotation", 0.0, SWING_BACK_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _reset_weapon_swing() -> void:
	if _swing_tween:
		_swing_tween.kill()
		_swing_tween = null
	var mount := _get_weapon_mount()
	if mount != null:
		mount.rotation = 0.0


func _play_throw_body_swing() -> void:
	if _appearance == null:
		return
	if _flip_tween:
		_flip_tween.kill()
	# Rotate the appearance under `_visual` so `_visual.scale.x` facing mirrors the lean.
	_visual.rotation = 0.0
	_appearance.rotation = 0.0
	_flip_tween = create_tween()
	_flip_tween.tween_property(
		_appearance,
		"rotation",
		deg_to_rad(THROW_WINDUP_DEG),
		THROW_WINDUP_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_property(
		_appearance,
		"rotation",
		deg_to_rad(THROW_STRIKE_DEG),
		THROW_STRIKE_TIME
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_flip_tween.tween_property(_appearance, "rotation", 0.0, THROW_SETTLE_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_callback(func() -> void:
		_flip_tween = null
	)


func _reset_throw_flip() -> void:
	if _flip_tween:
		_flip_tween.kill()
		_flip_tween = null
	if _visual != null:
		_visual.rotation = 0.0
	if _appearance != null:
		_appearance.rotation = 0.0


func _get_weapon_mount() -> Node2D:
	if _appearance == null:
		return null
	var mount := _appearance.weapon_mount
	if mount == null:
		mount = _appearance.get_node_or_null("WeaponMount") as Node2D
	return mount


func _set_held_weapon_visible(weapon_visible: bool) -> void:
	var mount := _get_weapon_mount()
	if mount != null:
		mount.visible = weapon_visible


func _spawn_hit_burst() -> void:
	var world := _get_world_node()
	if world == null:
		return
	var burst: HitBurst = _HIT_BURST_SCENE.instantiate()
	world.add_child(burst)
	burst.global_position = global_position + Vector2(0.0, -40.0)
	burst.burst()


func _spawn_spore_cloud(momentum: Vector2 = Vector2.ZERO) -> void:
	var world := _get_world_node()
	if world == null:
		return
	var cloud: SporeCloud = _SPORE_CLOUD_SCENE.instantiate()
	world.add_child(cloud)
	var origin := global_position
	if _visual != null:
		origin = _visual.global_position
	cloud.global_position = origin + Vector2(0.0, -20.0)
	var spore_color := (
		ENEMY_SPORE_COLOR if _troop != null and _troop.is_enemy else SPORE_COLOR
	)
	cloud.burst(spore_color, 1.0, momentum)


func _ensure_hp_chip() -> void:
	if _hp_chip != null and is_instance_valid(_hp_chip):
		_hp_chip.position = _hp_chip_local_position()
		_hp_chip.set_value(current_hp)
		return
	_hp_chip = _STAT_CHIP_SCENE.instantiate() as StatChip
	_hp_chip.icon = _HP_ICON
	_hp_chip.position = _hp_chip_local_position()
	_hp_chip.z_index = 10
	add_child(_hp_chip)
	_hp_chip.set_value(current_hp)
	health_changed.connect(_on_hp_chip_health_changed)


func _hp_chip_local_position() -> Vector2:
	var half := StatChip.CHIP_SIZE * 0.5
	var pos := Vector2(-half.x, HP_CHIP_GAP)
	if _body_shape != null and _body_shape.shape is RectangleShape2D:
		var rect := _body_shape.shape as RectangleShape2D
		var bottom_y := _body_shape.position.y + rect.size.y * 0.5
		pos = Vector2(_body_shape.position.x - half.x, bottom_y + HP_CHIP_GAP)
	return pos


func _on_hp_chip_health_changed(current: int, _maximum: int) -> void:
	if _hp_chip != null and is_instance_valid(_hp_chip):
		_hp_chip.set_value(current)


func _face_toward(point: Vector2) -> void:
	if _visual == null:
		return
	var delta_x := point.x - global_position.x
	if absf(delta_x) < FACE_FLIP_DEADZONE:
		return
	_set_facing(signf(delta_x))


func _face_travel_direction() -> void:
	if _visual == null or is_zero_approx(velocity.x):
		return
	_set_facing(signf(velocity.x))


func _face_march_direction() -> void:
	if _visual == null or _troop == null:
		return
	_set_facing(-1.0 if _troop.is_enemy else 1.0)


func _set_facing(direction: float) -> void:
	if is_zero_approx(direction) or _visual == null:
		return
	_visual.scale.x = direction
