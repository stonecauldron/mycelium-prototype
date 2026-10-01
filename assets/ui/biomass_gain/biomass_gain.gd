class_name BiomassGain
extends Control

## Replays committed income; authoritative BiomassData is never changed here.
signal finished
signal cancelled

const _THEME := preload("res://assets/themes/default.tres")
const _DROP_TIME := 0.2
const _FLIGHT_TIME := 0.34
const _SETTLE_TIME := 0.46
const _GOLD := Color("f1d980")

var _counter: BiomassChip
var _counter_token := 0
var _amount := 0
var _elapsed := 0.0
var _delay := 0.0
var _spread_time := 0.5
var _keep_label := false
var _landed := false
var _completed := false
var _completed_at_msec := 0
var _completion_voice: AudioStreamPlayer
var _done := false
var _received_count := 0
var _source := Vector2.ZERO
var _gain_row: HBoxContainer
var _number: Label
var _icons: Array[Sprite2D] = []
var _launch_offsets: Array[Vector2] = []
var _icon_scales: Array[float] = []
var _arrived: Array[bool] = []


static func play(
	parent: Control, source_canvas_rect: Rect2, amount: int, counter: BiomassChip,
	keep_label: bool = false, delay: float = 0.0
) -> BiomassGain:
	var effect := BiomassGain.new()
	effect.name = "BiomassGain"
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.process_mode = Node.PROCESS_MODE_PAUSABLE
	effect.theme = _THEME
	effect.z_index = 105
	parent.add_child(effect)
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect._build(source_canvas_rect, amount, counter, keep_label, delay)
	return effect


func _ready() -> void:
	get_viewport().size_changed.connect(cancel)


func _build(source_canvas_rect: Rect2, amount: int, counter: BiomassChip, keep_label: bool, delay: float) -> void:
	if amount <= 0 or not is_instance_valid(counter) or get_tree().paused:
		cancel.call_deferred()
		return
	_amount = amount
	_counter = counter
	_counter_token = counter.begin_gain(amount)
	_keep_label = keep_label
	_delay = maxf(0.0, delay)
	_source = get_global_transform_with_canvas().affine_inverse() * source_canvas_rect.get_center()
	_source.x = clampf(_source.x, 180.0, maxf(180.0, size.x - 180.0))
	_source.y = clampf(_source.y, 130.0, maxf(130.0, size.y - 100.0))
	_spread_time = clampf(0.36 + sqrt(float(amount)) * 0.035, 0.4, 0.78)
	_gain_row = BiomassDisplay.make_amount("+0", 56, _GOLD, true)
	_gain_row.name = "GainAmount"
	add_child(_gain_row)
	_number = _gain_row.get_child(0) as Label
	_number.add_theme_constant_override("outline_size", 6)
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Reserve the final width so counting never shifts the icon sideways.
	_number.custom_minimum_size.x = _number.get_theme_font("font").get_string_size(
		BiomassDisplay.number(amount, true), HORIZONTAL_ALIGNMENT_LEFT, -1, 56
	).x
	_gain_row.size = _gain_row.get_combined_minimum_size()
	_gain_row.hide()
	var count := clampi(ceili(sqrt(float(amount)) * 2.5), 3, 40)
	var visual_rng := RandomNumberGenerator.new()
	visual_rng.randomize()
	for i in count:
		var icon := Sprite2D.new()
		icon.name = "BiomassParticle%d" % i
		icon.texture = BiomassDisplay.ICON
		icon.z_index = -1
		icon.hide()
		add_child(icon)
		_icons.append(icon)
		_launch_offsets.append(Vector2(visual_rng.randf_range(-80.0, 80.0), visual_rng.randf_range(-8.0, 28.0)))
		_icon_scales.append(visual_rng.randf_range(25.0, 43.0) / BiomassDisplay.ICON.get_width())
		_arrived.append(false)


