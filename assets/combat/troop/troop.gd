extends Node2D
class_name Troop

enum State { MARCHING, HALTED }

signal state_changed(new_state: State)

const DEFAULT_MARCH_SPEED := 120.0
const DEFAULT_HALT_DISTANCE := 600.0
const HALT_DISTANCE_TOLERANCE := 24.0

@export var march_speed: float = DEFAULT_MARCH_SPEED
@export var halt_distance: float = DEFAULT_HALT_DISTANCE
@export var is_enemy: bool = false

var state: State = State.MARCHING
var _opponent: Troop
var _battle_march_speed: float = DEFAULT_MARCH_SPEED

@onready var flag_bearer: FlagBearer = $FlagBearer


func _ready() -> void:
	add_to_group("troops")
	call_deferred("_acquire_opponent")
	call_deferred("_assign_squad_indices")


func _assign_squad_indices() -> void:
	refresh_squad_indices()


func refresh_squad_indices() -> void:
	var by_line: Dictionary = {}
	for unit in get_living_units():
		var formation_line: WeaponData.FormationLine = (
			unit.weapon.formation_line if unit.weapon != null else WeaponData.FormationLine.FRONT
		)
		if not by_line.has(formation_line):
			by_line[formation_line] = []
		by_line[formation_line].append(unit)

	for formation_line in by_line:
		var units: Array = by_line[formation_line]
		for i in units.size():
			units[i].squad_index = i


func get_living_units_midpoint() -> Vector2:
	var living := get_living_units()
	if living.is_empty():
		return flag_bearer.global_position
	var sum := Vector2.ZERO
	for unit in living:
		sum += unit.global_position
	return sum / float(living.size())


func get_opponent() -> Troop:
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


func is_wiped_out() -> bool:
	## True when no combat units remain (flag bearer alone does not count).
	return get_living_unit_count() == 0


func has_living_formation_line(formation_line: WeaponData.FormationLine) -> bool:
	return get_living_formation_line_count(formation_line) > 0


func get_living_formation_line_count(formation_line: WeaponData.FormationLine) -> int:
	var count := 0
	for unit in get_living_units():
		if unit.weapon != null and unit.weapon.formation_line == formation_line:
			count += 1
	return count


func apply_power_tier(tier: UnitStatsData.PowerTier) -> void:
	for unit in get_units():
		unit.apply_power_tier(tier)
	refresh_squad_indices()


func reset_for_scenario(spawn_global: Vector2) -> void:
	flag_bearer.global_position = spawn_global
	flag_bearer.reset_combat_state()
	state = State.MARCHING
	state_changed.emit(state)
	_battle_march_speed = march_speed
	refresh_squad_indices()


func cache_battle_march_speed() -> void:
	var total := 0.0
	var count := 0
	for unit in get_units():
		if unit.current_hp <= 0:
			continue
		total += unit.get_move_speed()
		count += 1
	if count == 0:
		_battle_march_speed = march_speed
	else:
		_battle_march_speed = total / float(count)


func get_average_unit_speed() -> float:
	return _battle_march_speed


func _acquire_opponent() -> void:
	var closest: Troop = null
	var closest_distance := INF

	for node in get_tree().get_nodes_in_group("troops"):
		if node == self:
			continue
		var troop := node as Troop
		if troop == null or troop.is_enemy == is_enemy:
			continue
		var distance := absf(troop.get_flag_global_x() - get_flag_global_x())
		if distance < closest_distance:
			closest_distance = distance
			closest = troop

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
	if is_wiped_out():
		flag_bearer.stop()
		halt()
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
