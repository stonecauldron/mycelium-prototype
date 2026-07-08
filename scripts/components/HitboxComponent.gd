class_name HitboxComponent
extends Area2D

@export var damage: int = 0
@export var owner_unit: Unit

var _on_cooldown: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	monitoring = false


func enable_for_attack(attack_damage: int) -> void:
	damage = attack_damage
	_on_cooldown = false
	monitoring = true


func disable() -> void:
	monitoring = false


func _on_area_entered(area: Area2D) -> void:
	if not monitoring or _on_cooldown:
		return

	var hurtbox: HurtboxComponent = area as HurtboxComponent
	if hurtbox == null or owner_unit == null:
		return

	var target_unit: Unit = hurtbox.get_unit()
	if target_unit == null or target_unit == owner_unit:
		return
	if target_unit._army.is_enemy == owner_unit._army.is_enemy:
		return

	hurtbox.receive_hit(damage, owner_unit.global_position)
	_on_cooldown = true
