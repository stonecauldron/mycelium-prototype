extends Node2D

signal battle_ended(player_won: bool)

const FLOOR_SURFACE_Y := 786.0
const _UNIT_SCENE := preload("res://assets/units/unit.tscn")
const _GAME_OVER_SCENE_PATH := "res://assets/game_over/game_over.tscn"
const _VICTORY_SCENE_PATH := "res://assets/victory/victory.tscn"
const _DAY_SUMMARY_SCENE_PATH := "res://assets/day_summary/day_summary.tscn"
const _FAST_FORWARD_SCALES: Array[int] = [1, 2, 4]
const _FAST_FORWARD_COLOR_2X := Color(1.0, 0.85, 0.35, 1.0)
const _FAST_FORWARD_COLOR_4X := Color(1.0, 0.25, 0.25, 1.0)
const _HITSTOP_SCALE := 0.05
const _HITSTOP_DURATION := 0.05
const _ZOMBIE_RESPAWN_DELAY := 2.0
## Keep physics step size fixed under time_scale so 2×/4× don't change combat outcomes.
const _BASE_PHYSICS_TICKS := 60
const _BIOMASS_NUMBER_SCENE := preload("res://assets/vfx/biomass_number/biomass_number.tscn")
const _SPORE_GENERATED_SCENE := preload("res://assets/vfx/spore_generated/spore_generated.tscn")
const _COMBAT_CALLOUT_SCENE := preload("res://assets/vfx/combat_callout/combat_callout.tscn")
const _BIOMASS_DIGITS := 4
const _VICTORY_HITSTOP_SCALE := 0.12
const _VICTORY_HITSTOP_DURATION := 0.35
const _VICTORY_CELEBRATE_SEC := 1.9
## Beat after the wipe before flag death / callout / tosses.
const _VICTORY_LEAD_IN_SEC := 0.25
## Debug click-to-kill: max distance from cursor to a living player unit (world px).
const _DEBUG_KILL_PICK_RADIUS := 96.0
## Acid Rain stalemate breaker (battle time).
const _ACID_RAIN_GRACE_SEC := 20.0
const _ACID_RAIN_TICK_SEC := 1.0
const _ACID_RAIN_ESCALATE_SEC := 10.0
const _ACID_RAIN_BASE_DAMAGE := 1

@export var sandboxed: bool = false

@onready var player_troop: Troop = $World/PlayerTroop
@onready var enemy_troop: Troop = $World/EnemyTroop
@onready var _fast_forward_button: Button = %FastForwardButton
@onready var _biomass_amount: Label = %BiomassChip.get_node("%BiomassAmount")
@onready var _player_army_hp: ArmyHpChip = %PlayerArmyHp
@onready var _enemy_army_hp: ArmyHpChip = %EnemyArmyHp
@onready var _hud: CanvasLayer = $HUD

var _player_spawn: Vector2
var _enemy_spawn: Vector2
var _battle_over: bool = false
var _fallen_units: Array[RosterUnitData] = []
var _biomass_earned_this_fight: int = 0
## Precomputed Battle reward for this fight (day × difficulty); granted on victory.
var _battle_reward: int = 0
var _fast_forward_scale: int = 1
var _hitstop_active: bool = false
var _combat_paused: bool = false
var _saved_physics_ticks: int = _BASE_PHYSICS_TICKS
var _saved_max_physics_steps: int = 8
var _pending_player_zombie_respawns: int = 0
var _pending_enemy_zombie_respawns: int = 0
var _victory_celebrating: bool = false
var _victory_director: VictoryCelebrationDirector = null
var _player_army_max_hp: int = 0
var _enemy_army_max_hp: int = 0
var _battle_elapsed_sec: float = 0.0
var _acid_rain_active: bool = false
var _acid_rain_tick_accum: float = 0.0
var _acid_rain_active_elapsed: float = 0.0
var _acid_rain_label: Label = null


