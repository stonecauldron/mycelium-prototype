class_name Unit
extends CharacterBody2D

signal died
signal health_changed(current: int, maximum: int)

enum CombatPhase { READY, APPROACHING, ATTACKING, RETURNING }

const BASE_MOVE_SPEED := 80.0
const BASE_ATTACK_INTERVAL := 1.0
const HOME_ARRIVE_THRESHOLD := 4.0
const MARCH_CATCH_UP_MULTIPLIER := 2.0
const LUNGE_DISTANCE := 48.0
const LUNGE_OUT_TIME := 0.08
const LUNGE_BACK_TIME := 0.12
const KNOCKBACK_FORCE := 280.0
const KNOCKBACK_LIFT := -140.0
const KNOCKBACK_DURATION := 0.18
const HURT_FLASH_COLOR := Color(1.0, 0.35, 0.35, 1.0)
const HURT_FLASH_TIME := 0.12

const _DAMAGE_NUMBER_SCENE := preload("res://scenes/vfx/DamageNumber.tscn")

const COLLISION_WORLD := 1
const COLLISION_PLAYER_UNITS := 2
const COLLISION_ENEMY_UNITS := 16

@export var stats: UnitStats
@export var weapon: WeaponData
@export var roll_random_stats: bool = true
@export var squad_index: int = 0
@export var body_color: Color = Color(0.4, 0.7, 0.5)

var current_hp: int
var _attack_timer: float = 0.0
var _target: Node2D
var _army: Army
var _combat_phase: CombatPhase = CombatPhase.READY
var _hurt_tween: Tween
var _knockback_time: float = 0.0
var _knockback_velocity_x: float = 0.0

@onready var _visual: Node2D = $Visual
@onready var _body: Polygon2D = $Visual/Body
@onready var _hitbox: HitboxComponent = $Visual/Hitbox


func _ready() -> void:
	if roll_random_stats and stats == null:
		stats = UnitStats.create_random()
	elif stats != null:
		stats = stats.duplicate()

	if weapon == null:
		push_error("Unit requires a WeaponData resource.")
		return

	_initialize_runtime()


func apply_power_tier(tier: UnitStats.PowerTier) -> void:
	_cancel_attack()
	stats = UnitStats.create_for_tier(tier)
	current_hp = stats.get_max_hp()
	health_changed.emit(current_hp, stats.get_max_hp())
	_attack_timer = 0.0
	_target = null
	_combat_phase = CombatPhase.READY
	_knockback_time = 0.0
	_knockback_velocity_x = 0.0
	_apply_body_color()


func _initialize_runtime() -> void:
	current_hp = stats.get_max_hp()
	health_changed.emit(current_hp, stats.get_max_hp())

	add_to_group("units")
	_army = get_parent().get_parent() as Army
	if _army == null:
		push_error("Unit must be a child of Army/Units.")
		return

	_hitbox.owner_unit = self
	_setup_collision()
	_apply_body_color()
	call_deferred("_sync_squad_index")


func _sync_squad_index() -> void:
	if _army == null:
		return
	var units: Array[Unit] = _army.get_units()
	for i in units.size():
		if units[i] == self:
			squad_index = i
			break


func _apply_body_color() -> void:
	if _body:
		_body.color = body_color


func _setup_collision() -> void:
	if _army.is_enemy:
		collision_layer = COLLISION_ENEMY_UNITS
		collision_mask = COLLISION_WORLD | COLLISION_PLAYER_UNITS
	else:
		collision_layer = COLLISION_PLAYER_UNITS
		collision_mask = COLLISION_WORLD | COLLISION_ENEMY_UNITS


func _physics_process(delta: float) -> void:
	if stats == null or weapon == null or _army == null:
		return

	velocity += get_gravity() * delta

	if _knockback_time > 0.0:
		_knockback_time -= delta
		velocity.x = _knockback_velocity_x
		move_and_slide()
		return

	if _combat_phase == CombatPhase.ATTACKING:
		velocity.x = 0.0
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
	var army_speed := _army.get_average_unit_speed()
	var delta_pos := home.x - global_position.x
	var march_direction := -1.0 if _army.is_enemy else 1.0

	if absf(delta_pos) <= HOME_ARRIVE_THRESHOLD:
		velocity.x = army_speed * march_direction
	else:
		velocity.x = signf(delta_pos) * army_speed * MARCH_CATCH_UP_MULTIPLIER