func _process(delta: float) -> void:
	if _done or _gain_row == null:
		return
	if not is_visible_in_tree() or not is_instance_valid(_counter) or not _counter.is_visible_in_tree():
		cancel()
		return
	if not _completed and not _counter.is_gain_active(_counter_token):
		# Spending, undoing or another reward supersedes this readout.
		cancel()
		return
	_elapsed += delta
	var age := _elapsed - _delay
	if age < 0.0:
		return
	_gain_row.show()
	var count_time := _spread_time + _FLIGHT_TIME
	var progress := clampf((age - _DROP_TIME) / count_time, 0.0, 1.0)
	var displayed := mini(_amount, floori(float(_amount) * (1.0 - pow(1.0 - progress, 1.35))))
	_number.text = "+%d" % displayed
	var growth := lerpf(0.88, 1.3, progress)
	var drop_y := 0.0
	if age < _DROP_TIME:
		var fall := clampf(age / _DROP_TIME, 0.0, 1.0)
		drop_y = -110.0 * (1.0 - fall * fall)
		_gain_row.modulate.a = minf(fall * 4.0, 1.0)
	elif not _landed:
		_landed = true
		Audio.play_owned_ui_cue(self, Sfx.Cue.BIOMASS_DROP)
	var landing_age := maxf(0.0, age - _DROP_TIME)
	var bounce := sin(minf(landing_age / 0.2, 1.0) * TAU) * maxf(0.0, 1.0 - landing_age / 0.2)
	_gain_row.pivot_offset = _gain_row.size * 0.5
	_gain_row.position = _source - _gain_row.size * 0.5 + Vector2(0, drop_y - bounce * 10.0)
	_gain_row.scale = Vector2(growth * (1.0 + bounce * 0.08), growth * (1.0 - bounce * 0.12))
	_animate_icons(landing_age)
	if progress >= 1.0 and not _completed:
		_completed = true
		_completed_at_msec = Time.get_ticks_msec()
		_number.text = BiomassDisplay.number(_amount, true)
		_counter.receive_gain(_counter_token, _amount)
		_completion_voice = Audio.play_owned_ui_cue(self, Sfx.Cue.BIOMASS_COMPLETE)
	if not _completed:
		return
	# Keep the resolve audible even after a slow frame or a time-scale change.
	var settle_age := float(Time.get_ticks_msec() - _completed_at_msec) / 1000.0
	var settle := clampf(settle_age / _SETTLE_TIME, 0.0, 1.0)
	_gain_row.scale = Vector2.ONE * lerpf(1.3, 1.15, smoothstep(0.0, 1.0, settle))
	if not _keep_label:
		_gain_row.modulate.a = 1.0 - smoothstep(0.5, 1.0, settle)
	if settle >= 1.0:
		_finish()


func _animate_icons(age: float) -> void:
	var target := get_global_transform_with_canvas().affine_inverse() * _counter.gain_target_canvas_position()
	var previous_count := _received_count
	for i in _icons.size():
		if _arrived[i]:
			continue
		var launch_time := _spread_time * float(i) / float(maxi(1, _icons.size() - 1))
		var travel := clampf((age - launch_time) / _FLIGHT_TIME, 0.0, 1.0)
		if age < launch_time:
			continue
		var icon := _icons[i]
		icon.show()
		var start := _source + _launch_offsets[i]
		var first := start + Vector2(_launch_offsets[i].x * 1.8, -100.0)
		var second := target + Vector2(_launch_offsets[i].x * 0.6, 100.0)
		icon.position = start.bezier_interpolate(first, second, target, travel)
		icon.scale = Vector2.ONE * _icon_scales[i] * lerpf(1.0, 0.45, travel * travel)
		icon.modulate.a = minf(travel * 10.0, 1.0)
		icon.rotation = sin(travel * PI) * _launch_offsets[i].x * 0.008
		if travel >= 1.0:
			icon.hide()
			_arrived[i] = true
			_received_count += 1
	if _received_count > previous_count:
		var progress := float(_received_count) / float(_icons.size())
		_counter.receive_gain(_counter_token, roundi(float(_amount) * progress))
		var voice := Audio.play_owned_ui_cue(self, Sfx.Cue.BIOMASS_FEED)
		if voice != null:
			voice.pitch_scale = lerpf(0.95, 1.25, progress)


func is_finished() -> bool:
	return _done


func finish_immediately() -> void:
	if _done or is_queued_for_deletion():
		return
	if _gain_row == null or not is_instance_valid(_counter):
		cancel()
		return
	if not _completed and not _counter.is_gain_active(_counter_token):
		cancel()
		return
	var already_completed := _completed
	_completed = true
	_landed = true
	_number.text = BiomassDisplay.number(_amount, true)
	_gain_row.size = _gain_row.get_combined_minimum_size()
	_gain_row.pivot_offset = _gain_row.size * 0.5
	_gain_row.position = _source - _gain_row.size * 0.5
	_gain_row.scale = Vector2.ONE * 1.15
	_gain_row.modulate.a = 1.0
	_gain_row.show()
	for icon in _icons:
		icon.hide()
	_counter.receive_gain(_counter_token, _amount)
	if not is_instance_valid(_completion_voice):
		_completion_voice = null
	_stop_owned_sounds(_completion_voice)
	if not already_completed:
		_completion_voice = Audio.play_owned_ui_cue(self, Sfx.Cue.BIOMASS_COMPLETE)
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	_counter.end_gain(_counter_token)
	set_process(false)
	# End the presentation now, but keep the full ka-ching tail audible.
	if not _keep_label:
		if is_instance_valid(_completion_voice) and _completion_voice.playing:
			_completion_voice.finished.connect(queue_free, CONNECT_ONE_SHOT)
		else:
			queue_free()
	finished.emit()


func _stop_owned_sounds(except_player: AudioStreamPlayer = null) -> void:
	for child in get_children():
		if child is AudioStreamPlayer and child != except_player:
			(child as AudioStreamPlayer).stop()
			child.queue_free()


func cancel() -> void:
	if is_queued_for_deletion():
		return
	var was_done := _done
	_done = true
	if is_instance_valid(_counter):
		_counter.end_gain(_counter_token)
	hide()
	_stop_owned_sounds()
	if not was_done or _keep_label:
		cancelled.emit()
	queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		cancel()


func _exit_tree() -> void:
	if is_instance_valid(_counter):
		_counter.end_gain(_counter_token)
