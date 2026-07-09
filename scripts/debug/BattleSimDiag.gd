extends SceneTree

const TIME_SCALE := 1.0

var _stage: Node2D
var _player: Army
var _enemy: Army
var _frames := 0
var _elapsed := 0.0
var _ready_done := false


func _initialize() -> void:
	Engine.time_scale = TIME_SCALE
	var packed := load("res://scenes/CombatStage.tscn") as PackedScene
	_stage = packed.instantiate()
	root.add_child(_stage)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		for child in _stage.get_children():
			if child is CanvasLayer:
				child.free()
		_player = _stage.get_node("World/PlayerArmy") as Army
		_enemy = _stage.get_node("World/EnemyArmy") as Army
		_stage.call("_run_scenario", UnitStats.PowerTier.AVERAGE, UnitStats.PowerTier.AVERAGE)
		_ready_done = true
		print("Scenario started")
	return false


func _physics_process(delta: float) -> bool:
	if not _ready_done:
		return false

	_elapsed += delta / TIME_SCALE
	if int(_elapsed * 2.0) != int((_elapsed - delta / TIME_SCALE) * 2.0):
		_dump("t=%.1f" % _elapsed)

	if _elapsed >= 15.0:
		_dump("FINAL")
		quit(0)
	return false


func _dump(label: String) -> void:
	print("--- %s ---" % label)
	print(
		"Army states P:%s E:%s | alive P:%d E:%d"
		% [
			Army.State.keys()[_player.state],
			Army.State.keys()[_enemy.state],
			_player.get_living_unit_count(),
			_enemy.get_living_unit_count(),
		]
	)
	print(
		"Flags Px=%.1f Ex=%.1f gap=%.1f"
		% [
			_player.get_flag_global_x(),
			_enemy.get_flag_global_x(),
			absf(_enemy.get_flag_global_x() - _player.get_flag_global_x()),
		]
	)
	for unit in _player.get_units():
		print(
			"  P unit idx=%d x=%.1f y=%.1f hp=%d phase=%s target=%s"
			% [
				unit.squad_index,
				unit.global_position.x,
				unit.global_position.y,
				unit.current_hp,
				Unit.CombatPhase.keys()[unit._combat_phase],
				str(unit._target),
			]
		)
	for unit in _enemy.get_units():
		print(
			"  E unit idx=%d x=%.1f y=%.1f hp=%d phase=%s target=%s"
			% [
				unit.squad_index,
				unit.global_position.x,
				unit.global_position.y,
				unit.current_hp,
				Unit.CombatPhase.keys()[unit._combat_phase],
				str(unit._target),
			]
		)
