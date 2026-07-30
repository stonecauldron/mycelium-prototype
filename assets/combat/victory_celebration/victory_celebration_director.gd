class_name VictoryCelebrationDirector
extends Node

## Owns victory weapon-toss VFX so Unit only handles celebrate-march locomotion.

class TossState:
	var unit: Unit
	var tossed: Node2D
	var held: Node2D
	var mount: Node2D
	var start: Vector2 = Vector2.ZERO
	var start_rot: float = 0.0
	var peak: float = 0.0
	var lateral: float = 0.0
	var spin: float = 0.0
	var duration: float = 1.0
	var elapsed: float = 0.0
	var flying: bool = false
	var wait_left: float = 0.0


var _world: Node = null
var _active: bool = false
var _states: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func play(units: Array[Unit], world: Node) -> void:
	stop()
	_world = world
	_active = true
	if _world == null:
		return
	for unit in units:
		if unit == null or not is_instance_valid(unit):
			continue
		var state := TossState.new()
		state.unit = unit
		state.wait_left = randf_range(0.05, 0.55)
		_states.append(state)
	set_process(true)


func stop() -> void:
	_active = false
	set_process(false)
	for state in _states:
		_clear_flight(state, true)
	_states.clear()
	_world = null


func _process(delta: float) -> void:
	if not _active:
		return
	# Convert scaled delta to wall-clock so tosses stay readable during hitstop.
	var step := delta
	if Engine.time_scale > 0.0001:
		step = delta / Engine.time_scale
	for state in _states:
		_tick_state(state, step)


func _tick_state(state: TossState, delta: float) -> void:
	if state == null or state.unit == null or not is_instance_valid(state.unit):
		return
	if not state.unit.can_victory_toss():
		_clear_flight(state, true)
		return

	if state.flying:
		state.elapsed += delta
		var t := clampf(state.elapsed / maxf(state.duration, 0.001), 0.0, 1.0)
		_apply_arc(state, t)
		if t >= 1.0:
			_clear_flight(state, true)
			state.wait_left = randf_range(0.35, 0.8)
		return

	state.wait_left -= delta
	if state.wait_left > 0.0:
		return
	_start_flight(state)


func _start_flight(state: TossState) -> void:
	if state == null or not _active:
		return
	if state.unit == null or not is_instance_valid(state.unit):
		return
	if not state.unit.can_victory_toss():
		return
	if _world == null or not is_instance_valid(_world):
		return

	var mount := state.unit.get_weapon_mount_for_vfx()
	if mount == null or not mount.visible or mount.get_child_count() == 0:
		state.wait_left = randf_range(0.35, 0.8)
		return
	var held := mount.get_child(0) as Node2D
	if held == null:
		state.wait_left = randf_range(0.35, 0.8)
		return

	_clear_flight(state, true)

	var tossed: Node2D = held.duplicate() as Node2D
	if tossed == null:
		state.wait_left = randf_range(0.35, 0.8)
		return
	_world.add_child(tossed)
	tossed.global_transform = held.global_transform
	mount.visible = false

	var face := state.unit.get_victory_facing()
	state.tossed = tossed
	state.held = held
	state.mount = mount
	state.start = tossed.global_position
	state.start_rot = tossed.rotation
	state.peak = randf_range(240.0, 360.0)
	state.lateral = face * randf_range(-30.0, 90.0)
	state.spin = TAU * randf_range(1.75, 2.75) * face
	state.duration = randf_range(0.85, 1.1)
	state.elapsed = 0.0
	state.flying = true
	_apply_arc(state, 0.0)


func _apply_arc(state: TossState, t: float) -> void:
	if state == null:
		return
	if not is_instance_valid(state.tossed) or not is_instance_valid(state.held):
		return
	var hand_pos := state.held.global_position
	var arc := 4.0 * t * (1.0 - t)
	state.tossed.global_position = (
		state.start.lerp(hand_pos, t)
		+ Vector2(state.lateral * arc, -state.peak * arc)
	)
	state.tossed.rotation = state.start_rot + state.spin * t


func _clear_flight(state: TossState, restore_mount: bool) -> void:
	if state == null:
		return
	if state.tossed != null and is_instance_valid(state.tossed):
		state.tossed.queue_free()
	state.tossed = null
	state.held = null
	state.flying = false
	state.elapsed = 0.0
	if restore_mount and state.mount != null and is_instance_valid(state.mount):
		state.mount.visible = true
	state.mount = null
