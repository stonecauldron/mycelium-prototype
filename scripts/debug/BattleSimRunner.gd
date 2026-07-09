extends SceneTree

const BATTLE_COUNT := 50
const MAX_BATTLE_SECONDS := 120.0
const TIME_SCALE := 4.0
const STARTUP_FRAMES := 5

var _stage: Node2D
var _player: Army
var _enemy: Army
var _player_wins := 0
var _enemy_wins := 0
var _draws := 0
var _timeouts := 0
var _battle_index := 0
var _elapsed := 0.0
var _waiting := false
var _startup_frames := 0
var _started := false


func _initialize() -> void:
	Engine.time_scale = TIME_SCALE
	var packed := load("res://scenes/CombatStage.tscn") as PackedScene
	_stage = packed.instantiate()
	root.add_child(_stage)
	current_scene = _stage


func _process(_delta: float) -> bool:
	if _started:
		return false

	_startup_frames += 1
	if _startup_frames < STARTUP_FRAMES:
		return false

	_started = true
	_player = _stage.get_node("World/PlayerArmy") as Army
	_enemy = _stage.get_node("World/EnemyArmy") as Army

	for child in _stage.get_children():
		if child is CanvasLayer:
			child.free()

	_start_next_battle()
	return false


func _start_next_battle() -> void:
	if _battle_index >= BATTLE_COUNT:
		_print_results()
		quit(0)
		return

	_battle_index += 1
	_elapsed = 0.0
	_waiting = true
	_stage.call("_run_scenario", UnitStats.PowerTier.AVERAGE, UnitStats.PowerTier.AVERAGE)
	print("Battle %d/%d started" % [_battle_index, BATTLE_COUNT])


func _physics_process(delta: float) -> bool:
	if not _waiting:
		return false

	_elapsed += delta / TIME_SCALE

	var player_alive := _player.get_living_unit_count()
	var enemy_alive := _enemy.get_living_unit_count()

	if player_alive == 0 and enemy_alive == 0:
		_draws += 1
		print("  -> draw (mutual wipe) at %.1fs" % _elapsed)
		_waiting = false
		call_deferred("_start_next_battle")
		return false

	if player_alive == 0:
		_enemy_wins += 1
		print("  -> enemy win (%d left) at %.1fs" % [enemy_alive, _elapsed])
		_waiting = false
		call_deferred("_start_next_battle")
		return false

	if enemy_alive == 0:
		_player_wins += 1
		print("  -> player win (%d left) at %.1fs" % [player_alive, _elapsed])
		_waiting = false
		call_deferred("_start_next_battle")
		return false

	if _elapsed >= MAX_BATTLE_SECONDS:
		_timeouts += 1
		# Closest to a winner by remaining units, then remaining HP.
		if player_alive > enemy_alive:
			_player_wins += 1
			print("  -> timeout player win (P:%d E:%d) at %.1fs" % [player_alive, enemy_alive, _elapsed])
		elif enemy_alive > player_alive:
			_enemy_wins += 1
			print("  -> timeout enemy win (P:%d E:%d) at %.1fs" % [player_alive, enemy_alive, _elapsed])
		else:
			var p_hp := _total_hp(_player)
			var e_hp := _total_hp(_enemy)
			if p_hp > e_hp:
				_player_wins += 1
				print("  -> timeout player win by HP (P:%d E:%d) at %.1fs" % [p_hp, e_hp, _elapsed])
			elif e_hp > p_hp:
				_enemy_wins += 1
				print("  -> timeout enemy win by HP (P:%d E:%d) at %.1fs" % [p_hp, e_hp, _elapsed])
			else:
				_draws += 1
				print("  -> timeout draw (P:%d E:%d hp equal) at %.1fs" % [player_alive, enemy_alive, _elapsed])
		_waiting = false
		call_deferred("_start_next_battle")

	return false


func _total_hp(army: Army) -> int:
	var total := 0
	for unit in army.get_living_units():
		total += unit.current_hp
	return total


func _print_results() -> void:
	var total := float(BATTLE_COUNT)
	print("")
	print("=== Average vs Average (%d battles) ===" % BATTLE_COUNT)
	print(
		"Player (green): %d wins (%.1f%%)"
		% [_player_wins, 100.0 * _player_wins / total]
	)
	print(
		"Enemy (red):    %d wins (%.1f%%)"
		% [_enemy_wins, 100.0 * _enemy_wins / total]
	)
	print(
		"Draws:          %d (%.1f%%)"
		% [_draws, 100.0 * _draws / total]
	)
	print("Timeouts used:  %d" % _timeouts)