func _process_combat(delta: float) -> void:
	if _combat_phase == CombatPhase.RETURNING or _attack_timer > 0.0:
		_attack_timer = maxf(_attack_timer - delta, 0.0)
		_return_home()
		if _attack_timer <= 0.0 and _is_at_home():
			_combat_phase = CombatPhase.READY
		return

	_refresh_target()
	if _target == null:
		_hold_or_march()
		return

	var distance := global_position.distance_to(_target.global_position)
	if distance <= weapon.attack_range:
		velocity.x = 0.0
		_face_toward(_target.global_position)
		_start_attack()
		return

	if _army.state == Army.State.HALTED:
		_combat_phase = CombatPhase.APPROACHING
		velocity.x = _axis_velocity(global_position.x, _target.global_position.x, get_move_speed())
		_face_toward(_target.global_position)
		return

	_hold_or_march()


func _hold_or_march() -> void:
	if _army.state == Army.State.HALTED:
		_return_home()
	else:
		_combat_phase = CombatPhase.READY
		_seek_home_marching()


func _return_home() -> void:
	_combat_phase = CombatPhase.RETURNING
	var home := _get_home_global()
	velocity.x = _axis_velocity(global_position.x, home.x, get_move_speed())
	_face_toward(home)


func _is_at_home() -> bool:
	return absf(global_position.x - _get_home_global().x) <= HOME_ARRIVE_THRESHOLD


func _start_attack() -> void:
	if _combat_phase == CombatPhase.ATTACKING:
		return

	_combat_phase = CombatPhase.ATTACKING
	_hitbox.enable_for_attack(_get_attack_damage())

	var direction := signf(_visual.scale.x)
	if direction == 0.0:
		direction = 1.0

	var forward := Vector2(direction * LUNGE_DISTANCE, 0.0)
	var tween := create_tween()
	tween.tween_property(_visual, "position", forward, LUNGE_OUT_TIME)
	tween.tween_callback(_hitbox.disable)
	tween.tween_property(_visual, "position", Vector2.ZERO, LUNGE_BACK_TIME)
	tween.tween_callback(_finish_attack)


func _finish_attack() -> void:
	_hitbox.disable()
	_visual.position = Vector2.ZERO
	_attack_timer = BASE_ATTACK_INTERVAL / stats.get_speed_multiplier()
	_combat_phase = CombatPhase.RETURNING


func _cancel_attack() -> void:
	if _combat_phase != CombatPhase.ATTACKING:
		return
	_hitbox.disable()
	_visual.position = Vector2.ZERO
	_combat_phase = CombatPhase.RETURNING


func _get_home_global() -> Vector2:
	var flag_pos := _army.flag_bearer.global_position
	var facing := -1.0 if _army.is_enemy else 1.0
	return Vector2(flag_pos.x + facing * weapon.get_squad_offset(squad_index), flag_pos.y)


func _axis_velocity(current: float, target: float, speed: float) -> float:
	var delta_pos := target - current
	if absf(delta_pos) <= HOME_ARRIVE_THRESHOLD:
		return 0.0
	return signf(delta_pos) * speed


func _refresh_target() -> void:
	_target = null
	var opponent: Army = _army.get_opponent()
	if opponent == null:
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


func _get_attack_damage() -> int:
	return weapon.base_damage + stats.get_damage_bonus(weapon.range_class)


func take_damage(amount: int, knockback_from: Vector2 = Vector2.ZERO) -> void:
	_play_hurt_highlight()
	_spawn_damage_number(amount)
	if knockback_from != Vector2.ZERO:
		_apply_knockback(knockback_from)
	current_hp = maxi(current_hp - amount, 0)
	health_changed.emit(current_hp, stats.get_max_hp())
	if current_hp <= 0:
		_die()


func _die() -> void:
	died.emit()
	if _army != null:
		_army.call_deferred("refresh_squad_indices")
	queue_free()


func _apply_knockback(from_global: Vector2) -> void:
	var direction := signf(global_position.x - from_global.x)
	if direction == 0.0:
		direction = 1.0
	_knockback_velocity_x = direction * KNOCKBACK_FORCE
	velocity.y = KNOCKBACK_LIFT
	_knockback_time = KNOCKBACK_DURATION


func _play_hurt_highlight() -> void:
	if _body == null:
		return
	if _hurt_tween:
		_hurt_tween.kill()
	_body.color = HURT_FLASH_COLOR
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(_body, "color", body_color, HURT_FLASH_TIME)


func _spawn_damage_number(amount: int) -> void:
	var world := get_tree().current_scene.get_node_or_null("World")
	if world == null:
		return

	var number: DamageNumber = _DAMAGE_NUMBER_SCENE.instantiate()
	world.add_child(number)
	number.global_position = global_position + Vector2(0, -72)
	number.display(amount)


func _face_toward(point: Vector2) -> void:
	if _visual == null:
		return
	_visual.scale.x = -1.0 if point.x < global_position.x else 1.0
