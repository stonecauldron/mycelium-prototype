class_name BoomCapExplosion
extends Node2D

var _damage: int = 0
var _radius: float = 100.0
var _knockback: float = 420.0
var _source: Unit = null
var _spent: bool = false


func trigger(strength: int, radius: float, knockback: float, source: Unit) -> void:
	_damage = maxi(strength, 1)
	_radius = radius
	_knockback = knockback
	_source = source
	_apply_damage()
	_flash()
	var timer := get_tree().create_timer(0.45)
	await timer.timeout
	queue_free()


func _apply_damage() -> void:
	if _spent:
		return
	_spent = true
	var units: Array[Node] = get_tree().get_nodes_in_group("units")
	for node in units:
		var unit := node as Unit
		if unit == null or not is_instance_valid(unit) or unit == _source:
			continue
		if unit.global_position.distance_to(global_position) > _radius:
			continue
		unit.take_damage(
			_damage,
			global_position,
			_knockback,
			_source,
			WeaponData.DamageType.SLASHING
		)
	for node in get_tree().get_nodes_in_group("combat_obstacles"):
		if not is_instance_valid(node) or not node.has_method("take_damage"):
			continue
		if (node as Node2D).global_position.distance_to(global_position) > _radius:
			continue
		node.call("take_damage", _damage, global_position, _knockback, _source)


func _flash() -> void:
	var poly := Polygon2D.new()
	poly.color = Color(1.0, 0.45, 0.15, 0.55)
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * _radius)
	poly.polygon = pts
	add_child(poly)
	var tween := create_tween()
	tween.tween_property(poly, "modulate:a", 0.0, 0.4)
