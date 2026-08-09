extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var errs: Array[String] = []

	var child := UnitAppearance.instantiate_player_layers(false, null, null)
	if child == null:
		errs.append("child appearance null")
	else:
		var body := child.get_node_or_null("Sprite") as Sprite2D
		var cap := child.get_node_or_null("Cap") as Sprite2D
		if body == null or cap == null:
			errs.append("child missing Sprite/Cap")
		else:
			if body.modulate != UnitAppearance.DEFAULT_CHILD_BODY:
				errs.append("child body default tint %s" % body.modulate)
			if cap.modulate != UnitAppearance.DEFAULT_CHILD_CAP:
				errs.append("child cap default tint %s" % cap.modulate)
		if child.get_node_or_null("Sprite/WeaponFollow") == null:
			errs.append("child missing WeaponFollow on body")
		if child.get_node_or_null("Sprite/CapFollow") == null:
			errs.append("child missing CapFollow")
		child.free()

	var boom := load("res://assets/base/nursery/mutations/boom.tres") as MutationData
	var mini := load("res://assets/base/nursery/mutations/mini.tres") as MutationData
	var adult := UnitAppearance.instantiate_player_layers(true, mini, boom)
	if adult == null:
		errs.append("adult appearance null")
	else:
		var body := adult.get_node_or_null("Sprite") as Sprite2D
		var cap := adult.get_node_or_null("Cap") as Sprite2D
		if body == null or cap == null:
			errs.append("adult missing layers")
		else:
			if body.modulate != mini.tint:
				errs.append("mini body tint")
			if cap.modulate != boom.tint:
				errs.append("boom cap tint")
		# Silhouette after "remount": BodyShape size must stay base while root scales.
		var body_shape := adult.get_node_or_null("BodyShape") as CollisionShape2D
		var hurt := adult.get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D
		var base_body_size := (body_shape.shape as RectangleShape2D).size
		var base_hurt_size := (hurt.shape as RectangleShape2D).size
		# Simulate combat remount: reparent BodyShape off the appearance before silhouette.
		var host := Node2D.new()
		add_child(host)
		host.add_child(adult)
		var global_xform := body_shape.global_transform
		body_shape.reparent(host)
		body_shape.global_transform = global_xform
		adult.apply_body_mutation_silhouette(mini)
		if not adult.scale.is_equal_approx(mini.silhouette_scale):
			errs.append("silhouette scale %s != %s" % [adult.scale, mini.silhouette_scale])
		var remounted_size := (body_shape.shape as RectangleShape2D).size
		if remounted_size != base_body_size:
			errs.append("physics body shape changed")
		# Hurtbox remains under appearance so inherits root scale (shape resource unchanged).
		if (hurt.shape as RectangleShape2D).size != base_hurt_size:
			errs.append("hurtbox shape resource mutated")
		if not is_equal_approx(hurt.global_scale.x, mini.silhouette_scale.x):
			errs.append("hurtbox did not inherit silhouette scale")
		host.queue_free()

	# Portrait funnel ignores specialty strain scenes.
	var death_strain := load("res://assets/units/death_cap/death_cap_strain.tres") as UnitStrain
	var roster := RosterUnitData.create("Test", UnitStatsData.new(), null, death_strain)
	roster.cap_mutation = boom.duplicate(true) as MutationData
	roster.body_mutation = mini.duplicate(true) as MutationData
	var host_ctrl := Control.new()
	host_ctrl.size = Vector2(120, 120)
	add_child(host_ctrl)
	var portrait := roster.mount_portrait(host_ctrl, 0.55)
	if portrait == null:
		errs.append("portrait null")
	else:
		if portrait.scene_file_path.find("gen_child_appearance") < 0 \
			and portrait.name.find("GenChild") < 0 \
			and portrait.get_node_or_null("Cap") == null:
			errs.append("portrait did not use layered generalist")
		var body := portrait.get_node_or_null("Sprite") as Sprite2D
		var cap := portrait.get_node_or_null("Cap") as Sprite2D
		if body == null or cap == null:
			errs.append("portrait missing layers")
		elif body.modulate != mini.tint or cap.modulate != boom.tint:
			errs.append("portrait layer tints wrong")
		var tier := UnitStatsData.tint_for_tier(roster.power_tier)
		if portrait.modulate != tier:
			errs.append("portrait tier modulate missing")

	if errs.is_empty():
		print("LAYER CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("LAYER ERRORS:")
		for e in errs:
			print(" - ", e)
		get_tree().quit(1)
