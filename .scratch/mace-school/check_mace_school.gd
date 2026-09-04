extends Node

const S := WeaponSchool.Id
const _UNIT := preload("res://assets/units/unit.tscn")
const _BASE := preload("res://assets/base/base.tscn")
const _STARTERS := preload("res://assets/base/troop_selection/starter_choice_dialog.tscn")
const _RECIPES := [
	[S.SWORD, S.SWORD, "Great Sword"], [S.SHIELD, S.SHIELD, "Great Shield"],
	[S.SPEAR, S.SPEAR, "Halberd"], [S.BOW, S.BOW, "Sniper"],
	[S.MACE, S.MACE, "Great Hammer"], [S.SWORD, S.SHIELD, "Sword and Shield"],
	[S.SWORD, S.SPEAR, "Lance"], [S.SWORD, S.BOW, "Crossbow"],
	[S.SHIELD, S.SPEAR, "Spear and Shield"], [S.SHIELD, S.BOW, "Umbrella Shield"],
	[S.SPEAR, S.BOW, "Spore Mortar"], [S.MACE, S.SWORD, "Warhammer"],
	[S.MACE, S.SHIELD, "Mace and Shield"], [S.MACE, S.SPEAR, "Polehammer"],
	[S.MACE, S.BOW, "Sling"],
]
var _failures: Array[String] = []
var _checks := 0
var _screenshots := false
var _projectile_checks := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("FAIL: " + label)


func _make_roster(schools: Array[int] = [], adult: bool = false) -> RosterUnitData:
	var unit := RosterUnitData.create("Sample", UnitStatsData.new(), null)
	unit.weapon_trainings = schools.duplicate()
	if adult:
		unit.promote_to_imago()
	unit.sync_weapon_from_trainings()
	return unit


func _run() -> void:
	_screenshots = "--screenshots" in OS.get_cmdline_user_args()
	GameState.seals = SealsCollection.new()
	_check_recipes()
	_check_training()
	_check_starters()
	await _check_paired_engagement()
	await _check_combat_and_attachments()
	await _check_projectiles_and_charges()
	_check(_projectile_checks == 4, "all four projectile integration cases completed")
	await _check_base_ui_and_compost()
	print("MACE SCHOOL: ", _checks, " checks, ", _failures.size(), " failures")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check_recipes() -> void:
	_check([S.SWORD, S.SHIELD, S.SPEAR, S.BOW, S.MACE] == [0, 1, 2, 3, 4], "stable school IDs")
	_check(WeaponSchool.DISPLAY_ORDER == [S.SWORD, S.MACE, S.SHIELD, S.SPEAR, S.BOW], "school display order")
	for school in WeaponSchool.COUNT:
		var base := WeaponSchool.resolve_weapon([school])
		_check(base.display_name == WeaponSchool.display_name(school), "base school " + str(school))
	var paths: Dictionary = {}
	for recipe in _RECIPES:
		var weapon := WeaponSchool.resolve_weapon([recipe[0], recipe[1]])
		_check(weapon != null and weapon.display_name == recipe[2], "recipe " + str(recipe))
		_check(WeaponSchool.resolve_weapon([recipe[1], recipe[0]]) == weapon, "reversed recipe " + str(recipe))
		_check(weapon.icon != null and weapon.appearance_scene != null, "art " + weapon.display_name)
		paths[weapon.resource_path] = true
	_check(paths.size() == 15, "15 distinct combo identities")
	var crossbow := WeaponSchool.resolve_weapon([S.SWORD, S.BOW])
	_check(crossbow.damage_type == WeaponData.DamageType.SLASHING, "Crossbow non-blunt")
	var sling := WeaponSchool.resolve_weapon([S.MACE, S.BOW])
	var sling_projectile := sling.projectile_scene.instantiate() as Projectile
	var bolt := crossbow.projectile_scene.instantiate() as Projectile
	_check(sling.damage_type == WeaponData.DamageType.BLUNT, "Sling blunt")
	_check(sling_projectile.launch_angle_deg == bolt.launch_angle_deg, "Sling launch angle")
	_check(sling_projectile.fallback_speed == bolt.fallback_speed, "Sling fallback speed")
	_check(sling_projectile.max_lifetime == bolt.max_lifetime, "Sling projectile lifetime")
	var origin := Vector2(0, 500)
	var target := Vector2(700, 650)
	_check(sling_projectile._compute_launch_velocity(origin, target).is_equal_approx(bolt._compute_launch_velocity(origin, target)), "Sling trajectory matches Crossbow")
	sling_projectile.free()
	bolt.free()
	for recipe in [[S.MACE, S.SPEAR], [S.SPEAR, S.SHIELD]]:
		var hybrid := WeaponSchool.resolve_weapon(recipe)
		_check(hybrid.is_hybrid_engagement() and hybrid.uses_throw_projectile() and hybrid.uses_melee_hitbox(), "hybrid " + hybrid.display_name)


