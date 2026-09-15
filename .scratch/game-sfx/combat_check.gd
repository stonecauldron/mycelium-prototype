extends Node

var _heard: Dictionary[String, bool] = {}
var _failures: int = 0
var _recording := AudioEffectRecord.new()


func _ready() -> void:
	get_tree().create_timer(70.0, true, false, true).timeout.connect(func() -> void: get_tree().quit(2))
	_run.call_deferred()


func _process(_delta: float) -> void:
	for node in Audio.get_children():
		if node is AudioStreamPlayer and node.playing and node.stream != null and node.bus == &"SFX":
			_heard[node.stream.resource_path.get_file().get_basename()] = true


func _check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	if not condition:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _run() -> void:
	get_tree().current_scene = null
	# Capture only the SFX bus; do not change or save the user's volume preferences.
	var bus := AudioServer.get_bus_index(&"SFX")
	AudioServer.set_bus_mute(bus, false)
	AudioServer.set_bus_volume_db(bus, 0.0)
	var recording_index := AudioServer.get_bus_effect_count(bus)
	AudioServer.add_bus_effect(bus, _recording)
	_recording.set_recording_active(true)
	GameState.combat_fast_forward = 4
	get_tree().change_scene_to_file("res://assets/combat/combat_sandbox/combat_sandbox.tscn")
	await get_tree().scene_changed
	var sandbox := get_tree().current_scene
	await _wait(4.0)
	_check(_heard.has("battle_start"), "Battle start plays its cue")
	_check(_heard.has("slash") and _heard.has("hit_slash"), "Real melee combat emits attacks and impacts")
	var weapon := sandbox.get_node("%PlayerWeapon") as OptionButton
	var enemy := sandbox.get_node("%EnemyType") as OptionButton
	for i in enemy.item_count:
		if enemy.get_item_text(i) == "Stump":
			enemy.select(i)
	for choice in ["Bow", "Mortar", "Great Horn"]:
		for i in weapon.item_count:
			if weapon.get_item_text(i) == choice:
				weapon.select(i)
		(sandbox.get_node("%RunCustom") as Button).pressed.emit()
		await _wait(3.0)
	_check(_heard.has("bow"), "Bow releases use the bow sound")
	_check(_heard.has("throw") and _heard.has("explosion"), "Mortars throw and explode audibly")
	_check(_heard.has("horn"), "Great Horn uses its authored launch sound")
	_check(_heard.has("death"), "Fallen units emit a death pop")
	for i in enemy.item_count:
		if enemy.get_item_text(i) == "Solar Sword":
			enemy.select(i)
	for scenario in [
		["Great Sword", "great_slash", "great_hit_slash"],
		["Great Hammer", "great_swing", "great_hit_blunt"],
		["Great Spear", "great_throw", "great_hit_slash"],
		["Great Shield", "great_swing", "great_hit_blunt", "great_block"],
		["Great Bow", "great_bow", "great_hit_slash"],
		["Great Horn", "horn", "great_hit_blunt"],
	]:
		for i in weapon.item_count:
			if weapon.get_item_text(i) == scenario[0]:
				weapon.select(i)
		(sandbox.get_node("%RunCustom") as Button).pressed.emit()
		_heard.clear()
		await _wait(3.5)
		for cue in scenario.slice(1):
			_check(_heard.has(cue), "%s emits %s in real combat" % [scenario[0], cue])
	# Mix all six Great weapon families together so overlap is represented in the recording.
	sandbox.call("_set_matchup", func() -> Array:
		var great_weapons: Array = []
		for name in ["great_sword", "great_hammer", "great_shield", "great_spear", "great_bow", "giant_horn"]:
			great_weapons.append(load("res://assets/weapons/%s/%s.tres" % [name, name]))
		return [sandbox.call("_make_line", great_weapons), sandbox.call("_make_enemies",
			load("res://assets/units/enemies/solar_sword/solar_sword_unit.tres"), 24)]
	)
	_heard.clear()
	await _wait(8.0)
	_check(_heard.has("great_hit_slash") and _heard.has("great_hit_blunt"), "Crowded mixed Great army produces both impact families")
	await _check_direct_impacts(sandbox, weapon)
	_recording.set_recording_active(false)
	var recording := _recording.get_recording()
	_check(recording != null and recording.get_length() > 10.0, "The audio mixer produces a combat SFX recording")
	if recording != null:
		recording.save_to_wav("/private/tmp/mycelium-combat-sfx.wav")
	AudioServer.remove_bus_effect(bus, recording_index)
	get_tree().change_scene_to_file("res://assets/title/title.tscn")
	await get_tree().scene_changed
	# Release MP3 decoder voices before shutting down the audio server.
	Audio.stop_music()
	await _wait(0.6)
	print("Observed combat cues: ", _heard.keys())
	get_tree().quit(1 if _failures else 0)


func _check_direct_impacts(sandbox: Node, weapons: OptionButton) -> void:
	for i in weapons.item_count:
		if weapons.get_item_text(i) == "Great Shield":
			weapons.select(i)
	(sandbox.get_node("%RunCustom") as Button).pressed.emit()
	var world := sandbox.get_node("CombatStage/World")
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var attacker := world.get_node("PlayerTroop").get_living_units()[0] as Unit
	var target := world.get_node("EnemyTroop").get_living_units()[0] as Unit
	_check(attacker.weapon.damage_type == WeaponData.DamageType.SLASHING, "Great Shield retains its original damage type")
	var duplicate := attacker.weapon.duplicate() as WeaponData
	_check(duplicate.get_combat_profile().great_weapon_sfx, "Duplicated Great weapons retain their authored sounds")
	Audio.stop_gameplay_sfx()
	_heard.clear()
	target.take_damage(1, Vector2.ZERO, 0.0, attacker, WeaponData.DamageType.BLUNT, false)
	await _wait(0.1)
	_check(_heard.has("hit_blunt") and not _heard.has("great_hit_blunt"), "Status damage credited to a Great weapon keeps the normal impact")
	var hurtbox: HurtboxComponent = target.get("_appearance").hurtbox
	Audio.stop_gameplay_sfx()
	_heard.clear()
	hurtbox.receive_hit(1, Vector2.ZERO, 0.0, attacker, WeaponData.DamageType.SLASHING, true)
	await _wait(0.1)
	_check(_heard.has("great_hit_blunt"), "Great Shield melee contact uses the heavy bash impact")
	attacker.combat = load("res://assets/weapons/great_spear/great_spear.tres").get_combat_profile()
	Audio.stop_gameplay_sfx()
	_heard.clear()
	hurtbox.receive_hit(1, Vector2.ZERO, 0.0, attacker, WeaponData.DamageType.SLASHING, true)
	await _wait(0.1)
	_check(_heard.has("great_hit_slash"), "Great Spear close-range contact uses the heavy piercing impact")
	var shot := attacker.combat.resolve_projectile_scene().instantiate() as Projectile
	world.add_child(shot)
	shot.launch(attacker.global_position, target.global_position, 1, 0.0, attacker)
	attacker.free()
	Audio.stop_gameplay_sfx()
	_heard.clear()
	shot.call("_on_impact", hurtbox)
	await _wait(0.1)
	_check(_heard.has("great_hit_slash"), "A Great projectile keeps its impact after its owner is freed")
