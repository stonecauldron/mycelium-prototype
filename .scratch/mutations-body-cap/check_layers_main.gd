extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errs: Array[String] = []

	var child := UnitAppearance.compose_player(false, null, null)
	if child == null:
		errs.append("child appearance null")
	else:
		var body := child.get_node_or_null("Body/Sprite") as Sprite2D
		var cap_mount := child.get_node_or_null("Body/CapMount") as Node2D
		var cap: CanvasItem = null
		if cap_mount != null and cap_mount.get_child_count() > 0:
			cap = cap_mount.get_child(0) as CanvasItem
		if body == null or cap == null:
			errs.append("child missing Body/Sprite or CapMount/cap")
		else:
			if body.modulate != UnitAppearance.DEFAULT_CHILD_BODY:
				errs.append("child body default tint %s" % body.modulate)
			if cap.self_modulate != UnitAppearance.DEFAULT_CHILD_CAP:
				errs.append("child cap default tint %s" % cap.self_modulate)
		if child.get_node_or_null("Body/Sprite/WeaponFollow") == null:
			errs.append("child missing WeaponFollow on body")
		if child.get_node_or_null("Body/Sprite/CapMountFollow") == null:
			errs.append("child missing CapMountFollow")
		if child.get_node_or_null("BodyShape") == null:
			errs.append("child missing base BodyShape")
		if child.get_node_or_null("AnimationPlayer") == null:
			errs.append("child missing base AnimationPlayer")
		if child.get_node_or_null("Body/AnimationPlayer") != null:
			errs.append("body should not own AnimationPlayer")
		child.free()

	var boom := load("res://assets/base/nursery/mutations/cap/boom.tres") as MutationData
	var fat := load("res://assets/base/nursery/mutations/body/fat.tres") as MutationData
	var adult := UnitAppearance.compose_player(true, fat, boom)
	if adult == null:
		errs.append("adult appearance null")
	else:
		var body := adult.get_node_or_null("Body/Sprite") as Sprite2D
		var cap_mount := adult.get_node_or_null("Body/CapMount") as Node2D
		var cap: CanvasItem = null
		if cap_mount != null and cap_mount.get_child_count() > 0:
			cap = cap_mount.get_child(0) as CanvasItem
		if body == null or cap == null:
			errs.append("adult missing layers")
		else:
			if body.modulate != fat.tint:
				errs.append("fat body tint")
			if cap.self_modulate != boom.tint:
				errs.append("boom cap tint")
		var body_shape := adult.get_node_or_null("BodyShape") as CollisionShape2D
		var hurt := adult.get_node_or_null("Body/Hurtbox/CollisionShape2D") as CollisionShape2D
		if body_shape == null or hurt == null:
			errs.append("adult missing BodyShape or hurtbox")
		else:
			var base_body_size := (body_shape.shape as RectangleShape2D).size
			# Simulate combat remount: BodyShape leaves appearance; body mutation must not resize it.
			var host := Node2D.new()
			add_child(host)
			host.add_child(adult)
			var global_xform := body_shape.global_transform
			body_shape.reparent(host)
			body_shape.global_transform = global_xform
			var remounted_size := (body_shape.shape as RectangleShape2D).size
			if remounted_size != base_body_size:
				errs.append("physics body shape changed")
			# Shared idle should still target Body/Sprite after mount.
			adult.play_idle(false)
			var anim := adult.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if anim == null or not anim.has_animation(&"idle"):
				errs.append("shared idle missing on base")
			elif anim.current_animation != &"idle":
				errs.append("idle did not play")
			host.queue_free()

	# Portrait funnel composes Body/Cap from mutations.
	var roster := RosterUnitData.create("Test", UnitStatsData.new(), null)
	roster.cap_mutation = boom.duplicate(true) as MutationData
	roster.body_mutation = fat.duplicate(true) as MutationData
	var host_ctrl := Control.new()
	host_ctrl.size = Vector2(120, 120)
	add_child(host_ctrl)
	var portrait := roster.mount_portrait(host_ctrl, 0.55)
	if portrait == null:
		errs.append("portrait null")
	else:
		if portrait.get_node_or_null("Body") == null:
			errs.append("portrait did not compose Body")
		var body := portrait.get_node_or_null("Body/Sprite") as Sprite2D
		var cap_mount := portrait.get_node_or_null("Body/CapMount") as Node2D
		var cap: CanvasItem = null
		if cap_mount != null and cap_mount.get_child_count() > 0:
			cap = cap_mount.get_child(0) as CanvasItem
		if body == null or cap == null:
			errs.append("portrait missing layers")
		elif body.modulate != fat.tint or cap.self_modulate != boom.tint:
			errs.append("portrait layer tints wrong")
		var tier := UnitStatsData.tint_for_tier(roster.power_tier)
		if portrait.modulate != tier:
			errs.append("portrait tier modulate missing")
		if portrait.get_node_or_null("BodyShape") == null:
			errs.append("portrait missing base BodyShape")

	if errs.is_empty():
		print("LAYER CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("LAYER ERRORS:")
		for e in errs:
			print(" - ", e)
		get_tree().quit(1)
