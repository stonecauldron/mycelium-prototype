extends Node

const _DIALOG := preload("res://assets/base/pupation/pupation_confirm_dialog.tscn")
const _SAMPLES := 60


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(42)
	var unit := RosterUnitData.new()
	unit.display_name = "Darwin"
	unit.stats = UnitStatsData.new()
	unit.weapon_trainings = [WeaponSchool.Id.SHIELD]
	unit.promote_to_imago()
	var dialog: PupationConfirmDialog = _DIALOG.instantiate()
	dialog.setup(unit, WeaponSchool.Id.BOW)
	add_child(dialog)
	await get_tree().process_frame
	await get_tree().process_frame
	var failures := _check_portrait(dialog.get_node("%RightPortrait"), "Adult Umbrella Shield")
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[0])
	for is_adult in [false, true]:
		for first in WeaponSchool.COUNT:
			for second in range(first, WeaponSchool.COUNT):
				var sample := RosterUnitData.new()
				sample.display_name = "Portrait sample"
				sample.stats = UnitStatsData.new()
				sample.weapon_trainings = [first, first]
				if is_adult:
					sample.promote_to_imago()
				else:
					sample.sync_weapon_from_trainings()
				dialog.setup(sample, second)
				await get_tree().process_frame
				await get_tree().process_frame
				var label := "%s %s + %s" % [
					"Adult" if is_adult else "Child",
					WeaponSchool.display_name(first), WeaponSchool.display_name(second),
				]
				failures += _check_portrait(dialog.get_node("%RightPortrait"), label + " result")
				if not is_adult:
					failures += _check_portrait(dialog.get_node("%LeftPortrait"), label + " before")
	print("Portrait containment: ", "PASS" if failures == 0 else "FAIL", " (", failures, " clipped samples; all 10 combos, Adult and Child layouts)")
	get_tree().quit(0 if failures == 0 else 1)


func _check_portrait(host: Control, label: String) -> int:
	var appearance: UnitAppearance = host.get_child(0)
	var player := appearance.animation_player
	var length := 0.0
	if player != null:
		length = player.current_animation_length
		player.pause()
	var failures := 0
	for frame in _SAMPLES:
		if player != null and length > 0.0:
			player.seek(length * float(frame) / float(_SAMPLES), true)
		var bounds := appearance.transform * appearance.visual_rect_local(true)
		if not Rect2(Vector2.ZERO, host.size).encloses(bounds):
			if failures == 0:
				print("FAIL ", label, ": artwork=", bounds, " host=", host.size)
			failures += 1
	return failures
