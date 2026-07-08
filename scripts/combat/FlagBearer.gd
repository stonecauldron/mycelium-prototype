extends CharacterBody2D
class_name FlagBearer

@export var flag_color: Color = Color(0.25, 0.75, 0.4)
@export var flag_faces_left: bool = false

@onready var _flag_banner: Polygon2D = $Visual/Flag

var _march_speed_x: float = 0.0


func _ready() -> void:
	_apply_flag_appearance()


func _physics_process(delta: float) -> void:
	velocity += get_gravity() * delta
	velocity.x = _march_speed_x
	move_and_slide()


func _apply_flag_appearance() -> void:
	if _flag_banner == null:
		return
	_flag_banner.color = flag_color
	_flag_banner.scale.x = -1.0 if flag_faces_left else 1.0


func set_march_velocity(speed: float) -> void:
	_march_speed_x = speed


func stop() -> void:
	_march_speed_x = 0.0
	velocity.x = 0.0
