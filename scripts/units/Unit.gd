class_name Unit
extends CharacterBody2D

signal died
signal health_changed(current: int, maximum: int)

const BASE_MOVE_SPEED := 80.0
const BASE_ATTACK_INTERVAL := 1.0
const SQUAD_SPREAD := 36.0
const HOME_ARRIVE_THRESHOLD := 4.0

@export var stats: UnitStats
@export var weapon: WeaponData
@export var roll_random_stats: bool = true
@export var squad_index: int = 0
@export var body_color: Color = Color(0.4, 0.7, 0.5)

var current_hp: int
var _attack_timer: float = 0.0
var _target: Unit
var _army: Army

@onready var _visual: Node2D = $Visual
@onready var _body: Polygon2D = $Visual/Body


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


func _on_army_state_changed(_new_state: Army.State) -> void:
	_target = null
	_attack_timer = 0.0


func _physics_process(delta: float) -> void:
	if stats == null or weapon == null or _army == null:
		return

	velocity += get_gravity() * delta

	if _army.state == Army.State.HALTED:
		_process_combat(delta)
	else:
		_seek_home()

	move_and_slide()


func _seek_home() -> void:
	var home := _get_home_global()
	var speed := BASE_MOVE_SPEED * stats.get_speed_multiplier()
	velocity.x = _axis_velocity(global_position.x, home.x, speed)


func _process_combat(delta: float) -> void:
	if not is_instance_valid(_target) or _target.current_hp <= 0:
		_refresh_target()

	if _target == null:
		velocity.x = 0.0
		return

	var distance := global_position.distance_to(_target.global_position)
	var speed := BASE_MOVE_SPEED * stats.get_speed_multiplier()

	if distance > weapon.attack_range:
		velocity.x = _axis_velocity(global_position.x, _target.global_position.x, speed)
		_face_toward(_target.global_position)
		return

	velocity.x = 0.0
	_face_toward(_target.global_position)

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_perform_attack()
		_attack_timer = BASE_ATTACK_INTERVAL / stats.get_speed_multiplier()


func _get_home_global() -> Vector2:
	var flag_pos := _army.flag_bearer.global_position
	var facing := -1.0 if _army.is_enemy else 1.0
	return flag_pos + Vector2(facing * weapon.get_squad_offset(), _get_squad_spread_y())


func _get_squad_spread_y() -> float:
	var unit_count: int = _army.get_units().size()
	if unit_count <= 1:
		return 0.0
	return (squad_index - (unit_count - 1) / 2.0) * SQUAD_SPREAD


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


func _perform_attack() -> void:
	if _target == null:
		return
	_target.take_damage(_get_attack_damage())


func _get_attack_damage() -> int:
	return weapon.base_damage + stats.get_damage_bonus(weapon.range_class)


func take_damage(amount: int) -> void:
	current_hp = maxi(current_hp - amount, 0)
	health_changed.emit(current_hp, stats.get_max_hp())
	if current_hp <= 0:
		died.emit()
		queue_free()


func _face_toward(point: Vector2) -> void:
	if _visual == null:
		return
	_visual.scale.x = -1.0 if point.x < global_position.x else 1.0