func _ready() -> void:
	if get_tree().current_scene != self:
		sandboxed = true

	_victory_director = VictoryCelebrationDirector.new()
	add_child(_victory_director)

	_saved_physics_ticks = Engine.physics_ticks_per_second
	_saved_max_physics_steps = Engine.max_physics_steps_per_frame
	_player_spawn = player_troop.get_formation_anchor_global()
	_enemy_spawn = enemy_troop.get_formation_anchor_global()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fast_forward_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_fast_forward_button.pressed.connect(_on_fast_forward_pressed)
	_set_fast_forward(GameState.combat_fast_forward)
	_refresh_biomass_hud()
	_setup_debug_kill_hint()
	_ensure_acid_rain_label()
	GameState.debug_cheats_applied.connect(_on_debug_cheats_applied)

	if sandboxed:
		return

	var player_roster := GameState.troop.get_squad_roster()
	if player_roster.is_empty():
		push_error("CombatStage requires a non-empty player squad in GameState.troop.")
		return

	if not BattleLaunch.has_enemy_roster():
		push_error("CombatStage requires an enemy roster via BattleLaunch.")
		return

	start_battle(player_roster, BattleLaunch.take_enemy_roster())


func _exit_tree() -> void:
	_hitstop_active = false
	_victory_celebrating = false
	if _victory_director != null:
		_victory_director.stop()
	_set_combat_paused(false)
	_restore_engine_timing()


func _unhandled_input(event: InputEvent) -> void:
	if _battle_over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_toggle_combat_pause()
			get_viewport().set_input_as_handled()
			return
	if not GameState.debug_mode_active:
		return
	# Debug (~): left-click a living player unit to kill it (tests death spores).
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			if _debug_kill_nearest_player_unit():
				get_viewport().set_input_as_handled()


func _debug_kill_nearest_player_unit() -> bool:
	if player_troop == null:
		return false
	var mouse_world := get_global_mouse_position()
	var best: Unit = null
	var best_dist := _DEBUG_KILL_PICK_RADIUS
	for unit in player_troop.get_living_units():
		if unit == null or not is_instance_valid(unit):
			continue
		var dist := unit.global_position.distance_to(mouse_world)
		if dist <= best_dist:
			best_dist = dist
			best = unit
	if best == null:
		return false
	best.take_damage(maxi(best.current_hp, 9999), best.global_position + Vector2(-40, 0), 120.0)
	return true


func _setup_debug_kill_hint() -> void:
	var hud := get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return
	var hint := hud.get_node_or_null("DebugKillHint") as Label
	if hint == null:
		hint = Label.new()
		hint.name = "DebugKillHint"
		hint.text = "Debug: click ally to kill"
		hint.theme_type_variation = &"SummaryEntryLabel"
		hint.position = Vector2(24, 220)
		hint.modulate = Color(1.0, 0.85, 0.4, 0.9)
		hud.add_child(hint)
	hint.visible = GameState.debug_mode_active


func _on_debug_cheats_applied() -> void:
	_setup_debug_kill_hint()


func _toggle_combat_pause() -> void:
	if _battle_over:
		return
	_set_combat_paused(not _combat_paused)


func _set_combat_paused(paused: bool) -> void:
	_combat_paused = paused
	if is_inside_tree():
		get_tree().paused = paused
	if not paused:
		_apply_simulation_rate()


func start_battle(
	player_roster: Array[RosterUnitData],
	enemy_roster: Array[RosterUnitData]
) -> void:
	_run_battle(player_roster, enemy_roster)


func _process(delta: float) -> void:
	if _battle_over or _combat_paused:
		return
	_battle_elapsed_sec += delta
	if not _acid_rain_active:
		if _battle_elapsed_sec < _ACID_RAIN_GRACE_SEC:
			return
		_start_acid_rain()
		if _battle_over:
			return
	_acid_rain_active_elapsed += delta
	_acid_rain_tick_accum += delta
	while _acid_rain_tick_accum >= _ACID_RAIN_TICK_SEC:
		_acid_rain_tick_accum -= _ACID_RAIN_TICK_SEC
		_tick_acid_rain()
		if _battle_over:
			return