func _check_training() -> void:
	_check(WeaponSchool.school_stat_deltas(S.MACE) == WeaponSchool.school_stat_deltas(S.SWORD), "Mace stat gains match Sword")
	var child := _make_roster()
	_check(child.apply_pupation_training(S.MACE), "Child Mace training")
	_check([child.stats.strength, child.stats.dex, child.stats.con] == [8, 4, 7], "Child Mace stats")
	_check(child.is_adult_stage() and child.weapon.display_name == "Mace", "Child emerges as Mace Adult")
	_check(child.apply_pupation_training(S.MACE), "Adult Mace training")
	_check([child.stats.strength, child.stats.dex, child.stats.con] == [8, 4, 7], "Adult stats unchanged")
	_check(child.weapon.display_name == "Great Hammer", "second Mace becomes Great Hammer")
	_check(child.apply_pupation_training(S.SHIELD), "Adult history replacement")
	_check(child.weapon_trainings == [S.MACE, S.SHIELD] and child.weapon.display_name == "Mace and Shield", "oldest school evicted")
	GameState.troop = TroopData.new()
	GameState.pupation = PupationData.new()
	GameState.biomass = BiomassData.new()
	GameState.biomass.amount = 20
	var trainee := _make_roster()
	var keeper := _make_roster()
	GameState.troop.seed_if_empty([trainee, keeper])
	_check(GameState.try_cocoon_for_pupation(trainee, S.MACE), "Mace cocoon accepts Child")
	_check(GameState.biomass.amount == 17 and GameState.pupation.get_days_remaining(S.MACE) == 1, "training cost/duration")
	_check(not GameState.can_cocoon_for_pupation(keeper, S.SWORD), "training preserves last fighter")
	_check(GameState.try_cancel_pupation(S.MACE), "Mace cancel")
	_check(GameState.biomass.amount == 20 and trainee.weapon_trainings.is_empty(), "cancel refund, no training")
	trainee.cocoon_duration_days = 0
	_check(GameState.try_cocoon_for_pupation(trainee, S.MACE), "instant Child Mace training")
	_check(trainee.weapon.display_name == "Mace" and GameState.pupation.get_occupant(S.MACE) == null, "instant emerge")
	_check(GameState.try_cocoon_for_pupation(trainee, S.MACE), "Adult Mace retraining")
	_check(GameState.pupation.get_days_remaining(S.MACE) == 1, "Adult ignores Child duration override")
	GameState.emerge_pupations()
	_check(trainee.weapon.display_name == "Great Hammer", "Adult daily emerge")
	_check([trainee.stats.strength, trainee.stats.dex, trainee.stats.con] == [8, 4, 7], "Adult emerge keeps stats")


