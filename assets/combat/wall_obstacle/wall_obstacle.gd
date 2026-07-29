class_name WallObstacle
extends CharacterBody2D

signal destroyed

const _STAT_CHIP_SCENE := preload("res://assets/ui/stat_chip/stat_chip.tscn")
const _HP_ICON := preload("res://assets/base/unit_card/hp_icon.png")
const HP_CHIP_GAP := 4.0
## Dedicated layers so each army only collides with the opposing side's walls.
const COLLISION_WORLD := 1
const COLLISION_PLAYER_WALLS := 32
const COLLISION_ENEMY_WALLS := 64

var max_hp: int = 1
var current_hp: int = 1
## Matches Troop.is_enemy of the army that spawned this wall.
var is_enemy: bool = false
var _dying: bool = false
var _settled: bool = false
var _hp_chip: StatChip = null

@onready var _body_shape: CollisionShape2D = $CollisionShape2D


func setup(hp: int, enemy_owned: bool = false) -> void:
	max_hp = maxi(hp, 1)
	current_hp = max_hp
	is_enemy = enemy_owned
	add_to_group("combat_obstacles")
	_apply_collision_layers()
	_ensure_hp_chip()


func _apply_collision_layers() -> void:
	# Stand on the floor; only the opposing army bumps into this wall.
	collision_mask = COLLISION_WORLD
	collision_layer = COLLISION_ENEMY_WALLS if is_enemy else COLLISION_PLAYER_WALLS


func _physics_process(delta: float) -> void:
	if _dying or _settled:
		return
	velocity += get_gravity() * delta
	move_and_slide()
	if is_on_floor():
		velocity = Vector2.ZERO
		_settled = true
		# Stay solid for opposing units; no further physics needed.
		set_physics_process(false)


func is_combat_obstacle() -> bool:
	return true


func take_damage(
	amount: int,
	_knockback_from: Vector2 = Vector2.ZERO,
	_knockback_force: float = 0.0,
	_killer: Node = null,
	damage_type: WeaponData.DamageType = WeaponData.DamageType.SLASHING
) -> void:
	if _dying:
		return
	var applied := maxi(amount, 0)
	if damage_type == WeaponData.DamageType.BLUNT:
		applied *= 2
	current_hp = maxi(current_hp - applied, 0)
	if _hp_chip != null and is_instance_valid(_hp_chip):
		_hp_chip.set_value(current_hp)
	modulate = Color(1.0, 0.7, 0.7, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	if current_hp <= 0:
		_die()


func _die() -> void:
	if _dying:
		return
	_dying = true
	destroyed.emit()
	queue_free()


func _ensure_hp_chip() -> void:
	if _hp_chip != null and is_instance_valid(_hp_chip):
		_hp_chip.position = _hp_chip_local_position()
		_hp_chip.set_value(current_hp)
		return
	_hp_chip = _STAT_CHIP_SCENE.instantiate() as StatChip
	_hp_chip.icon = _HP_ICON
	_hp_chip.position = _hp_chip_local_position()
	_hp_chip.z_index = 10
	add_child(_hp_chip)
	_hp_chip.set_value(current_hp)


func _hp_chip_local_position() -> Vector2:
	var half := StatChip.CHIP_SIZE * 0.5
	var pos := Vector2(-half.x, HP_CHIP_GAP)
	if _body_shape != null and _body_shape.shape is RectangleShape2D:
		var rect := _body_shape.shape as RectangleShape2D
		var bottom_y := _body_shape.position.y + rect.size.y * 0.5
		pos = Vector2(_body_shape.position.x - half.x, bottom_y + HP_CHIP_GAP)
	return pos
