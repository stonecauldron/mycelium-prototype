class_name Unit
extends CharacterBody2D

signal died(unit: Unit)
signal health_changed(current: int, maximum: int)

enum CombatPhase { READY, APPROACHING, ATTACKING, RETURNING }

const BASE_MOVE_SPEED := 180.0
const BASE_ATTACK_INTERVAL := 0.75
const RANGED_ATTACK_INTERVAL := 1.15
const HOME_ARRIVE_THRESHOLD := 4.0
const MARCH_CATCH_UP_MULTIPLIER := 2.0
const LUNGE_DISTANCE := 48.0
const LUNGE_OUT_TIME := 0.08
const LUNGE_BACK_TIME := 0.12
const THROW_JUMP_VELOCITY := -520.0
const THROW_RELEASE_DELAY := 0.22
const THROW_RECOVERY_TIME := 0.28
const THROW_MAX_DURATION := 1.4
const THROW_AIM_JITTER_X := 40.0
const THROW_AIM_JITTER_Y := 20.0
const THROW_ORIGIN_HEIGHT := -48.0
const RANGED_RELEASE_DELAY := 0.22
const RANGED_RECOVERY_TIME := 0.42
const RANGED_ORIGIN_HEIGHT := -40.0
const KNOCKBACK_UP_RATIO := 0.5
const HURT_FLASH_COLOR := Color(1.0, 0.35, 0.35, 1.0)
const HURT_FLASH_TIME := 0.12

const _DAMAGE_NUMBER_SCENE := preload("res://assets/vfx/damage_number/damage_number.tscn")
const _SPEAR_PROJECTILE_SCENE := preload("res://assets/combat/spear_projectile/spear_projectile.tscn")
const _ARROW_PROJECTILE_SCENE := preload("res://assets/combat/arrow_projectile/arrow_projectile.tscn")
const _STAT_CHIP_SCENE := preload("res://assets/ui/stat_chip/stat_chip.tscn")
const _HP_ICON := preload("res://assets/base/unit_card/hp_icon.png")
const HP_CHIP_GAP := 4.0

const COLLISION_WORLD := 1
const COLLISION_PLAYER_UNITS := 2
const COLLISION_ENEMY_UNITS := 16

@export var stats: UnitStatsData
@export var weapon: WeaponData
@export var roll_random_stats: bool = true
@export var squad_index: int = 0
@export var body_color: Color = Color.WHITE

var current_hp: int
var process_tiebreak: int = 0
var roster_data: RosterUnitData = null
var _attack_timer: float = 0.0
var _target: Node2D
var _troop: Troop
var _combat_phase: CombatPhase = CombatPhase.READY
var _hurt_tween: Tween
var _in_knockback: bool = false
var _knockback_left_ground: bool = false
var _throw_released: bool = false
var _throw_landed: bool = false
var _throw_left_ground: bool = false
var _throw_timer: float = 0.0

@onready var _visual: Node2D = $Visual
@onready var _hitbox: HitboxComponent = $Visual/Hitbox

var _appearance: UnitAppearance = null
var _body_shape: CollisionShape2D = null
var _hp_chip: StatChip = null


func _ready() -> void:
	if roll_random_stats and stats == null:
		stats = UnitStatsData.create_random()
	elif stats != null:
		stats = stats.duplicate()

	if weapon == null:
		push_error("Unit requires a WeaponData resource.")
		return

	_initialize_runtime()


func apply_power_tier(tier: UnitStatsData.PowerTier) -> void:
	_cancel_attack()
	stats = UnitStatsData.create_for_tier(tier)
	process_tiebreak = randi()
	current_hp = stats.get_max_hp()
	health_changed.emit(current_hp, stats.get_max_hp())
	_attack_timer = 0.0
	_target = null
	_combat_phase = CombatPhase.READY
	_in_knockback = false
	_knockback_left_ground = false
	_apply_body_color()


func _initialize_runtime() -> void:
	current_hp = stats.get_max_hp()
	health_changed.emit(current_hp, stats.get_max_hp())
	process_tiebreak = randi()

	add_to_group("units")
	_troop = get_parent().get_parent() as Troop
	if _troop == null:
		push_error("Unit must be a child of Troop/Units.")
		return

	_hitbox.owner_unit = self
	_setup_collision()
	_mount_appearance()
	_apply_body_color()
	_ensure_hp_chip()