func _check_starters() -> void:
	_check(StarterPackages.all_ids().size() == 5, "five starter packages")
	var units := StarterPackages.build_units(&"great_hammer")
	_check(units.size() == 2, "Breakers includes hidden Child")
	for unit in units:
		_check(unit.power_tier == UnitStatsData.PowerTier.COMMON, "common starter")
		if unit.is_adult_stage():
			_check(unit.generation == 2 and unit.weapon_trainings == [S.MACE, S.MACE], "Breakers Adult identity")
			_check(unit.weapon.display_name == "Great Hammer", "Breakers weapon")
			_check(unit.stats.strength >= 10 and unit.stats.strength <= 12, "two full STR gains")
			_check(unit.stats.dex >= 2 and unit.stats.dex <= 4, "two DEX penalties")
			_check(unit.stats.con >= 8 and unit.stats.con <= 10, "two full CON gains")
		else:
			_check(unit.generation == 1 and unit.weapon_trainings.is_empty(), "untrained generation-I Child")


func _check_combat_and_attachments() -> void:
	var troop := Troop.new()
	var units := Node2D.new()
	units.name = "Units"
	troop.add_child(units)
	add_child(troop)
	troop.set_physics_process(false)
	for school in [S.SWORD, S.MACE, S.SPEAR]:
		for adult in [false, true]:
			var roster := _make_roster([school, S.SHIELD], adult)
			roster.stats.con = 99
			var unit: Unit = _UNIT.instantiate()
			unit.roster_data = roster
			unit.stats = roster.stats
			units.add_child(unit)
			unit.set_physics_process(false)
			var base := WeaponSchool.resolve_weapon([school])
			var profile := unit.combat
			_check(profile.base_damage == base.base_damage and profile.attack_interval == base.attack_interval and profile.damage_stat == base.damage_stat, "paired normal offense")
			_check(profile.outgoing_damage_multiplier == 1.0, "no outgoing penalty")
			_check(unit._get_attack_damage(false) == base.base_damage + unit.stats.get_damage_bonus(base.damage_stat), "runtime normal attack damage")
			_check(profile.blocks_charges, "paired charge block")
			var hp := unit.current_hp
			unit.take_damage(20, unit.global_position - Vector2(10, 0), 200.0)
			_check(unit.current_hp == hp - 10 and is_equal_approx(unit.velocity.x, 100), "half non-blunt damage/knockback")
			hp = unit.current_hp
			unit.take_damage(20, Vector2.ZERO, 0.0, null, WeaponData.DamageType.BLUNT)
			_check(unit.current_hp == hp - 20, "blunt bypasses shield")
			var appearance := unit._appearance
			var offhand := appearance.offhand_mount
			var main := appearance.weapon_mount
			_check(offhand != null and offhand.get_child_count() == 1, "paired offhand mounted")
			_check(offhand.get_parent() == main.get_parent() and offhand.get_index() < main.get_index(), "independent mount and draw order")
			unit._play_melee_swing()
			_check(not is_zero_approx(main.rotation) and is_zero_approx(offhand.rotation), "swing rotates main weapon only")
			unit._set_held_weapon_visible(false)
			_check(not main.is_visible_in_tree() and offhand.is_visible_in_tree(), "throw hides main weapon only")
			unit._set_held_weapon_visible(true)
			unit._reset_weapon_swing()
			appearance.animation_player.pause()
			if unit._squash_tween != null:
				unit._squash_tween.kill()
			await get_tree().process_frame
			var before := offhand.global_position
			var body := appearance.sprite.get_parent() as Node2D
			var expected := body.to_global(appearance.sprite.position + Vector2(0, -12)) - body.to_global(appearance.sprite.position)
			appearance.sprite.position += Vector2(0, -12)
			await get_tree().process_frame
			_check(offhand.global_position.is_equal_approx(before + expected), "shield follows body movement")
			unit._visual.scale.x = -1
			_check(offhand.global_position.x > main.global_position.x, "shield mirrors with unit")
			appearance.mount_weapon_appearance(base)
			_check(offhand.get_child_count() == 0, "replacing pair removes offhand")
			appearance.mount_weapon_appearance(null)
			_check(main.get_child_count() == 0, "unequip clears main weapon")
			unit.queue_free()
			await get_tree().process_frame
	troop.queue_free()
	await get_tree().process_frame


