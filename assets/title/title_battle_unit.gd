class_name TitleBattleUnit
extends Unit

const _MARCH_SPEED := 240.0

var _marching: bool = false
var _marching_out: bool = false
var _march_target_x: float = 0.0


func march_in(target_x: float) -> void:
	_marching = true
	_marching_out = false
	_march_target_x = target_x
	collision_mask = COLLISION_WORLD
	_face_march_direction()


func has_arrived() -> bool:
	return absf(global_position.x - _march_target_x) < 2.0


func begin_fighting() -> void:
	_marching = false
	_setup_collision()


func march_out() -> void:
	_cancel_attack()
	_target = null
	_in_knockback = false
	_marching = true
	_marching_out = true
	collision_mask = COLLISION_WORLD
	_disable_hurtbox()
	_face_march_direction()


func _physics_process(delta: float) -> void:
	if not _marching:
		super._physics_process(delta)
		return
	velocity += get_gravity() * delta
	if _marching_out:
		velocity.x = _troop.get_facing() * _MARCH_SPEED
	else:
		var remaining := _march_target_x - global_position.x
		velocity.x = signf(remaining) * minf(_MARCH_SPEED, absf(remaining) / delta)
	move_and_slide()
	_update_locomotion_animation(delta)


## Attract-mode units use normal combat without run bonuses, rewards, or HUD text.
func is_player_controlled() -> bool:
	return false


func grant_hit_biomass(_hit_at: Node2D = null) -> void:
	pass


func _ensure_hp_chip() -> void:
	pass


func _spawn_damage_number(_amount: int) -> void:
	pass


func _spawn_combat_callout(_text: String, _kind: CombatCallout.Kind) -> void:
	pass


func _get_world_node() -> Node:
	return get_parent().get_parent().get_parent()
