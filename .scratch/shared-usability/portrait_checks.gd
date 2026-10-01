extends RefCounted

const PREVIEW_CHECKS := preload("res://.scratch/shared-usability/preview_checks.gd")
const TRAINING_SCENE := preload("res://assets/base/pupation/pupation_confirm_dialog.tscn")


static func run(host: Control) -> int:
	var failures := 0
	var dialog: PupationConfirmDialog = TRAINING_SCENE.instantiate()
	var horn := PREVIEW_CHECKS.make_unit([WeaponSchool.Id.MACE, WeaponSchool.Id.BOW], true)
	dialog.setup(horn, WeaponSchool.Id.BOW)
	host.add_child(dialog)
	failures += await _sample_cycle(host, dialog, false, "horn-bow")
	await _snapshot(host, "after")
	# Both sides must recompute their common scale when available portrait space changes.
	var before_resize := _appearance(dialog, "Left").scale.x
	for side in ["Left", "Right"]:
		(dialog._comparison.get_node("%%%sPortrait" % side) as Control).custom_minimum_size.y = 210.0
	failures += await _sample_cycle(host, dialog, false, "resized")
	failures += _check(_appearance(dialog, "Left").scale.x > before_resize,
		"larger hosts recompute the shared fit")
	for side in ["Left", "Right"]:
		(dialog._comparison.get_node("%%%sPortrait" % side) as Control).custom_minimum_size.y = 140.0
	var child := PREVIEW_CHECKS.make_unit([], false)
	dialog.setup(child, WeaponSchool.Id.BOW)
	failures += await _sample_cycle(host, dialog, true, "child-bow")
	await _snapshot(host, "child")
	var sword := PREVIEW_CHECKS.make_unit([WeaponSchool.Id.SWORD], true)
	dialog.setup(sword, WeaponSchool.Id.SWORD)
	failures += await _sample_cycle(host, dialog, false, "great-sword")
	var spear := PREVIEW_CHECKS.make_unit([WeaponSchool.Id.SPEAR], true)
	spear.body_mutation = load("res://assets/base/nursery/mutations/body/fat.tres") as MutationData
	spear.cap_mutation = load("res://assets/base/nursery/mutations/cap/inky.tres") as MutationData
	dialog.setup(spear, WeaponSchool.Id.SPEAR)
	failures += await _sample_cycle(host, dialog, false, "great-spear-mutated")
	await _snapshot(host, "mutated")
	dialog.setup(horn, WeaponSchool.Id.BOW)
	failures += await _sample_cycle(host, dialog, false, "reused-horn-bow")
	await _snapshot(host, "reused")
	dialog.queue_free()
	await host.get_tree().process_frame
	# Unit cards and normal portraits retain their authored mount scale and feet anchor.
	var normal_host := Control.new()
	normal_host.size = Vector2(200, 140)
	host.add_child(normal_host)
	var normal := horn.mount_portrait(normal_host, 0.7)
	failures += _check(normal.scale.is_equal_approx(Vector2.ONE * 0.7), "normal portrait authored scale")
	failures += _check(normal.position.is_equal_approx(Vector2(100, 136)), "normal portrait feet anchor")
	normal_host.size = Vector2(240, 180)
	await host.get_tree().process_frame
	failures += _check(normal.scale.is_equal_approx(Vector2.ONE * 0.7)
		and normal.position.is_equal_approx(Vector2(120, 176)), "normal portrait resize remains unchanged")
	normal_host.queue_free()
	print("PORTRAIT_CHECKS failures=", failures)
	return failures


static func _sample_cycle(host: Control, dialog: PupationConfirmDialog, is_child: bool, label: String) -> int:
	var failures := 0
	# Settle containers/deferred fit, then sample a complete authored 1.2s idle loop.
	for frame in 4:
		await host.get_tree().process_frame
	var left := _appearance(dialog, "Left")
	var right := _appearance(dialog, "Right")
	for sample_index in 5:
		var left_body := left.transform * left.visual_rect_local(false, true)
		var right_body := right.transform * right.visual_rect_local(false, true)
		failures += _check(left.scale.is_equal_approx(right.scale), label + " shares adult fit scale")
		failures += _check(absf(left.animation_player.current_animation_position
			- right.animation_player.current_animation_position) < 0.001, label + " idle phases match")
		if is_child:
			failures += _check(left_body.size.y < right_body.size.y * 0.85,
				label + " preserves smaller authored Child body")
		else:
			failures += _check(left_body.size.is_equal_approx(right_body.size),
				label + " Adult body dimensions match")
		for side in ["Left", "Right"]:
			failures += PREVIEW_CHECKS._check_portrait_alignment(dialog._comparison, side)
			var appearance := _appearance(dialog, side)
			var portrait := appearance.get_parent() as Control
			var painted := appearance.transform * appearance.visual_rect_local(true, true)
			failures += _check(Rect2(Vector2.ZERO, portrait.size).grow(1.0).encloses(painted),
				label + " " + side + " all painted art fits during idle")
			failures += _check_weapon_pixels(appearance, portrait, label + " " + side)
		if sample_index == 0:
			print("PORTRAIT_GEOMETRY ", label, " roots=", left.scale, "/", right.scale,
				" body_heights=", left_body.size.y, "/", right_body.size.y,
				" phases=", left.animation_player.current_animation_position, "/", right.animation_player.current_animation_position)
		if sample_index < 4:
			await host.get_tree().create_timer(0.3).timeout
	return failures


static func _check_weapon_pixels(appearance: UnitAppearance, portrait: Control, label: String) -> int:
	var failures := 0
	# Independent bounds check from texture alpha for the current held-weapon sprites.
	for mount in [appearance.weapon_mount, appearance.offhand_mount]:
		if mount == null:
			continue
		for node in mount.find_children("*", "Sprite2D", true, false):
			var sprite := node as Sprite2D
			if not sprite.is_visible_in_tree() or sprite.texture == null:
				continue
			var used := Rect2(sprite.texture.get_image().get_used_rect())
			var local := Rect2(sprite.get_rect().position + used.position, used.size)
			var to_host := portrait.get_global_transform_with_canvas().affine_inverse() * sprite.get_global_transform_with_canvas()
			failures += _check(Rect2(Vector2.ZERO, portrait.size).grow(1.0).encloses(to_host * local),
				label + " visible weapon alpha stays inside clip")
	return failures


static func _appearance(dialog: PupationConfirmDialog, side: String) -> UnitAppearance:
	var portrait := dialog._comparison.get_node("%%%sPortrait" % side) as Control
	for child in portrait.get_children():
		if child is UnitAppearance:
			return child as UnitAppearance
	return null


static func _snapshot(host: Control, label: String) -> void:
	if not OS.get_cmdline_user_args().has("--visual"):
		return
	await RenderingServer.frame_post_draw
	host.get_viewport().get_texture().get_image().save_png("/tmp/usability-training-portrait-%s.png" % label)


static func _check(ok: bool, message: String) -> int:
	if ok:
		return 0
	push_error("PORTRAIT_CHECK failed: " + message)
	return 1