func _check_paired_engagement() -> void:
	for school in [S.SWORD, S.MACE, S.SPEAR]:
		var troop := _runtime_troop(false)
		var paired := _runtime_unit(troop, [school, S.SHIELD])
		var base := _runtime_unit(troop, [school])
		_check(paired.weapon.engagement_stance == base.weapon.engagement_stance, "paired authored base stance")
		_check(paired.combat.engagement_stance == base.combat.engagement_stance, "paired combat profile base stance")
		_check(paired.get_engagement_stance() == base.get_engagement_stance(), "paired mixed-troop base stance")
		_check(paired.get_engagement_stance() != WeaponData.EngagementStance.HOLD_LINE, "paired weapon never holds without override")
		_check(paired.combat.formation_line == base.combat.formation_line and paired.combat.attack_style == base.combat.attack_style, "paired base formation and attack style")
		paired._hold_or_march()
		base._hold_or_march()
		_check(paired.velocity.x > 0.0 and is_equal_approx(paired.velocity.x, base.velocity.x), "paired marches like base in mixed troop")
		troop.queue_free()
		await get_tree().process_frame


func _runtime_troop(enemy: bool) -> Troop:
	var troop := Troop.new()
	troop.is_enemy = enemy
	var units := Node2D.new()
	units.name = "Units"
	troop.add_child(units)
	add_child(troop)
	troop.set_physics_process(false)
	return troop


func _runtime_unit(troop: Troop, schools: Array[int]) -> Unit:
	var roster := _make_roster(schools, true)
	roster.stats.con = 99
	var unit: Unit = _UNIT.instantiate()
	unit.roster_data = roster
	unit.stats = roster.stats
	troop.get_node("Units").add_child(unit)
	unit.set_physics_process(false)
	return unit


func _check_projectiles_and_charges() -> void:
	var world := Node2D.new()
	world.add_to_group("combat_world")
	add_child(world)
	var player := _runtime_troop(false)
	var enemy := _runtime_troop(true)
	player._opponent = enemy
	enemy._opponent = player
	var lancer := _runtime_unit(enemy, [S.SWORD, S.SPEAR])
	lancer.position = Vector2(600, 786)
	var hitbox := lancer._melee_hitbox
	for school in [S.SWORD, S.MACE, S.SPEAR]:
		var defender := _runtime_unit(player, [school, S.SHIELD])
		defender.position = Vector2(400, 786)
		var hp := defender.current_hp
		hitbox.enable_for_attack(40, 400.0, WeaponData.TargetingMode.SINGLE, WeaponData.DamageType.SLASHING, true)
		hitbox._try_charge_hit(defender._appearance.hurtbox)
		_check(not hitbox._charge_active, "charge stopped by " + defender.weapon.display_name)
		_check(defender.current_hp == hp - 10, "charge damage halved before shield mitigation")
		_check(is_equal_approx(absf(defender.velocity.x), 100.0), "charge knockback halved before shield mitigation")
		hitbox.disable()
		defender.queue_free()
		await _settle()
	var target := _runtime_unit(enemy, [S.SWORD, S.SHIELD])
	target.position = Vector2(900, 786)
	for recipe in [[S.MACE, S.SPEAR], [S.SPEAR, S.SHIELD], [S.MACE, S.BOW], [S.SWORD, S.BOW]]:
		var shooter := _runtime_unit(player, [int(recipe[0]), int(recipe[1])])
		shooter.position = Vector2(400, 786)
		if shooter.combat.uses_throw_projectile():
			shooter._spawn_spear_projectile()
		else:
			shooter._spawn_weapon_projectile(Vector2(400, 710), Vector2(900, 710))
		var projectiles := get_tree().get_nodes_in_group("projectiles")
		_check(projectiles.size() == 1, "spawns one projectile: " + shooter.weapon.display_name)
		var projectile := projectiles[0] as Projectile
		projectile.set_physics_process(false)
		_check(projectile.damage_type == shooter.weapon.damage_type, "projectile damage type: " + shooter.weapon.display_name)
		_check(projectile.damage == shooter._get_attack_damage(true), "projectile normal damage: " + shooter.weapon.display_name)
		if shooter.weapon.offhand_appearance_scene != null:
			_check(not shooter._appearance.weapon_mount.visible and shooter._appearance.offhand_mount.is_visible_in_tree(), "actual spear release retains shield")
			var hp := shooter.current_hp
			shooter.take_damage(20)
			_check(shooter.current_hp == hp - 10, "shield remains protective during throw")
			shooter._finish_attack()
			_check(shooter._appearance.weapon_mount.visible and shooter._appearance.offhand_mount.visible, "spear restored after recovery")
		var before := target.current_hp
		projectile._on_impact(target._appearance.hurtbox)
		var expected := projectile.damage
		if projectile.damage_type != WeaponData.DamageType.BLUNT:
			expected = maxi(roundi(float(expected) * 0.5), 1)
		_check(target.current_hp == before - expected, "projectile hits shield correctly: " + shooter.weapon.display_name)
		_projectile_checks += 1
		projectile.queue_free()
		shooter.queue_free()
		await _settle()
	player.queue_free()
	enemy.queue_free()
	world.queue_free()
	await _settle()