func _mount_appearance() -> void:
	_clear_visual_non_hitbox_children()
	if _body_shape != null and is_instance_valid(_body_shape):
		_body_shape.queue_free()
		_body_shape = null
	_appearance = null

	var strain: UnitStrain = roster_data.strain if roster_data != null else null
	if strain == null:
		strain = preload("res://assets/units/capling/capling_strain.tres") as UnitStrain
	if strain == null:
		return

	_appearance = strain.instantiate_appearance()
	if _appearance == null:
		return

	_visual.add_child(_appearance)
	_visual.move_child(_appearance, 0)

	var body := _appearance.get_node_or_null("BodyShape") as CollisionShape2D
	if body != null:
		var global_xform := body.global_transform
		body.reparent(self)
		body.global_transform = global_xform
		_body_shape = body

	_appearance.mount_weapon_appearance(weapon)
	_appearance.play_idle(true)


func _clear_visual_non_hitbox_children() -> void:
	for child in _visual.get_children():
		if child == _hitbox:
			continue
		_visual.remove_child(child)
		child.free()


func _apply_body_color() -> void:
	if _appearance:
		_appearance.modulate = body_color


func _setup_collision() -> void:
	if _troop.is_enemy:
		collision_layer = COLLISION_ENEMY_UNITS
		collision_mask = COLLISION_WORLD | COLLISION_PLAYER_UNITS
	else:
		collision_layer = COLLISION_PLAYER_UNITS
		collision_mask = COLLISION_WORLD | COLLISION_ENEMY_UNITS


func _physics_process(delta: float) -> void:
	if stats == null or weapon == null or _troop == null:
		return

	velocity += get_gravity() * delta

	if _in_knockback:
		move_and_slide()
		if not is_on_floor():
			_knockback_left_ground = true
		elif _knockback_left_ground and velocity.y >= 0.0:
			_in_knockback = false
			_knockback_left_ground = false
			velocity.x = 0.0
		return

	if _combat_phase == CombatPhase.ATTACKING:
		velocity.x = 0.0
		if weapon.attack_style == WeaponData.AttackStyle.SPEAR_THROW:
			_process_throw_attack(delta)
		elif weapon.attack_style == WeaponData.AttackStyle.BOW_SHOT:
			_process_ranged_attack(delta)
		move_and_slide()
		return

	_process_combat(delta)
	move_and_slide()


func get_move_speed() -> float:
	if stats == null:
		return BASE_MOVE_SPEED
	return BASE_MOVE_SPEED * stats.get_speed_multiplier()


func _seek_home_marching() -> void:
	var home := _get_home_global()
	var troop_speed := _troop.get_average_unit_speed()
	var delta_pos := home.x - global_position.x
	var march_direction := -1.0 if _troop.is_enemy else 1.0

	if absf(delta_pos) <= HOME_ARRIVE_THRESHOLD:
		velocity.x = troop_speed * march_direction
	else:
		velocity.x = signf(delta_pos) * troop_speed * MARCH_CATCH_UP_MULTIPLIER
	_face_travel_direction()


