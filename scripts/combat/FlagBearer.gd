extends CharacterBody2D
class_name FlagBearer

@export var flag_color: Color = Color(0.25, 0.75, 0.4)
@export var flag_faces_left: bool = false

@onready var _flag_banner: Polygon2D = $Visual/Flag

var _march_speed_x: float = 0.0

const COLLISION_WORLD := 1
const COLLISION_PLAYER_UNITS := 2
const COLLISION_ENEMY_UNITS := 16


func _ready() -> void:
	_apply_flag_appearance()
	_setup_collision()


func _physics_process(delta: float) -> void:
	velocity += get_gravity() * delta
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
