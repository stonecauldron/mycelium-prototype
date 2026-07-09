class_name Unit
extends CharacterBody2D

signal died
signal health_changed(current: int, maximum: int)

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
var _target: Unit
var _army: Army
var _is_attacking: bool = false
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

	current_hp = stats.get_max_hp()
	health_changed.emit(current_hp, stats.get_max_hp())

	add_to_group("units")
	_army = get_parent().get_parent() as Army
	if _army == null:
		push_error("Unit must be a child of Army/Units.")
		return

	_hitbox.owner_unit = self
	_setup_collision()
	_army.state_changed.connect(_on_army_state_changed)
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


func _on_army_state_changed(_new_state: Army.State) -> void:
	_target = null
	_attack_timer = 0.0
	_cancel_attack()


func _physics_process(delta: float) -> void:
	if stats == null or weapon == null or _army == null:
		return

	velocity += get_gravity() * delta

	if _knockback_time > 0.0:
		_knockback_time -= delta
		velocity.x = _knockback_velocity_x
		move_and_slide()
		return

	if _is_attacking:
		velocity.x = 0.0
		move_and_slide()
		return

	if _army.state == Army.State.HALTED:
		_process_combat(delta)
	else:
		_seek_home()

	move_and_slide()


func get_move_speed() -> float:
	if stats == null:
		return BASE_MOVE_SPEED
	return BASE_MOVE_SPEED * stats.get_speed_multiplier()


func _seek_home() -> void:
	var home := _get_home_global()
	var army_speed := _army.get_average_unit_speed()
	var delta_pos := home.x - global_position.x
	var march_direction := -1.0 if _army.is_enemy else 1.0

	if absf(delta_pos) <= HOME_ARRIVE_THRESHOLD:
		velocity.x = army_speed * march_direction
	else:
		velocity.x = signf(delta_pos) * army_speed * MARCH_CATCH_UP_MULTIPLIER


func _process_combat(delta: float) -> void:
	if not is_instance_valid(_target) or _target.current_hp <= 0:
		_refresh_target()

	if _target == null:
		velocity.x = 0.0
		return

	var distance := global_position.distance_to(_target.global_position)
	var speed := get_move_speed()

	if distance > weapon.attack_range:
		velocity.x = _axis_velocity(global_position.x, _target.global_position.x, speed)
		_face_toward(_target.global_position)
		return

	velocity.x = 0.0
	_face_toward(_target.global_position)

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_start_attack()
		_attack_timer = BASE_ATTACK_INTERVAL / stats.get_speed_multiplier()


func _start_attack() -> void:
	if _is_attacking:
		return

	_is_attacking = true
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
	_is_attacking = false


func _cancel_attack() -> void:
	if not _is_attacking:
		return
	_hitbox.disable()
	_visual.position = Vector2.ZERO
	_is_attacking = false


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
		died.emit()
		queue_free()


func _apply_knockback(from_global: Vector2) -> void:
	var direction := signf(global_position.x - from_global.x)
	if direction == 0.0:
		direction = 1.0
	_knockback_velocity_x = direction * KNOCKBACK_FORCE
	velocity.y = KNOCKBACK_LIFT
	_knockback_time = KNOCKBACK_DURATION
	_cancel_attack()


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