func _check_base_ui_and_compost() -> void:
	GameState.reset_run()
	GameState.clear_pending_seal_choice()
	GameState.troop.seed_if_empty(StarterPackages.build_units(&"great_hammer"))
	var base := _BASE.instantiate()
	add_child(base)
	await _settle()
	var screen := base.get_node("%ColonyScreen") as TroopSelectionScreen
	var row := screen.get_node("%SquadSlotRow") as HBoxContainer
	var schools := screen.get_node("%CocoonRow") as HBoxContainer
	_check(schools.get_child_count() == 5, "five school Cocoons, no compost cocoon")
	for i in WeaponSchool.DISPLAY_ORDER.size():
		_check((schools.get_child(i) as CocoonSlot).school == WeaponSchool.DISPLAY_ORDER[i], "Cocoon presentation " + str(i))
	_check(row.get_child_count() == 7, "four squad slots plus purchase, spacer, and bin")
	_check(row.get_child(4) is DropSlot and row.get_child(4).is_unlockable, "purchase before bin")
	_check(row.get_child(6) is CompostingBin, "bin last at initial capacity")
	_check_compost_spacing(screen)
	await _capture("war-chamber-start")
	for count in range(5, 11):
		GameState.troop.unlock_next_squad_slot()
		screen.on_screen_shown()
		await _settle()
		var bin := row.get_child(row.get_child_count() - 1) as CompostingBin
		_check(bin != null, "bin last at capacity " + str(count))
		_check(screen._squad_slots.size() == count, "bin never counts as squad slot")
		_check(bin.get_global_rect().end.x <= screen.get_global_rect().end.x, "bin within viewport at capacity " + str(count))
		_check_compost_spacing(screen)
	_check(row.get_child_count() == 12 and screen._squad_unlock_slot == null, "ten squad slots plus spacer and bin, no purchase")
	await _capture("war-chamber-max")
	var bin := screen._compost_bin
	var child := _make_roster()
	GameState.troop.try_add_unit(child)
	screen._sync_all_slots()
	_check(bin._accepts_drag_data({"source": "squad", "unit": child}), "bin accepts squad")
	_check(bin._accepts_drag_data({"source": "bench", "unit": child}), "bin accepts bench")
	_check(not bin._accepts_drag_data({"source": "cocoon", "unit": child}), "bin rejects non-troop source")
	_check(not bin._accepts_drag_data({"source": "squad", "unit": _make_roster()}), "bin rejects outsider")
	var biomass := GameState.biomass.amount
	var stock_size := GameState.nursery.stock.slots.filter(func(item: Resource) -> bool: return item != null).size()
	bin._drop_data(Vector2.ZERO, {"source": "squad", "unit": child})
	_check(screen._compost_dialog != null and GameState._troop_contains(child), "drop requires confirmation")
	screen._compost_dialog._on_cancel_pressed()
	await _settle()
	_check(GameState._troop_contains(child) and GameState.biomass.amount == biomass, "cancel preserves unit and biomass")
	bin._drop_data(Vector2.ZERO, {"source": "squad", "unit": child})
	screen._compost_dialog._on_confirm_pressed()
	await _settle()
	_check(not GameState._troop_contains(child) and GameState.biomass.amount == biomass + 2, "confirmed Child compost payout")
	_check(GameState.nursery.stock.slots.filter(func(item: Resource) -> bool: return item != null).size() == stock_size, "Child compost emits no spore")
	var adult := _make_roster([S.MACE, S.MACE], true)
	adult.cap_mutation = load("res://assets/base/nursery/mutations/cap/bank.tres")
	adult.biomass_bank = 10
	while GameState.nursery.stock.can_add():
		GameState.nursery.add_spore(SporeData.from_fallen_unit(_make_roster([S.SWORD], true)))
	var oldest: Resource = GameState.nursery.stock.slots[0]
	GameState.troop.try_add_unit(adult)
	var mould := GameState.troop.squad[0] as RosterUnitData
	mould.cap_mutation = load("res://assets/base/nursery/mutations/cap/mould.tres")
	var mould_before := mould.mould_compost_stacks
	biomass = GameState.biomass.amount
	screen._sync_all_slots()
	bin._drop_data(Vector2.ZERO, {"source": "squad", "unit": adult})
	screen._compost_dialog._on_confirm_pressed()
	await _settle()
	_check(GameState.biomass.amount == biomass + 13 and adult.biomass_bank == 0, "Adult compost pays base plus Bank")
	_check(adult.emitted_death_spore, "Adult emits lineage spore")
	_check(not GameState.nursery.stock.slots.has(oldest), "full Stock evicts oldest item for death spore")
	var death_spore := GameState.nursery.stock.slots[0] as SporeData
	_check(death_spore.weapon_trainings == [S.MACE, S.MACE], "death spore preserves Mace training lineage")
	_check(mould.mould_compost_stacks == mould_before + 1, "Mould ally compost hook")
	GameState.troop = TroopData.new()
	GameState.troop.seed_if_empty([child])
	_check(not bin._accepts_drag_data({"source": "squad", "unit": child}), "bin refuses last fighter")
	base.queue_free()
	await _settle()
	var starter := _STARTERS.instantiate() as StarterChoiceDialog
	add_child(starter)
	await _settle()
	var cards := starter.get_node("%CardsRow") as HBoxContainer
	_check(cards.get_child_count() == 5, "five starter cards")
	for card in cards.get_children():
		_check(Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(card.get_global_rect()), "starter card fits " + str(card.package_id))
	await _capture("starter-packages")
	starter.queue_free()
	await _settle()


func _check_compost_spacing(screen: TroopSelectionScreen) -> void:
	var spacer := screen.get_node("%SquadSlotRow/CompostSpacing") as Control
	_check(spacer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "bin spacer ignores mouse")
	if screen._squad_unlock_slot != null:
		var button := screen._squad_unlock_slot.get_node("%UnlockButton") as Button
		var label := screen._compost_bin.get_node("Stack/Label") as Label
		var gap := label.get_global_rect().position.x - button.get_global_rect().end.x
		_check(gap >= 32.0, "compost label clears unlock button at capacity %d (gap %.1f)" % [screen._squad_slots.size(), gap])


func _settle() -> void:
	for i in 4:
		await get_tree().process_frame


func _capture(label: String) -> void:
	if not _screenshots:
		return
	await RenderingServer.frame_post_draw
	var path := "res://.scratch/mace-school/" + label + ".png"
	var result := get_viewport().get_texture().get_image().save_png(path)
	_check(result == OK, "screenshot " + label)
