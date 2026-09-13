extends Node

const _SANDBOX := preload("res://assets/combat/combat_sandbox/combat_sandbox.gd")
const _SANDBOX_SCENE := preload("res://assets/combat/combat_sandbox/combat_sandbox.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(12345)
	var sandbox := _SANDBOX.new()
	var imago := CheckBox.new()
	sandbox._imago_checkbox = imago
	var failures := 0
	var checks := 0
	for is_imago in [false, true]:
		imago.set_pressed_no_signal(is_imago)
		for option in sandbox._WEAPON_OPTIONS:
			var expected := option["weapon"] as WeaponData
			var unit: RosterUnitData = sandbox._make_unit(expected)
			checks += 1
			if (
				unit.weapon != expected
				or unit.is_imago != is_imago
				or unit.combat != expected.get_combat_profile()
			):
				failures += 1
				print("FAIL imago=", is_imago, " selected=", expected.display_name,
					" equipped=", unit.weapon.display_name, " actual_imago=", unit.is_imago)
	imago.free()
	sandbox.free()
	var scene := _SANDBOX_SCENE.instantiate()
	add_child(scene)
	var player_weapon := scene.get_node("%PlayerWeapon") as OptionButton
	var run_custom := scene.get_node("%RunCustom") as Button
	for is_imago in [false, true]:
		scene._imago_checkbox.button_pressed = is_imago
		for i in scene._WEAPON_OPTIONS.size():
			player_weapon.select(i)
			run_custom.pressed.emit()
			var expected := scene._WEAPON_OPTIONS[i]["weapon"] as WeaponData
			var fighter: Unit = scene._stage.player_troop.get_units()[0]
			var mount := fighter._appearance.weapon_mount
			checks += 1
			if (
				fighter.weapon != expected
				or fighter.combat != expected.get_combat_profile()
				or fighter.roster_data.is_imago != is_imago
				or mount.get_child_count() != 1
				or mount.get_child(0).scene_file_path != expected.appearance_scene.resource_path
			):
				failures += 1
				print("FAIL spawned imago=", is_imago, " selected=", expected.display_name)
	scene.free()
	print("SANDBOX WEAPONS: ", checks, " checks, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