func _process_combat(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer = maxf(_attack_timer - delta, 0.0)
		_refresh_target()
		if _target == null:
			_hold_or_march()
		elif _should_chase():
			_chase_target()
		else:
			_return_home()
		return

	_refresh_target()
	if _target == null:
		_hold_or_march()
		return

	var distance := global_position.distance_to(_target.global_position)
	if (
		weapon.engagement_stance == WeaponData.EngagementStance.SKIRMISH
		and distance <= weapon.skirmish_distance
	):
		_return_home()
		return

	if distance <= weapon.attack_range:
		velocity.x = 0.0
		_face_toward(_target.global_position)
		_start_attack()
		return

	if _troop.state == Troop.State.HALTED or _should_chase():
		_chase_target()
		return

	_hold_or_march()


func _should_chase() -> bool:
	if weapon == null or _troop == null:
		return false
	match weapon.engagement_stance:
		WeaponData.EngagementStance.HOLD:
			return true
		WeaponData.EngagementStance.REFORM:
			var opponent := _troop.get_opponent()
			if opponent == null:
				return false
			return not opponent.has_living_formation_line(WeaponData.FormationLine.FRONT)
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
	if distance <= weapon.attack_range:
		velocity.x = 0.0
	else:
		velocity.x = _axis_velocity(global_position.x, _target.global_position.x, get_move_speed())
	_face_toward(_target.global_position)


func _hold_or_march() -> void:
	if _troop.state == Troop.State.HALTED:
		_return_home()
	else:
		_combat_phase = CombatPhase.READY
		_seek_home_marching()


func _return_home() -> void:
	_combat_phase = CombatPhase.RETURNING
	var home := _get_home_global()
	velocity.x = _axis_velocity(global_position.x, home.x, get_move_speed())
	if is_zero_approx(velocity.x):
		_face_toward(home)
	else:
		_face_travel_direction()


func _start_attack() -> void:
	if _combat_phase == CombatPhase.ATTACKING:
		return

	_combat_phase = CombatPhase.ATTACKING
	if weapon.attack_style == WeaponData.AttackStyle.SPEAR_THROW:
		_start_throw_attack()
		return
	if weapon.attack_style == WeaponData.AttackStyle.BOW_SHOT:
		_start_ranged_attack()
		return

	_hitbox.enable_for_attack(
		_get_attack_damage(),
		weapon.knockback_force,
		weapon.targeting_mode
	)

	var direction := signf(_visual.scale.x)
	if direction == 0.0:
		direction = 1.0

	var forward := Vector2(direction * LUNGE_DISTANCE, 0.0)
	var tween := create_tween()
	tween.tween_property(_visual, "position", forward, LUNGE_OUT_TIME)
	tween.tween_callback(_hitbox.disable)
	tween.tween_property(_visual, "position", Vector2.ZERO, LUNGE_BACK_TIME)
	tween.tween_callback(_finish_attack)


func _start_throw_attack() -> void:
	_throw_released = false
	_throw_landed = false
	_throw_left_ground = false
	_throw_timer = 0.0
	velocity.y = THROW_JUMP_VELOCITY


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

	if _throw_landed and _throw_timer >= THROW_RECOVERY_TIME:
		_finish_attack()
		return

	if _throw_released and _throw_timer >= THROW_MAX_DURATION:
		_finish_attack()


func _spawn_spear_projectile() -> void:
	var world := _get_world_node()
	if world == null:
		return

	var opponent := _troop.get_opponent()
	if opponent == null:
		return

	var aim := _pick_ranged_aim_target(opponent)
	aim += Vector2(
		randf_range(-THROW_AIM_JITTER_X, THROW_AIM_JITTER_X),
		randf_range(-THROW_AIM_JITTER_Y, THROW_AIM_JITTER_Y)
	)

	var spear: SpearProjectile = _SPEAR_PROJECTILE_SCENE.instantiate()
	world.add_child(spear)
	spear.launch(
		global_position + Vector2(0.0, THROW_ORIGIN_HEIGHT),
		aim,
		_get_attack_damage(),
		weapon.knockback_force,
		self
	)


func _start_ranged_attack() -> void:
	_throw_released = false
	_throw_timer = 0.0


func _process_ranged_attack(delta: float) -> void:
	_throw_timer += delta
	if not _throw_released and _throw_timer >= RANGED_RELEASE_DELAY:
		_throw_released = true
		_spawn_arrow_projectile()
		_throw_timer = 0.0
		return

	if _throw_released and _throw_timer >= RANGED_RECOVERY_TIME:
		_finish_attack()


func _spawn_arrow_projectile() -> void:
	var world := _get_world_node()
	if world == null:
		return

	var opponent := _troop.get_opponent()
	if opponent == null:
		return

	var aim := _pick_ranged_aim_target(opponent)
	aim += Vector2(
		randf_range(-THROW_AIM_JITTER_X, THROW_AIM_JITTER_X),
		randf_range(-THROW_AIM_JITTER_Y, THROW_AIM_JITTER_Y)
	)

	var arrow: ArrowProjectile = _ARROW_PROJECTILE_SCENE.instantiate()
	world.add_child(arrow)
	arrow.launch(
		global_position + Vector2(0.0, RANGED_ORIGIN_HEIGHT),
		aim,
		_get_attack_damage(),
		weapon.knockback_force,
		self
	)


func _finish_attack() -> void:
	_hitbox.disable()
	_visual.position = Vector2.ZERO
	_throw_released = false
	_throw_landed = false
	_throw_left_ground = false
	_throw_timer = 0.0
	var interval := BASE_ATTACK_INTERVAL
	if weapon != null and weapon.attack_style == WeaponData.AttackStyle.BOW_SHOT:
		interval = RANGED_ATTACK_INTERVAL
	_attack_timer = interval / stats.get_speed_multiplier()
	_combat_phase = CombatPhase.RETURNING


func _cancel_attack() -> void:
	if _combat_phase != CombatPhase.ATTACKING:
		return
	_hitbox.disable()
	_visual.position = Vector2.ZERO
	_throw_released = false
	_throw_landed = false
	_throw_left_ground = false
	_throw_timer = 0.0
	_combat_phase = CombatPhase.RETURNING


func _get_home_global() -> Vector2:
	var flag_pos := _troop.flag_bearer.global_position
	var facing := -1.0 if _troop.is_enemy else 1.0
	var index := squad_index
	# BACK uses a negative offset, so increasing squad_index moves left for the player
	# and mirrors War Chamber LTR. Reverse so left-in-selection stays left-on-screen.
	if (
		weapon != null
		and not _troop.is_enemy
		and weapon.formation_line == WeaponData.FormationLine.BACK
	):
		var line_count := _troop.get_living_formation_line_count(weapon.formation_line)
		index = maxi(line_count - 1 - squad_index, 0)
	var offset := weapon.get_squad_offset(index) if weapon != null else 0.0
	return Vector2(flag_pos.x + facing * offset, flag_pos.y)


func _axis_velocity(current: float, target: float, speed: float) -> float:
	var delta_pos := target - current
	if absf(delta_pos) <= HOME_ARRIVE_THRESHOLD:
		return 0.0
	return signf(delta_pos) * speed


func _refresh_target() -> void:
	_target = null
	var opponent: Troop = _troop.get_opponent()
	if opponent == null or opponent.is_wiped_out():
		return

	var closest_distance := INF
	for unit in opponent.get_units():
		if unit.current_hp <= 0:
			continue
		var distance := global_position.distance_squared_to(unit.global_position)
		if distance < closest_distance:
			closest_distance = distance
			_target = unit

	var flag := opponent.flag_bearer
	if flag != null and is_instance_valid(flag):
		var flag_distance := global_position.distance_squared_to(flag.global_position)
		if flag_distance < closest_distance:
			_target = flag


func _get_ranged_aim_priority() -> Array[WeaponData.FormationLine]:
	var line := (
		weapon.formation_line if weapon != null else WeaponData.FormationLine.FRONT
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
	for formation_line in _get_ranged_aim_priority():
		var candidates: Array[Unit] = []
		for unit in opponent.get_living_units():
			if unit.weapon != null and unit.weapon.formation_line == formation_line:
				candidates.append(unit)
		if candidates.is_empty():
			continue

		var total_weight := 0.0
		var weights: Array[float] = []
		for unit in candidates:
			var distance := global_position.distance_to(unit.global_position)
			var weight := 1.0 / maxf(distance, 1.0)
			weights.append(weight)
			total_weight += weight

		var roll := randf() * total_weight
		var cumulative := 0.0
		for i in candidates.size():
			cumulative += weights[i]
			if roll <= cumulative:
				return candidates[i].global_position
		return candidates[candidates.size() - 1].global_position

	if opponent.flag_bearer != null and is_instance_valid(opponent.flag_bearer):
		return opponent.flag_bearer.global_position
	return global_position


func _get_attack_damage() -> int:
	var raw: int = weapon.base_damage + stats.get_damage_bonus(weapon.attack_style)
	return roundi(float(raw) * weapon.outgoing_damage_multiplier)


func take_damage(
	amount: int,
	knockback_from: Vector2 = Vector2.ZERO,
	knockback_force: float = 0.0
) -> void:
	var incoming_mult: float = 1.0
	var knockback_mult: float = 1.0
	if weapon != null:
		incoming_mult = weapon.incoming_damage_multiplier
		knockback_mult = weapon.incoming_knockback_multiplier
	amount = roundi(float(amount) * incoming_mult)
	_play_hurt_highlight()
	_spawn_damage_number(amount)
	current_hp = maxi(current_hp - amount, 0)
	health_changed.emit(current_hp, stats.get_max_hp())
	if current_hp <= 0:
		_die()
		return
	if knockback_from != Vector2.ZERO and knockback_force > 0.0:
		_apply_knockback(knockback_from, knockback_force * knockback_mult)


func _die() -> void:
	died.emit(self)
	if _troop != null:
		_troop.call_deferred("refresh_squad_indices")
	queue_free()


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


func _get_world_node() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("combat_world")


func _spawn_damage_number(amount: int) -> void:
	var world := _get_world_node()
	if world == null:
		return

	var number: DamageNumber = _DAMAGE_NUMBER_SCENE.instantiate()
	world.add_child(number)
	number.global_position = global_position + Vector2(0, -72)
	number.display(amount)


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
	_visual.scale.x = -1.0 if point.x < global_position.x else 1.0


func _face_travel_direction() -> void:
	if _visual == null or is_zero_approx(velocity.x):
		return
	_visual.scale.x = signf(velocity.x)
