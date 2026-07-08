extends Node2D
class_name Army

enum State { MARCHING, HALTED }

signal state_changed(new_state: State)

const DEFAULT_MARCH_SPEED := 120.0
const DEFAULT_HALT_DISTANCE := 600.0

@export var march_speed: float = DEFAULT_MARCH_SPEED
@export var halt_distance: float = DEFAULT_HALT_DISTANCE
@export var is_enemy: bool = false

var state: State = State.MARCHING
var _opponent: Army

@onready var flag_bearer: FlagBearer = $FlagBearer


func _ready() -> void:
	add_to_group("armies")
	call_deferred("_acquire_opponent")


func _acquire_opponent() -> void:
	var closest: Army = null
	var closest_distance := INF

	for node in get_tree().get_nodes_in_group("armies"):
		if node == self:
			continue
		var army := node as Army
		if army == null or army.is_enemy == is_enemy:
			continue
		var distance := absf(army.get_flag_global_x() - get_flag_global_x())
		if distance < closest_distance:
			closest_distance = distance
			closest = army

	_opponent = closest


func get_flag_global_x() -> float:
	return flag_bearer.global_position.x


func get_flag_global_position() -> Vector2:
	return flag_bearer.global_position


func begin_march() -> void:
	state = State.MARCHING
	state_changed.emit(state)


func halt() -> void:
	if state == State.HALTED:
		return
	state = State.HALTED
	flag_bearer.stop()
	state_changed.emit(state)


func _physics_process(delta: float) -> void:
	if state != State.MARCHING or _opponent == null:
		flag_bearer.stop()
		return
	if is_enemy and march_speed <= 0.0:
		flag_bearer.stop()
		return

	var gap := _opponent.get_flag_global_x() - get_flag_global_x()
	if is_enemy:
		gap = -gap

	if gap <= halt_distance:
		halt()
		if _opponent.state == State.MARCHING:
			_opponent.halt()
		return

	var direction := -1.0 if is_enemy else 1.0
	flag_bearer.set_march_velocity(march_speed * direction)
