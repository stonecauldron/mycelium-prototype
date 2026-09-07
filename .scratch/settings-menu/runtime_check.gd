extends Node

var _failures: int = 0
var _visual: bool = false
var _had_settings: bool = false
var _settings_backup: PackedByteArray


func _ready() -> void:
	_visual = DisplayServer.get_name() != "headless"
	if _visual:
		_had_settings = FileAccess.file_exists(SettingsServer.PATH)
		if _had_settings:
			_settings_backup = FileAccess.get_file_as_bytes(SettingsServer.PATH)
			var backup := FileAccess.open("/private/tmp/settings-menu-preferences.backup", FileAccess.WRITE)
			backup.store_buffer(_settings_backup)
	get_tree().create_timer(50.0, true, false, true).timeout.connect(func() -> void: get_tree().quit(2))
	_run.call_deferred()


func _exit_tree() -> void:
	if _visual:
		if _had_settings:
			var file := FileAccess.open("user://settings.cfg", FileAccess.WRITE)
			file.store_buffer(_settings_backup)
		else:
			DirAccess.remove_absolute("user://settings.cfg")


func _check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		_failures += 1


func _wait(seconds: float = 0.1) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		get_tree().root.push_input(event, true)
	await _wait(0.04)


func _click(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		get_tree().root.push_input(event, true)
	await _wait(0.04)


func _button(menu: RunMenu, name: String) -> void:
	var button := menu.get_node("%" + name) as Control
	await _click(button.get_global_rect().get_center())


func _capture(name: String) -> void:
	if _visual:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/private/tmp/settings-menu-" + name + ".png")


func _button_feedback(menu: RunMenu, button_name: String) -> void:
	var button := menu.get_node("%" + button_name) as Button
	var snapshots: Array[PackedByteArray] = []
	get_tree().root.gui_release_focus()
	for state in ["normal", "hover", "pressed"]:
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(8, 8) if state == "normal" else button.get_global_rect().get_center()
		get_tree().root.push_input(motion, true)
		if state == "pressed":
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.position = motion.position
			press.pressed = true
			get_tree().root.push_input(press, true)
		await _wait(0.05)
		await RenderingServer.frame_post_draw
		snapshots.append(get_viewport().get_texture().get_image().get_data())
		await _capture(button_name + "-" + state)
	_check(snapshots[0] != snapshots[1], button_name + " visibly reacts to hover")
	_check(snapshots[1] != snapshots[2], button_name + " visibly reacts to press")
	# Release outside the button so testing the exit action cannot activate it.
	var move_off := InputEventMouseMotion.new()
	move_off.position = Vector2(8, 8)
	move_off.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_tree().root.push_input(move_off, true)
	await _wait(0.05)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = Vector2(8, 8)
	get_tree().root.push_input(release, true)
	await _wait(0.05)


func _scene(path: String) -> Node:
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	await _wait()
	return get_tree().current_scene


func _run() -> void:
	# Keep the check driver alive beside the actual current scene.
	get_tree().current_scene = null
	if _visual:
		# Let the native startup fullscreen animation finish before injecting input.
		await _wait(3.0)
	GameState.reset_run()
	var base := await _scene("res://assets/base/base.tscn")
	var menu := base.get_node("RunMenu") as RunMenu
	var colony := base.get_node("%ColonyScreen")
	var seal := colony.get("_seal_dialog") as SealChoiceDialog
	_check(seal != null and GameState.pending_seal_choice, "Base opens with blocking Seal choice")
	await _capture("base-seal")
	await _button(menu, "GearButton")
	_check(get_tree().paused and menu.get_node("%Overlay").visible, "Gear opens above Seal choice and pauses")
	_check(not base.can_process() and menu.can_process(), "Base pauses while menu processes")
	if _visual and "--button-states" in OS.get_cmdline_user_args():
		await _button(menu, "TitleButton")
		await _button_feedback(menu, "ConfirmButton")
		await _button_feedback(menu, "CancelButton")
		print("BUTTON FEEDBACK CHECK: ", _failures, " failures")
		get_tree().quit(0 if _failures == 0 else 1)
		return
	await _capture("paused")
	var focus_stays_inside := true
	for i in 6:
		await _key(KEY_TAB)
		var focused := get_tree().root.gui_get_focus_owner()
		focus_stays_inside = focus_stays_inside and focused != null and menu.get_node("%MenuPage").is_ancestor_of(focused)
	_check(focus_stays_inside, "Keyboard focus stays inside active menu")
	await _button(menu, "SettingsButton")
	_check(menu.get_node("%SettingsPage").visible and get_tree().paused, "Settings opens without unpausing")
	await _capture("settings")
	if _visual and "--confirmation-only" not in OS.get_cmdline_user_args():
		var before_fullscreen := SettingsServer.is_fullscreen()
		await _button(menu, "FullscreenButton")
		await _wait(2.0)
		_check(SettingsServer.is_fullscreen() != before_fullscreen and get_tree().paused, "Fullscreen toggles while paused")
		var cfg := ConfigFile.new()
		cfg.load(SettingsServer.PATH)
		_check(cfg.get_value("display", "fullscreen") == not before_fullscreen, "Fullscreen preference saved")
		SettingsServer.call("_apply_fullscreen", before_fullscreen)
		await _wait(2.0)
		SettingsServer.call("_load")
		await _wait(2.0)
		_check(SettingsServer.is_fullscreen() != before_fullscreen, "Reloading settings reapplies saved fullscreen")
		await _button(menu, "FullscreenButton")
		await _wait(2.0)
		_check(SettingsServer.is_fullscreen() == before_fullscreen, "Fullscreen can return to original mode")
		if "--fullscreen-only" in OS.get_cmdline_user_args():
			print("FULLSCREEN CHECK: ", _failures, " failures")
			get_tree().quit(0 if _failures == 0 else 1)
			return
	await _key(KEY_ESCAPE)
	_check(menu.get_node("%MenuPage").visible and get_tree().paused, "Escape from Settings returns to paused menu")
	await _button(menu, "SettingsButton")
	await _click(Vector2(8, 8))
	_check(not get_tree().paused and not menu.get_node("%Overlay").visible, "Outside Settings closes whole menu and resumes")
	_check(is_instance_valid(seal) and GameState.pending_seal_choice, "Closing preserves Seal choice")
	await _key(KEY_ESCAPE)
	_check(get_tree().paused, "Escape opens menu over blocking choice")
	await _button(menu, "TitleButton")
	_check(get_tree().current_scene == base and menu.get_node("%ConfirmationPage").visible, "Return to title requires confirmation")
	await _capture("confirm")
	await _button(menu, "CancelButton")
	_check(get_tree().paused and menu.get_node("%MenuPage").visible, "Cancel keeps menu paused")
	await _button(menu, "QuitButton")
	_check(menu.get_node("%ConfirmationHeading").text == "Quit?" and get_tree().current_scene == base, "Quit requires confirmation")
	await _capture("confirm-quit")
	await _key(KEY_ESCAPE)
	_check(get_tree().paused and menu.get_node("%MenuPage").visible, "Escape returns to paused menu")
	await _button(menu, "QuitButton")
	await _click(Vector2(8, 8))
	_check(not get_tree().paused, "Outside confirmation cancels exit and resumes")
	if "--confirmation-only" in OS.get_cmdline_user_args():
		print("CONFIRMATION CHECK: ", _failures, " failures")
		get_tree().quit(0 if _failures == 0 else 1)
		return
	# Complete Seal pick to verify the next blocking choice too.
	seal.call("_on_card_pressed", seal.get("_offers")[0])
	seal.call("_on_confirm_pressed")
	await _wait()
	var starter := colony.get("_starter_dialog") as StarterChoiceDialog
	_check(starter != null, "Starter package choice follows Seal")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_check(is_instance_valid(starter) and not GameState.troop.is_seeded(), "Opening/closing preserves Starter choice")
	starter.call("_on_card_pressed", &"great_sword_spear")
	starter.call("_on_confirm_pressed")
	await _wait()
	await _capture("base")
	await _key(KEY_ESCAPE)
	await _button(menu, "TitleButton")
	await _button(menu, "ConfirmButton")
	await _wait(1.1)
	_check(get_tree().current_scene.scene_file_path.ends_with("title.tscn") and not get_tree().paused, "Base return reaches unpaused title")
	var normal_ticks := Engine.physics_ticks_per_second
	var normal_steps := Engine.max_physics_steps_per_frame
	for speed in [1, 2, 4]:
		GameState.combat_fast_forward = speed
		var enemy_data := load("res://assets/units/enemies/solar_sword/solar_sword_unit.tres") as EnemyUnitData
		BattleLaunch.set_enemy_roster([RosterUnitData.create_enemy("Solar Sword", enemy_data.make_stats(), enemy_data)])
		var stage := await _scene("res://assets/combat/combat_stage/combat_stage.tscn")
		menu = stage.get_node("RunMenu") as RunMenu
		var ally := stage.get_node("World/PlayerTroop").get_living_units()[0] as Unit
		var projectile := Projectile.new()
		projectile.explode_delay = 0.1
		projectile.aoe_radius = 1.0
		stage.get_node("World").add_child(projectile)
		projectile.global_position = Vector2.ZERO
		projectile.call("_arm_fuse")
		stage.call("_schedule_zombie_respawn", ally.roster_data, true, 0)
		await _key(KEY_ESCAPE)
		var before_position := ally.global_position
		var before_hp := ally.current_hp
		var before_elapsed: float = stage.get("_battle_elapsed_sec")
		await _wait(2.1)
		_check(get_tree().paused and not ally.can_process(), "%dx units are paused" % speed)
		_check(ally.global_position == before_position and ally.current_hp == before_hp, "%dx movement/HP freeze" % speed)
		_check(stage.get("_battle_elapsed_sec") == before_elapsed, "%dx Acid Rain clock freezes" % speed)
		_check(is_instance_valid(projectile), "%dx projectile fuse freezes" % speed)
		_check(stage.get("_pending_player_zombie_respawns") == 1, "%dx zombie respawn freezes" % speed)
		await _capture("combat-%dx" % speed)
		await _button(menu, "ResumeButton")
		_check(not get_tree().paused and Engine.time_scale == float(speed), "%dx Resume restores speed" % speed)
		_check(Engine.physics_ticks_per_second == normal_ticks * speed, "%dx physics tick rate preserved" % speed)
		await _wait(0.15)
		_check(not is_instance_valid(projectile), "%dx projectile fuse resumes" % speed)
		stage.call("request_hitstop")
		await _key(KEY_ESCAPE)
		await _wait(0.1)
		_check(stage.get("_hitstop_active") and Engine.time_scale < 1.0, "%dx hitstop freezes while paused" % speed)
		await _button(menu, "TitleButton")
		await _button(menu, "ConfirmButton")
		await _wait(1.1)
		_check(get_tree().current_scene.scene_file_path.ends_with("title.tscn") and not get_tree().paused, "%dx combat return reaches unpaused title" % speed)
		_check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == normal_ticks and Engine.max_physics_steps_per_frame == normal_steps, "%dx exit restores engine timing" % speed)
		_check(GameState.combat_fast_forward == speed, "%dx preference survives exit" % speed)
	for path in ["title/title", "day_summary/day_summary", "victory/victory", "game_over/game_over"]:
		var screen := await _scene("res://assets/%s.tscn" % path)
		_check(screen.find_child("RunMenu", true, false) == null, "%s has no in-run menu" % path)
	print("SETTINGS MENU CHECK: ", _failures, " failures")
	get_tree().quit(0 if _failures == 0 else 1)
