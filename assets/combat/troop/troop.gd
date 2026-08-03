extends Node2D
class_name Troop

## Distance at which units acquire combat targets (replaces army-wide halt gap).
const ENGAGE_RANGE := 1800.0
const DEFAULT_MARCH_SPEED := 120.0
## Distance from flag/anchor center to squad slot 0 home / gap behind rearmost unit.
const FLAG_REAR_CLEARANCE := 100.0
## Horizontal spacing between consecutive home slots (player).
const HOME_SLOT_SPACING := 64.0
## Tighter packing for larger enemy armies.
const ENEMY_HOME_SLOT_SPACING := 44.0
## Tint for enemy-owned props (e.g. walls). Enemy units use authored colors.
const ENEMY_TINT := Color(0.85, 0.25, 0.3, 1.0)

@export var march_speed: float = DEFAULT_MARCH_SPEED
@export var is_enemy: bool = false

var _opponent: Troop

@onready var flag_bearer: FlagBearer = get_node_or_null("FlagBearer") as FlagBearer
@onready var spawn_anchor: Node2D = get_node_or_null("SpawnAnchor") as Node2D


func _ready() -> void:
	add_to_group("troops")
	if spawn_anchor == null and not has_flag_bearer():
		spawn_anchor = Node2D.new()
		spawn_anchor.name = "SpawnAnchor"
		add_child(spawn_anchor)
		move_child(spawn_anchor, 0)
	call_deferred("_acquire_opponent")


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
		if unit.combat != null and unit.combat.formation_line == formation_line:
			count += 1
	return count


func apply_power_tier(tier: UnitStatsData.PowerTier) -> void:
	for unit in get_units():
		unit.apply_power_tier(tier)


func reset_for_scenario(spawn_global: Vector2) -> void:
	if has_flag_bearer():
		flag_bearer.global_position = spawn_global
		flag_bearer.reset_combat_state()
	elif spawn_anchor != null:
		spawn_anchor.global_position = spawn_global


func get_facing() -> float:
	return -1.0 if is_enemy else 1.0


func get_home_slot_spacing() -> float:
	return ENEMY_HOME_SLOT_SPACING if is_enemy else HOME_SLOT_SPACING


## Living unit furthest from the enemy (army rear).
func get_rearmost_living_unit() -> Unit:
	var facing := get_facing()
	var rearmost: Unit = null
	for unit in get_living_units():
		if (
			rearmost == null
			or facing * (unit.global_position.x - rearmost.global_position.x) < 0.0
		):
			rearmost = unit
	return rearmost


## Living unit that has advanced furthest toward the enemy (army front).
func get_frontmost_living_unit() -> Unit:
	var facing := get_facing()
	var frontmost: Unit = null
	for unit in get_living_units():
		if (
			frontmost == null
			or facing * (unit.global_position.x - frontmost.global_position.x) > 0.0
		):
			frontmost = unit
	return frontmost


func _anchor_formation_behind_rearmost(delta: float) -> void:
	var rearmost := get_rearmost_living_unit()
	if rearmost == null:
		if has_flag_bearer():
			flag_bearer.stop()
		return
	var facing := get_facing()
	# Predict one step so we track a retreating rearmost without lag/overshoot chatter.
	var target_x := (
		rearmost.global_position.x
		+ rearmost.velocity.x * delta
		- facing * FLAG_REAR_CLEARANCE
	)
	if has_flag_bearer():
		flag_bearer.follow_anchor_x(target_x, Unit.BASE_MOVE_SPEED, delta)
	elif spawn_anchor != null:
		spawn_anchor.global_position.x = target_x


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


func has_flag_bearer() -> bool:
	return flag_bearer != null and is_instance_valid(flag_bearer)


func get_flag_global_x() -> float:
	return get_formation_anchor_global().x


func get_flag_global_position() -> Vector2:
	return get_formation_anchor_global()


func get_formation_anchor_global() -> Vector2:
	if has_flag_bearer():
		return flag_bearer.global_position
	if spawn_anchor != null and is_instance_valid(spawn_anchor):
		return spawn_anchor.global_position
	return global_position


func _physics_process(delta: float) -> void:
	_acquire_opponent()
	if has_flag_bearer():
		if flag_bearer.is_in_knockback():
			return
		if is_wiped_out():
			flag_bearer.stop()
			return
		_anchor_formation_behind_rearmost(delta)
		return
	if spawn_anchor == null:
		return
	if is_wiped_out():
		return
	_anchor_formation_behind_rearmost(delta)
