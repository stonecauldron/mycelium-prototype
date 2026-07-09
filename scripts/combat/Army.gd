extends Node2D
class_name Army

enum State { MARCHING, HALTED }

signal state_changed(new_state: State)

const DEFAULT_MARCH_SPEED := 120.0
const DEFAULT_HALT_DISTANCE := 600.0
const HALT_DISTANCE_TOLERANCE := 24.0

@export var march_speed: float = DEFAULT_MARCH_SPEED
@export var halt_distance: float = DEFAULT_HALT_DISTANCE
@export var is_enemy: bool = false

var state: State = State.MARCHING
var _opponent: Army

@onready var flag_bearer: FlagBearer = $FlagBearer


func _ready() -> void:
	add_to_group("armies")
	call_deferred("_acquire_opponent")
	call_deferred("_assign_squad_indices")


func _assign_squad_indices() -> void:
	refresh_squad_indices()


func refresh_squad_indices() -> void:
	var units := get_living_units()
	for i in units.size():
		units[i].squad_index = i


func get_opponent() -> Army:
	return _opponent


func get_units() -> Array[Unit]:
	var units: Array[Unit] = []
	for child in $Units.get_children():
		if child is Unit:
			units.append(child)
	return units


func get_living_units() -> Array[Unit]:
	var units: Array[Unit] = []
	for unit in get_units():
		if unit.current_hp > 0:
			units.append(unit)
	return units


func get_living_unit_count() -> int:
	return get_living_units().size()


func apply_power_tier(tier: UnitStats.PowerTier) -> void:
	for unit in get_units():
		unit.apply_power_tier(tier)
	refresh_squad_indices()


func reset_for_scenario(spawn_global: Vector2) -> void:
	flag_bearer.global_position = spawn_global
	flag_bearer.reset_combat_state()
	state = State.MARCHING
	state_changed.emit(state)
	refresh_squad_indices()


func get_average_unit_speed() -> float:
	var total := 0.0
	var count := 0
	for unit in get_units():
		if unit.current_hp <= 0:
			continue
		total += unit.get_move_speed()
		count += 1
	if count == 0:
		return march_speed
	return total / float(count)


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
	if state == State.MARCHING:
		return
	state = State.MARCHING
	state_changed.emit(state)


func halt() -> void:
	if state == State.HALTED:
		return
	state = State.HALTED
	state_changed.emit(state)


func _physics_process(_delta: float) -> void:
	_acquire_opponent()
	if flag_bearer.is_in_knockback():
		return
	if _opponent == null:
		flag_bearer.stop()
		return
	if is_enemy and march_speed <= 0.0:
		flag_bearer.stop()
		return

	var gap := absf(_opponent.get_flag_global_x() - get_flag_global_x())
	var toward_enemy := signf(_opponent.get_flag_global_x() - get_flag_global_x())
	if toward_enemy == 0.0:
		toward_enemy = 1.0 if not is_enemy else -1.0

	var speed := get_average_unit_speed()
	var error := gap - halt_distance

	if absf(error) <= HALT_DISTANCE_TOLERANCE:
		flag_bearer.stop()
		halt()
		return

	if error > 0.0:
		# Too far — close the gap.
		flag_bearer.set_march_velocity(speed * toward_enemy)
		if state == State.HALTED:
			begin_march()
	else:
		# Too close — fall back to restore spacing.
		flag_bearer.set_march_velocity(speed * -toward_enemy)
		halt()