func _on_fast_forward_pressed() -> void:
	var idx := _FAST_FORWARD_SCALES.find(_fast_forward_scale)
	if idx < 0:
		idx = 0
	var next_scale := _FAST_FORWARD_SCALES[(idx + 1) % _FAST_FORWARD_SCALES.size()]
	_set_fast_forward(next_scale)


func _set_fast_forward(ff_scale: int) -> void:
	if ff_scale not in _FAST_FORWARD_SCALES:
		ff_scale = 1
	_fast_forward_scale = ff_scale
	GameState.combat_fast_forward = ff_scale
	_apply_simulation_rate()
	if _fast_forward_button != null:
		match ff_scale:
			2:
				_fast_forward_button.modulate = _FAST_FORWARD_COLOR_2X
			4:
				_fast_forward_button.modulate = _FAST_FORWARD_COLOR_4X
			_:
				_fast_forward_button.modulate = Color.WHITE


## time_scale alone enlarges each physics delta; also raise tick rate so game-time
## step size stays ~1/_BASE_PHYSICS_TICKS (projectiles/collisions stay consistent).
func _apply_simulation_rate() -> void:
	var ff := 1 if _battle_over else _fast_forward_scale
	Engine.physics_ticks_per_second = _saved_physics_ticks * ff
	# 4× at 60fps needs 4 steps/frame; headroom if render FPS dips.
	Engine.max_physics_steps_per_frame = maxi(_saved_max_physics_steps, ff * 4)
	if _hitstop_active:
		return
	Engine.time_scale = 1.0 if _battle_over else float(ff)


func _restore_time_scale() -> void:
	_apply_simulation_rate()


func _restore_engine_timing() -> void:
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = _saved_physics_ticks
	Engine.max_physics_steps_per_frame = _saved_max_physics_steps


func request_hitstop() -> void:
	if _battle_over or _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = _HITSTOP_SCALE
	var timer := get_tree().create_timer(_HITSTOP_DURATION, true, false, true)
	await timer.timeout
	if not is_inside_tree():
		return
	# Victory celebration owns hitstop / time_scale after the killing blow.
	if _victory_celebrating:
		return
	_hitstop_active = false
	if _battle_over:
		return
	_restore_time_scale()


func _run_battle(
	player_roster: Array[RosterUnitData],
	enemy_roster: Array[RosterUnitData]
) -> void:
	_battle_over = false
	_hitstop_active = false
	_victory_celebrating = false
	if _victory_director != null:
		_victory_director.stop()
	_fallen_units.clear()
	_biomass_earned_this_fight = 0
	_battle_reward = 0
	if not sandboxed:
		_battle_reward = _compute_battle_reward(enemy_roster)
	_pending_player_zombie_respawns = 0
	_pending_enemy_zombie_respawns = 0
	_player_army_max_hp = 0
	_enemy_army_max_hp = 0
	_reset_acid_rain()
	_clear_world_vfx()
	_reset_troop_from_roster(
		player_troop,
		_player_spawn,
		player_roster,
		Color.WHITE,
		true
	)
	_reset_troop_from_roster(
		enemy_troop,
		_enemy_spawn,
		enemy_roster,
		Color.WHITE,
		false
	)
	_refresh_unit_process_order()
	_setup_army_hp_hud()
	_notify_battle_start()
	_set_fast_forward(_fast_forward_scale)


func _notify_battle_start() -> void:
	var context := BattleStartContext.new()
	for unit in player_troop.get_living_units():
		unit.notify_battle_start(context)
	for unit in enemy_troop.get_living_units():
		unit.notify_battle_start(context)
	context.flush()


func _reset_acid_rain() -> void:
	_battle_elapsed_sec = 0.0
	_acid_rain_active = false
	_acid_rain_tick_accum = 0.0
	_acid_rain_active_elapsed = 0.0
	_ensure_acid_rain_label()
	if _acid_rain_label != null:
		_acid_rain_label.visible = false


