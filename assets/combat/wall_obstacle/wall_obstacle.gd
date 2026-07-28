class_name WallObstacle
extends StaticBody2D

signal destroyed

var max_hp: int = 1
var current_hp: int = 1
var _dying: bool = false


func setup(hp: int) -> void:
	max_hp = maxi(hp, 1)
	current_hp = max_hp
	add_to_group("combat_obstacles")


func is_combat_obstacle() -> bool:
	return true


func take_damage(
	amount: int,
	_knockback_from: Vector2 = Vector2.ZERO,
	_knockback_force: float = 0.0,
	_killer: Node = null,
	_damage_type: WeaponData.DamageType = WeaponData.DamageType.SLASHING
) -> void:
	if _dying:
		return
	current_hp = maxi(current_hp - maxi(amount, 0), 0)
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
