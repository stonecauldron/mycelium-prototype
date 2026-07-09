extends CharacterBody2D
class_name FlagBearer

const KNOCKBACK_FORCE := 280.0
const KNOCKBACK_LIFT := -140.0
const KNOCKBACK_DURATION := 0.18
const HURT_FLASH_COLOR := Color(1.0, 0.35, 0.35, 1.0)
const HURT_FLASH_TIME := 0.12

const COLLISION_WORLD := 1
const COLLISION_PLAYER_UNITS := 2
const COLLISION_ENEMY_UNITS := 16

const _DAMAGE_NUMBER_SCENE := preload("res://scenes/vfx/DamageNumber.tscn")

@export var flag_color: Color = Color(0.25, 0.75, 0.4)
@export var flag_faces_left: bool = false

@onready var _flag_banner: Polygon2D = $Visual/Flag
@onready var _pole: Polygon2D = $Visual/Pole

var _march_speed_x: float = 0.0
var _knockback_time: float = 0.0
var _knockback_velocity_x: float = 0.0
var _hurt_tween: Tween
var _pole_color: Color = Color(0.15, 0.12, 0.1, 1.0)


func _ready() -> void:
	if _pole:
		_pole_color = _pole.color
	_apply_flag_appearance()
	_setup_collision()


func _physics_process(delta: float) -> void:
	velocity += get_gravity() * delta

	if _knockback_time > 0.0:
		_knockback_time -= delta
		velocity.x = _knockback_velocity_x
		move_and_slide()
		return

	velocity.x = _march_speed_x
	move_and_slide()


func _apply_flag_appearance() -> void:
	if _flag_banner == null:
		return
	_flag_banner.color = flag_color
	_flag_banner.scale.x = -1.0 if flag_faces_left else 1.0


func _setup_collision() -> void:
	var army := get_parent() as Army
	if army == null:
		return
	if army.is_enemy:
		collision_layer = COLLISION_ENEMY_UNITS
		collision_mask = COLLISION_WORLD | COLLISION_PLAYER_UNITS
	else:
		collision_layer = COLLISION_PLAYER_UNITS
		collision_mask = COLLISION_WORLD | COLLISION_ENEMY_UNITS


func set_march_velocity(speed: float) -> void:
	_march_speed_x = speed


func stop() -> void:
	_march_speed_x = 0.0
	velocity.x = 0.0


func reset_combat_state() -> void:
	_knockback_time = 0.0
	_knockback_velocity_x = 0.0
	velocity = Vector2.ZERO
	stop()
	if _hurt_tween:
		_hurt_tween.kill()
		_hurt_tween = null
	_apply_flag_appearance()
	if _pole:
		_pole.color = _pole_color


func take_damage(amount: int, knockback_from: Vector2 = Vector2.ZERO) -> void:
	_play_hurt_highlight()
	_spawn_damage_number(amount)
	if knockback_from != Vector2.ZERO:
		call_deferred("_apply_knockback", knockback_from)


func _apply_knockback(from_global: Vector2) -> void:
	if not is_inside_tree():
		return
	var direction := signf(global_position.x - from_global.x)
	if direction == 0.0:
		direction = 1.0
	_knockback_velocity_x = direction * KNOCKBACK_FORCE
	velocity.y = KNOCKBACK_LIFT
	_knockback_time = KNOCKBACK_DURATION


func _play_hurt_highlight() -> void:
	if _hurt_tween:
		_hurt_tween.kill()
	if _flag_banner:
		_flag_banner.color = HURT_FLASH_COLOR
	if _pole:
		_pole.color = HURT_FLASH_COLOR
	_hurt_tween = create_tween()
	_hurt_tween.set_parallel(true)
	if _flag_banner:
		_hurt_tween.tween_property(_flag_banner, "color", flag_color, HURT_FLASH_TIME)
	if _pole:
		_hurt_tween.tween_property(_pole, "color", _pole_color, HURT_FLASH_TIME)


func _spawn_damage_number(amount: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var scene := tree.current_scene
	if scene == null:
		return
	var world := scene.get_node_or_null("World")
	if world == null:
		return

	var number: DamageNumber = _DAMAGE_NUMBER_SCENE.instantiate()
	world.add_child(number)
	number.global_position = global_position + Vector2(0, -72)
	number.display(amount)