func _ensure_acid_rain_label() -> void:
	if _acid_rain_label != null and is_instance_valid(_acid_rain_label):
		return
	if _hud == null:
		return
	var label := Label.new()
	label.name = "AcidRainLabel"
	label.visible = false
	label.text = "Acid Rain"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", 36)
	label.add_theme_color_override(&"font_color", Color(0.55, 0.95, 0.35, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 1.0))
	label.add_theme_constant_override(&"outline_size", 6)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -160.0
	label.offset_right = 160.0
	label.offset_top = 112.0
	label.offset_bottom = 156.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(label)
	_acid_rain_label = label


func _start_acid_rain() -> void:
	_acid_rain_active = true
	_acid_rain_tick_accum = 0.0
	_acid_rain_active_elapsed = 0.0
	_ensure_acid_rain_label()
	if _acid_rain_label != null:
		_acid_rain_label.visible = true
	_show_acid_rain_callout()
	_tick_acid_rain()


func _show_acid_rain_callout() -> void:
	if _hud == null:
		return
	var callout: CombatCallout = _COMBAT_CALLOUT_SCENE.instantiate()
	_hud.add_child(callout)
	callout.position = Vector2(960.0, 220.0)
	callout.display("Acid Rain!", CombatCallout.Kind.STREAK)


func _acid_rain_damage() -> int:
	var steps := int(_acid_rain_active_elapsed / _ACID_RAIN_ESCALATE_SEC)
	return _ACID_RAIN_BASE_DAMAGE + maxi(steps, 0)


func _tick_acid_rain() -> void:
	if _battle_over:
		return
	var amount := _acid_rain_damage()
	var units: Array[Unit] = []
	units.append_array(player_troop.get_living_units())
	units.append_array(enemy_troop.get_living_units())
	for unit in units:
		if unit == null or not is_instance_valid(unit):
			continue
		unit.take_damage(
			amount,
			unit.global_position,
			0.0,
			null,
			WeaponData.DamageType.BLUNT
		)
	if _acid_rain_label != null:
		_acid_rain_label.text = "Acid Rain  %d" % amount


func _notify_battle_end() -> void:
	if _victory_director != null:
		_victory_director.stop()
	for unit in player_troop.get_living_units():
		unit.notify_battle_end()
	for unit in enemy_troop.get_living_units():
		unit.notify_battle_end()
	_clear_zombie_battle_revives()


## Zombie revive is once per battle; survivors keep the body mutation for later fights.
func _clear_zombie_battle_revives() -> void:
	for unit in player_troop.get_units():
		if unit != null and unit.roster_data != null:
			unit.roster_data.has_revived = false
	for unit in enemy_troop.get_units():
		if unit != null and unit.roster_data != null:
			unit.roster_data.has_revived = false
	if sandboxed:
		return
	for entry in GameState.troop.squad:
		var roster := entry as RosterUnitData
		if roster != null:
			roster.has_revived = false
	for entry in GameState.troop.bench:
		var roster := entry as RosterUnitData
		if roster != null:
			roster.has_revived = false


func _compute_battle_reward(enemy_roster: Array[RosterUnitData]) -> int:
	var day := clampi(GameState.get_upcoming_day(), 1, GameState.WIN_DAYS)
	var specs: Array[EnemyUnitSpec] = []
	specs.assign(GameState.upcoming_enemy_formation)
	if specs.is_empty():
		specs = _specs_from_enemy_roster(enemy_roster)
	return EnemyComposer.battle_reward_for(day, specs)


static func _specs_from_enemy_roster(enemy_roster: Array[RosterUnitData]) -> Array[EnemyUnitSpec]:
	var specs: Array[EnemyUnitSpec] = []
	for roster in enemy_roster:
		if roster == null or roster.enemy_unit_data == null:
			continue
		specs.append(EnemyUnitSpec.make(roster.enemy_unit_data))
	return specs


