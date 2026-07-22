extends CharacterBody2D
class_name FlagBearer

const KNOCKBACK_UP_RATIO := 0.5
const KNOCKBACK_IMPULSE_MULTIPLIER := 1.75
const HIT_KNOCKBACK_PER_HIT := 0.25
const HIT_KNOCKBACK_MAX_MULT := 2.0
const HIT_SLOW_PER_HIT := 0.25
const HIT_SLOW_MIN_MULT := 0.5
const HURT_FLASH_COLOR := Color(1.0, 0.35, 0.35, 1.0)
const HURT_FLASH_TIME := 0.12

const COLLISION_WORLD := 1
const COLLISION_PLAYER_UNITS := 2
const COLLISION_ENEMY_UNITS := 16

const _DAMAGE_NUMBER_SCENE := preload("res://assets/vfx/damage_number/damage_number.tscn")

@export var flag_color: Color = Color.WHITE
@export var flag_faces_left: bool = false

@onready var _visual: Node2D = $Visual
@onready var _shroom: Sprite2D = $Visual/Shroom
@onready var _flag_banner: Sprite2D = $Visual/Shroom/Flag
@onready var _animation_player: AnimationPlayer = $Visual/AnimationPlayer

var _march_speed_x: float = 0.0
var _in_knockback: bool = false
var _knockback_left_ground: bool = false
var _hits_taken: int = 0
var _hurt_tween: Tween
var _shroom_modulate: Color = Color.WHITE


func _ready() -> void:
	if _shroom:
		_shroom_modulate = _shroom.modulate
	_apply_flag_appearance()
	_setup_collision()
	_start_idle_animation()


func _start_idle_animation() -> void:
	if _animation_player == null or not _animation_player.has_animation(&"idle"):
		return
	_animation_player.play(&"idle")
	var length := _animation_player.current_animation_length
	if length > 0.0:
		_animation_player.seek(randf() * length, true)


func _physics_process(delta: float) -> void:
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

	velocity.x = _march_speed_x
	move_and_slide()


func _apply_flag_appearance() -> void:
	if _visual:
		_visual.scale.x = -1.0 if flag_faces_left else 1.0
	if _flag_banner:
		_flag_banner.modulate = flag_color
	if _shroom:
		_shroom.modulate = _shroom_modulate


func _setup_collision() -> void:
	var troop := get_parent() as Troop
	if troop == null:
		return
	if troop.is_enemy:
		collision_layer = COLLISION_ENEMY_UNITS
		collision_mask = COLLISION_WORLD | COLLISION_PLAYER_UNITS
	else:
		collision_layer = COLLISION_PLAYER_UNITS
		collision_mask = COLLISION_WORLD | COLLISION_ENEMY_UNITS


func set_march_velocity(speed: float) -> void:
	if _in_knockback:
		return
	_march_speed_x = speed * _march_speed_multiplier()


func stop() -> void:
	_march_speed_x = 0.0


func is_in_knockback() -> bool:
	return _in_knockback


func _march_speed_multiplier() -> float:
	return maxf(1.0 - float(_hits_taken) * HIT_SLOW_PER_HIT, HIT_SLOW_MIN_MULT)

func reset_combat_state() -> void:
	_in_knockback = false
	_knockback_left_ground = false
	_hits_taken = 0
	velocity = Vector2.ZERO
	stop()
	if _hurt_tween:
		_hurt_tween.kill()
		_hurt_tween = null
	_apply_flag_appearance()


func take_damage(
	amount: int,
	knockback_from: Vector2 = Vector2.ZERO,
	knockback_force: float = 0.0
) -> void:
	_hits_taken += 1
	_play_hurt_highlight()
	_spawn_damage_number(amount)
	if knockback_from != Vector2.ZERO and knockback_force > 0.0:
		_apply_knockback(knockback_from, knockback_force)


func _apply_knockback(from_global: Vector2, knockback_force: float) -> void:
	if not is_inside_tree() or knockback_force <= 0.0:
		return
	var direction := signf(global_position.x - from_global.x)
	if direction == 0.0:
		direction = 1.0
	var hit_mult := minf(
		1.0 + float(_hits_taken - 1) * HIT_KNOCKBACK_PER_HIT,
		HIT_KNOCKBACK_MAX_MULT
	)
	var impulse := knockback_force * KNOCKBACK_IMPULSE_MULTIPLIER * hit_mult
	velocity.x = direction * impulse
	velocity.y = -impulse * KNOCKBACK_UP_RATIO
	_in_knockback = true
	_knockback_left_ground = false
	_march_speed_x = 0.0

func _play_hurt_highlight() -> void:
	if _hurt_tween:
		_hurt_tween.kill()
	if _flag_banner:
		_flag_banner.modulate = HURT_FLASH_COLOR
	if _shroom:
		_shroom.modulate = HURT_FLASH_COLOR
	_hurt_tween = create_tween()
	_hurt_tween.set_parallel(true)
	if _flag_banner:
		_hurt_tween.tween_property(_flag_banner, "modulate", flag_color, HURT_FLASH_TIME)
	if _shroom:
		_hurt_tween.tween_property(_shroom, "modulate", _shroom_modulate, HURT_FLASH_TIME)


func _spawn_damage_number(amount: int) -> void:
	var world := _get_world_node()
	if world == null:
		return

	var number: DamageNumber = _DAMAGE_NUMBER_SCENE.instantiate()
	world.add_child(number)
	number.global_position = global_position + Vector2(0, -72)
	number.display(amount)


func _get_world_node() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("combat_world")