func _award_battle_reward() -> void:
	if sandboxed or _battle_reward <= 0:
		return
	GameState.biomass.add(_battle_reward)
	Analytics.biomass_source("Battle", "Reward", _battle_reward)
	_biomass_earned_this_fight += _battle_reward
	_refresh_biomass_hud()


func record_biomass_yield(amount: int) -> void:
	if amount <= 0:
		return
	_biomass_earned_this_fight += amount
	_refresh_biomass_hud()


func _spawn_biomass_number(at_global: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	var world := get_node_or_null("World") as Node2D
	if world == null:
		return
	var number: BiomassNumber = _BIOMASS_NUMBER_SCENE.instantiate()
	world.add_child(number)
	number.global_position = at_global + Vector2(0, -128)
	number.display(amount)


func _refresh_biomass_hud() -> void:
	if _biomass_amount == null:
		return
	_biomass_amount.text = "%0*d kg" % [_BIOMASS_DIGITS, GameState.biomass.amount]


func _setup_army_hp_hud() -> void:
	_player_army_max_hp = _sum_troop_max_hp(player_troop)
	_enemy_army_max_hp = _sum_troop_max_hp(enemy_troop)
	_refresh_army_hp_hud()


func _sum_troop_max_hp(troop: Troop) -> int:
	var total := 0
	for unit in troop.get_units():
		total += unit.get_effective_max_hp()
	return total


func _sum_troop_current_hp(troop: Troop) -> int:
	var total := 0
	for unit in troop.get_living_units():
		total += unit.current_hp
	return total


func _refresh_army_hp_hud(_current: int = 0, _maximum: int = 0) -> void:
	if _player_army_hp != null:
		_player_army_hp.set_hp(_sum_troop_current_hp(player_troop), _player_army_max_hp)
	if _enemy_army_hp != null:
		_enemy_army_hp.set_hp(_sum_troop_current_hp(enemy_troop), _enemy_army_max_hp)


func _reset_troop_from_roster(
	troop: Troop,
	spawn_global: Vector2,
	roster: Array[RosterUnitData],
	body_color: Color,
	is_player: bool
) -> void:
	var units_root: Node2D = troop.get_node("Units")
	_clear_units(units_root)
	troop.reset_for_scenario(spawn_global)

	# Player homes use War Chamber slot indices (nulls leave gaps). Enemies and
	# sandbox battles use compact order from the passed roster.
	if is_player and not sandboxed:
		var squad: Array = GameState.troop.squad
		for slot_index in squad.size():
			var data := squad[slot_index] as RosterUnitData
			if data == null:
				continue
			_spawn_unit(units_root, data, body_color, slot_index, is_player)
	else:
		var index := 0
		for data in roster:
			if data == null:
				continue
			_spawn_unit(units_root, data, body_color, index, is_player)
			index += 1


func _clear_units(units_root: Node2D) -> void:
	for child in units_root.get_children():
		units_root.remove_child(child)
		child.free()


func _spawn_unit(
	units_root: Node2D,
	roster_data: RosterUnitData,
	body_color: Color,
	squad_index: int,
	is_player: bool,
	spawn_global: Vector2 = Vector2.INF
) -> Unit:
	var unit: Unit = _UNIT_SCENE.instantiate()
	unit.roll_random_stats = false
	unit.roster_data = roster_data
	if roster_data.stats != null:
		unit.stats = roster_data.stats.duplicate(true)
	unit.weapon = roster_data.weapon
	unit.combat = roster_data.ensure_combat_profile()
	if roster_data.enemy_unit_data != null:
		unit.body_color = body_color
	else:
		unit.body_color = body_color * UnitStatsData.tint_for_tier(roster_data.power_tier)
	unit.squad_index = squad_index
	unit.died.connect(_on_unit_died.bind(is_player))
	unit.health_changed.connect(_refresh_army_hp_hud)
	units_root.add_child(unit)
	if spawn_global != Vector2.INF:
		unit.global_position = spawn_global
	return unit


func _on_unit_died(unit: Unit, is_player: bool) -> void:
	request_hitstop()
	var roster := unit.roster_data
	var wants_zombie_respawn := (
		roster != null
		and not roster.has_revived
		and roster.has_meta("zombie_cap_wants_respawn")
		and bool(roster.get_meta("zombie_cap_wants_respawn"))
	)
	if not sandboxed:
		if is_player and roster != null:
			_fallen_units.append(roster)
			GameState.troop.remove_unit(roster)
			if not wants_zombie_respawn:
				_try_emit_death_spore(roster, unit.global_position)
		# Enemy deaths no longer drip biomass; Battle reward is granted on victory.
	if wants_zombie_respawn:
		_schedule_zombie_respawn(roster, is_player, unit.squad_index)
	else:
		_check_battle_end()


func _try_emit_death_spore(roster: RosterUnitData, at_global: Vector2) -> void:
	if roster == null or not roster.is_adult_stage():
		return
	var spore := GameState.nursery.add_death_spore(roster)
	if spore == null:
		return
	_spawn_spore_generated(at_global, spore.tint)


func _spawn_spore_generated(at_global: Vector2, tint: Color = Color.WHITE) -> void:
	var world := get_node_or_null("World") as Node2D
	if world == null:
		return
	var callout: SporeGenerated = _SPORE_GENERATED_SCENE.instantiate()
	world.add_child(callout)
	# Higher than biomass/damage numbers so the wider label doesn't clip the body.
	callout.global_position = at_global + Vector2(0, -220)
	callout.display(tint)


func _schedule_zombie_respawn(
	dead_roster: RosterUnitData,
	is_player: bool,
	squad_index: int
) -> void:
	if dead_roster == null:
		return
	if dead_roster.has_meta("zombie_cap_wants_respawn"):
		dead_roster.remove_meta("zombie_cap_wants_respawn")
	if is_player:
		_pending_player_zombie_respawns += 1
	else:
		_pending_enemy_zombie_respawns += 1
	await get_tree().create_timer(_ZOMBIE_RESPAWN_DELAY).timeout
	if not is_inside_tree():
		return
	if is_player:
		_pending_player_zombie_respawns = maxi(_pending_player_zombie_respawns - 1, 0)
	else:
		_pending_enemy_zombie_respawns = maxi(_pending_enemy_zombie_respawns - 1, 0)
	if _battle_over:
		return
	_respawn_zombie_cap(dead_roster, is_player, squad_index)
	_check_battle_end()


## Spawn just ahead of the opposing unit that has advanced furthest.
func _zombie_respawn_global_position(troop: Troop) -> Vector2:
	var opponent := troop.get_opponent()
	if opponent == null:
		return troop.get_flag_global_position()
	var frontmost := opponent.get_frontmost_living_unit()
	if frontmost == null:
		return troop.get_flag_global_position()
	# Place slightly in front of that unit (in the direction they face).
	return frontmost.global_position + Vector2(
		opponent.get_facing() * Troop.HOME_SLOT_SPACING,
		0.0
	)


func _respawn_zombie_cap(
	dead_roster: RosterUnitData,
	is_player: bool,
	squad_index: int
) -> void:
	if dead_roster == null:
		return
	var clone := dead_roster.duplicate(true) as RosterUnitData
	if clone == null:
		return
	if clone.stats != null:
		clone.stats = dead_roster.stats.duplicate(true)
	clone.has_revived = true
	if clone.has_meta("zombie_cap_wants_respawn"):
		clone.remove_meta("zombie_cap_wants_respawn")
	if is_player and not sandboxed:
		_fallen_units.erase(dead_roster)
		if GameState.troop.try_add_unit(clone) == "":
			return
	var troop := player_troop if is_player else enemy_troop
	var units_root: Node2D = troop.get_node("Units")
	var color := Color.WHITE
	var spawn_pos := _zombie_respawn_global_position(troop)
	var spawned := _spawn_unit(units_root, clone, color, squad_index, is_player, spawn_pos)
	if spawned != null:
		var respawn_max := spawned.get_effective_max_hp()
		if is_player:
			_player_army_max_hp += respawn_max
		else:
			_enemy_army_max_hp += respawn_max
		spawned.notify_battle_start()
		_refresh_army_hp_hud()
	_refresh_unit_process_order()


func _check_battle_end() -> void:
	if _battle_over:
		return
	var player_wiped := (
		player_troop.is_wiped_out() and _pending_player_zombie_respawns <= 0
	)
	var enemy_wiped := (
		enemy_troop.is_wiped_out() and _pending_enemy_zombie_respawns <= 0
	)
	if not player_wiped and not enemy_wiped:
		return
	_battle_over = true
	if _acid_rain_label != null:
		_acid_rain_label.visible = false
	_set_combat_paused(false)

	if player_wiped:
		_hitstop_active = false
		_restore_engine_timing()
		_notify_battle_end()
		if sandboxed:
			battle_ended.emit(false)
			return
		Analytics.flush_hit_biomass()
		Analytics.day_fail()
		Analytics.run_fail()
		SceneTransition.change_scene(_GAME_OVER_SCENE_PATH)
		return

	# Sandbox rematches skip the victory beat so flags/walls stay reset-friendly.
	if sandboxed:
		_hitstop_active = false
		_restore_engine_timing()
		_notify_battle_end()
		battle_ended.emit(true)
		return

	_victory_celebrating = true
	await get_tree().create_timer(_VICTORY_LEAD_IN_SEC, true, true, true).timeout
	if not is_inside_tree():
		return
	await _play_victory_celebration()
	if not is_inside_tree():
		return
	_victory_celebrating = false
	_hitstop_active = false
	_restore_engine_timing()
	# Keep celebrate-march / weapon tosses running under the scene fade;
	# _exit_tree stops the director when combat is replaced.
	_clear_zombie_battle_revives()

	Analytics.flush_hit_biomass()
	_award_battle_reward()
	Analytics.day_complete()
	GameState.ensure_nursery_seeded()
	GameState.current_day += 1
	GameState.clear_upcoming_enemy_formation()
	if GameState.has_won_run():
		Analytics.run_complete()
		SceneTransition.change_scene(_VICTORY_SCENE_PATH)
		return
	DaySummaryFeed.clear()
	_push_combat_recap_to_day_summary()
	GameState.prefer_nursery_tab = true
	if GameState.current_day == GameState.NURSERY_UNLOCK_DAY:
		DaySummaryFeed.add_base_unlock("Nursery")
	if _biomass_earned_this_fight > 0:
		DaySummaryFeed.add_biomass_earned(_biomass_earned_this_fight)
	for unit in _fallen_units:
		DaySummaryFeed.add_fallen_unit(unit)
	GameState.troop.advance_unit_ages()
	var emerged := GameState.emerge_pupations()
	for entry in emerged:
		DaySummaryFeed.add_unit_emerged_from_pupation(
			entry.get("unit") as RosterUnitData,
			int(entry.get("school", 0))
		)
	var matured := GameState.nursery.advance_day()
	for entry in matured:
		DaySummaryFeed.add_nursery_matured(
			str(entry.get("spore_name", "Spore")),
			int(entry.get("plot_index", 0)),
			entry.get("tint", Color.WHITE) as Color,
			bool(entry.get("as_imago", false))
		)
	GameState.refresh_shops_for_new_day()
	GameState.begin_day()
	GameState.maybe_queue_seal_choice()
	SceneTransition.change_scene(_DAY_SUMMARY_SCENE_PATH)


func _push_combat_recap_to_day_summary() -> void:
	var merged: Dictionary = {}
	for unit in player_troop.get_units():
		if unit == null or unit.roster_data == null:
			continue
		var key := unit.squad_index
		if not merged.has(key):
			merged[key] = {
				"unit": unit.roster_data,
				"dealt": 0,
				"taken": 0,
				"max_hp": 0,
				"order": key,
			}
		var entry: Dictionary = merged[key]
		entry["unit"] = unit.roster_data
		entry["dealt"] = int(entry["dealt"]) + unit.damage_dealt
		entry["taken"] = int(entry["taken"]) + unit.damage_taken
		var unit_max_hp := unit.get_effective_max_hp()
		# Keep the highest max HP seen (same across Zombie lives).
		entry["max_hp"] = maxi(int(entry["max_hp"]), unit_max_hp)
	var damage_rows: Array[Dictionary] = []
	var keys: Array = merged.keys()
	keys.sort()
	for key in keys:
		var entry: Dictionary = merged[key]
		var roster := entry["unit"] as RosterUnitData
		if roster == null:
			continue
		var max_hp := int(entry["max_hp"])
		if max_hp <= 0:
			max_hp = SealModifiers.effective_max_hp(roster)
		damage_rows.append({
			"unit": roster,
			"dealt": int(entry["dealt"]),
			"taken": int(entry["taken"]),
			"max_hp": max_hp,
			"order": int(entry["order"]),
		})
	damage_rows.sort_custom(_sort_unit_damage_rows_desc)
	DaySummaryFeed.set_combat_recap(
		_sum_troop_current_hp(player_troop),
		_player_army_max_hp,
		damage_rows
	)


func _sort_unit_damage_rows_desc(a: Dictionary, b: Dictionary) -> bool:
	var a_dealt := int(a.get("dealt", 0))
	var b_dealt := int(b.get("dealt", 0))
	if a_dealt != b_dealt:
		return a_dealt > b_dealt
	var a_taken := int(a.get("taken", 0))
	var b_taken := int(b.get("taken", 0))
	if a_taken != b_taken:
		return a_taken > b_taken
	return int(a.get("order", 0)) < int(b.get("order", 0))


func _play_victory_celebration() -> void:
	_hitstop_active = true
	Engine.time_scale = _VICTORY_HITSTOP_SCALE
	_destroy_all_walls()
	if enemy_troop.has_flag_bearer():
		enemy_troop.flag_bearer.play_death()
	_spawn_victory_callout()
	var celebrants: Array[Unit] = player_troop.get_living_units()
	for unit in celebrants:
		unit.begin_victory_celebration()
	var world := get_node_or_null("World") as Node2D
	if _victory_director != null:
		_victory_director.play(celebrants, world)

	# Real-time durations so slow-mo doesn't compress the celebration.
	await get_tree().create_timer(_VICTORY_HITSTOP_DURATION, true, true, true).timeout
	if not is_inside_tree():
		return
	_hitstop_active = false
	Engine.time_scale = 1.0

	# Leave tosses/marching running so the day-summary fade doesn't cut them off.
	await get_tree().create_timer(_VICTORY_CELEBRATE_SEC, true, true, true).timeout


func _destroy_all_walls() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("combat_obstacles"):
		var wall := node as WallObstacle
		if wall != null:
			wall.destroy()


func _spawn_victory_callout() -> void:
	var hud := get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return
	var callout: CombatCallout = _COMBAT_CALLOUT_SCENE.instantiate()
	hud.add_child(callout)
	var viewport_size := get_viewport().get_visible_rect().size
	callout.position = viewport_size * 0.5 + Vector2(0.0, -48.0)
	callout.display("Victory!", CombatCallout.Kind.VICTORY)


func _refresh_unit_process_order() -> void:
	var units: Array[Unit] = []
	units.append_array(player_troop.get_living_units())
	units.append_array(enemy_troop.get_living_units())
	units.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.process_tiebreak > b.process_tiebreak
	)
	for i in units.size():
		units[i].process_physics_priority = i


func _clear_world_vfx() -> void:
	var world := $World
	for child in world.get_children():
		if (
			child is DamageNumber
			or child is CombatCallout
			or child is Projectile
			or child is HitBurst
			or child is SporeCloud
			or child is WallObstacle
		):
			child.queue_free()
