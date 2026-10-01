class_name UnitEmergence
extends Control

## Presentation only. Call with committed results; cancellation never changes them.
signal finished
signal cancelled

enum Kind { COCOON, EGG }

const _CLOUD := preload("res://assets/vfx/spore_cloud/spore_cloud.tscn")
const _SPARKS := preload("res://assets/vfx/hit_burst/hit_burst.tscn")
const _COCOON_LANDING_TIME := 0.86
const _EGG_LANDING_TIME := 0.56
const _SETTLE_TIME := 0.18
const _EGG_WALK_START := 0.78
const _EGG_STAGGER := 0.1

var _kind: Kind
var _elapsed := 0.0
var _anticipation := 0.42
var _landing_time := _COCOON_LANDING_TIME
var _end_time := 1.16
var _walk_speed := 520.0
var _right_edge := 0.0
var _released := false
var _landed := false
var _done := false
var _cue_started := false
var _duck_started := false
var _duck: Node
var _shell: Sprite2D
var _shell_shadow: Sprite2D
var _shell_origin := Vector2.ZERO
var _shell_scale := Vector2.ONE
var _shell_tint := Color.WHITE
var _shell_size := Vector2.ZERO
var _ground := 0.0
var _hop := 0.0
var _actors: Array[UnitAppearance] = []
var _shadows: Array[Node2D] = []
var _landings: Array[Vector2] = []
var _starts: Array[Vector2] = []
var _destination_transforms: Array[Transform2D] = []
var _actor_delays: Array[float] = []
var _flight_hops: Array[float] = []
var _actor_landed: Array[bool] = []
var _walking: Array[bool] = []
var _tints: Array[Color] = []
var _pieces: Array[Sprite2D] = []
var _piece_origins: Array[Vector2] = []
var _flash: Sprite2D
var _backdrop: ColorRect


## Capture before a transaction refreshes or clears the source art.
static func capture_shell(shell: TextureRect) -> Dictionary:
	var transform := shell.get_global_transform_with_canvas()
	return {
		"texture": shell.texture,
		"tint": shell.modulate,
		"canvas_rect": Rect2(transform * Vector2.ZERO, transform * shell.size - transform * Vector2.ZERO),
	}


static func play(
	parent: Control,
	units: Array[RosterUnitData],
	shell: Dictionary,
	kind: Kind,
	destinations: Array[Transform2D] = []
) -> UnitEmergence:
	DetailTooltipPopup.dismiss_current()
	var effect := UnitEmergence.new()
	effect.name = "UnitEmergence"
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.z_index = 90
	parent.add_child(effect)
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect._build(units, shell, kind, destinations)
	return effect


func _ready() -> void:
	get_viewport().size_changed.connect(cancel)


func _build(
	units: Array[RosterUnitData], snapshot: Dictionary, kind: Kind,
	destinations: Array[Transform2D]
) -> void:
	_kind = kind
	_anticipation = 0.32 if kind == Kind.EGG else 0.42
	_landing_time = _EGG_LANDING_TIME if kind == Kind.EGG else _COCOON_LANDING_TIME
	var texture := snapshot.get("texture") as Texture2D
	if texture == null or units.is_empty():
		cancel.call_deferred()
		return
	var canvas_rect: Rect2 = snapshot.canvas_rect
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var visible_rect: Rect2 = inverse * get_viewport().get_visible_rect()
	_right_edge = visible_rect.end.x
	var shell_rect := Rect2(inverse * canvas_rect.position, inverse.basis_xform(canvas_rect.size))
	var texture_size := texture.get_size()
	var ratio := minf(shell_rect.size.x / texture_size.x, shell_rect.size.y / texture_size.y)
	_shell_size = texture_size * ratio
	_shell_origin = shell_rect.get_center()
	_shell_scale = Vector2.ONE * ratio
	_shell_tint = snapshot.get("tint", Color.WHITE)
	_shell = Sprite2D.new()
	_shell.texture = texture
	_shell.position = _shell_origin
	_shell.scale = _shell_scale
	_shell.modulate = _shell_tint
	_shell.z_index = 3
	add_child(_shell)
	var shadow_texture := snapshot.get("shadow_texture") as Texture2D
	if shadow_texture != null:
		_shell_shadow = Sprite2D.new()
		_shell_shadow.texture = shadow_texture
		_shell_shadow.position = _shell_origin
		_shell_shadow.scale = _shell_scale
		add_child(_shell_shadow)
	# Transparent padding in egg art must not move the feet below the painted shell.
	var painted := Rect2(Vector2.ZERO, texture_size)
	var shell_image := texture.get_image()
	if shell_image != null and not shell_image.is_empty():
		if not shell_image.is_compressed() or shell_image.decompress() == OK:
			painted = Rect2(shell_image.get_used_rect())
	_ground = _shell_origin.y + (float(painted.end.y) - texture_size.y * 0.5) * ratio
	_hop = clampf(shell_rect.size.y * 0.48, 72.0, 110.0)
	_make_backdrop()
	_build_actors(units, destinations, inverse)
	_make_pieces(texture)
	_make_flash()


func _build_actors(
	units: Array[RosterUnitData], destinations: Array[Transform2D], canvas_inverse: Transform2D
) -> void:
	var cell_width := 0.0
	var body_width := 0.0
	var max_height := 0.0
	for i in units.size():
		var unit := units[i]
		var actor := UnitAppearance.compose_player(unit.is_adult_stage(), unit.body_mutation, unit.cap_mutation)
		actor.name = "RevealedUnit%d" % _actors.size()
		actor.set_meta("unit", unit)
		add_child(actor)
		actor.mount_weapon_appearance(unit.weapon)
		actor.modulate = UnitStatsData.tint_for_tier(unit.power_tier)
		# Match the actual roster portrait for cocoons; eggs retain authored stage scale.
		if _kind == Kind.COCOON and i < destinations.size():
			actor.transform = canvas_inverse * destinations[i]
		else:
			actor.scale *= UnitCard.PORTRAIT_SCALE
		actor.z_index = 5
		actor.play_idle(false)
		var basis := actor.transform
		basis.origin = Vector2.ZERO
		var bounds: Rect2 = basis * actor.visual_rect_local(true, true)
		var body: Rect2 = basis * actor.visual_rect_local(false, true)
		var half_width := maxf(body.get_center().x - bounds.position.x, bounds.end.x - body.get_center().x)
		cell_width = maxf(cell_width, half_width * 2.0 + 24.0)
		body_width = maxf(body_width, body.size.x + 32.0)
		max_height = maxf(max_height, -bounds.position.y)
		_actors.append(actor)
		_tints.append(actor.modulate)
		_destination_transforms.append(actor.transform)
		# The leading, rightmost hatch starts first so the following units do not bunch up.
		_actor_delays.append(float(units.size() - 1 - i) * _EGG_STAGGER if _kind == Kind.EGG else 0.0)
		_actor_landed.append(false)
		_walking.append(false)
		actor.hide()
	# Keep each body readable in a wide hatch; never shrink it to fit the shell or group.
	var spacing := cell_width
	if units.size() > 1 and cell_width * units.size() > size.x - 32.0:
		spacing = maxf(body_width, (size.x - 32.0 - cell_width) / float(units.size() - 1))
	var half_group := (cell_width + spacing * (units.size() - 1)) * 0.5
	var center_x := clampf(_shell_origin.x, 16.0 + half_group, maxf(16.0 + half_group, size.x - 16.0 - half_group))
	if half_group > (size.x - 32.0) * 0.5:
		center_x = size.x * 0.5
	if _kind == Kind.EGG:
		_ground = clampf(_ground, minf(max_height + _hop + 12.0, size.y - 20.0), size.y - 20.0)
	var longest_walk := 0.0
	for i in _actors.size():
		var actor := _actors[i]
		var destination := _destination_transforms[i]
		var basis := destination
		basis.origin = Vector2.ZERO
		var body: Rect2 = basis * actor.visual_rect_local(false, true)
		if _kind == Kind.EGG or i >= destinations.size():
			destination.origin = Vector2(center_x + (float(i) - float(units.size() - 1) * 0.5) * spacing - body.get_center().x, _ground)
		_destination_transforms[i] = destination
		_landings.append(destination.origin)
		_starts.append(Vector2(_shell_origin.x - body.get_center().x, _ground))
		actor.transform = destination
		if _kind == Kind.COCOON:
			var distance := _starts[i].distance_to(destination.origin)
			var desired_hop := maxf(_hop, minf(240.0, 120.0 + distance * 0.14))
			_flight_hops.append(_visible_flight_hop(actor, _starts[i], destination, desired_hop))
		else:
			_flight_hops.append(_hop)
			var bounds: Rect2 = destination * actor.visual_rect_local(true, true)
			longest_walk = maxf(longest_walk, _right_edge + 32.0 - bounds.position.x)
		var shadow := actor.get_node_or_null("GroundShadow") as Node2D
		if shadow != null:
			shadow.reparent(self, true)
			shadow.z_index = 0
			shadow.hide()
		_shadows.append(shadow)
	if _kind == Kind.EGG:
		_walk_speed = maxf(520.0, longest_walk / 1.7)
		_end_time = _EGG_WALK_START + float(_actor_delays.max()) + longest_walk / _walk_speed
	else:
		_end_time = _landing_time + _SETTLE_TIME + 0.12


func _visible_flight_hop(
	actor: UnitAppearance, start: Vector2, destination: Transform2D, desired: float
) -> float:
	var hop := desired
	var bounds := actor.visual_rect_local(true, true)
	var basis := destination
	basis.origin = Vector2.ZERO
	# Upper Bench arrivals need a lower apex, not a smaller unit or shifted landing.
	# Include the in-flight tilt and spare room for the authored idle motion.
	for step in range(1, 40):
		var progress := float(step) / 40.0
		var turn := Transform2D(-sin(progress * PI) * 0.14, Vector2.ZERO)
		var painted: Rect2 = turn * basis * bounds
		var floor_y := lerpf(start.y, destination.origin.y, progress)
		var lift := 4.0 * progress * (1.0 - progress)
		hop = minf(hop, maxf(0.0, (floor_y + painted.position.y - 24.0) / lift))
	return hop


func _make_backdrop() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "RevealBackdrop"
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.z_index = -1
	_backdrop.color = Color(0.06, 0.11, 0.08, 0.0)
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _make_pieces(texture: Texture2D) -> void:
	var dimensions := texture.get_size()
	for i in 2:
		var piece := Sprite2D.new()
		piece.texture = texture
		piece.region_enabled = true
		piece.region_filter_clip_enabled = true
		var offset: Vector2
		if _kind == Kind.EGG:
			piece.region_rect = Rect2(0, dimensions.y * 0.5 * i, dimensions.x, dimensions.y * 0.5)
			offset = Vector2(0, (float(i) - 0.5) * _shell_size.y * 0.5)
		else:
			piece.region_rect = Rect2(dimensions.x * 0.5 * i, 0, dimensions.x * 0.5, dimensions.y)
			offset = Vector2((float(i) - 0.5) * _shell_size.x * 0.5, 0)
		piece.scale = _shell_scale
		piece.modulate = _shell_tint
		piece.z_index = 4
		piece.hide()
		add_child(piece)
		_pieces.append(piece)
		_piece_origins.append(_shell_origin + offset)


func _make_flash() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 0.92, 0.62, 0.5), Color(1, 0.92, 0.62, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	_flash = Sprite2D.new()
	_flash.texture = texture
	_flash.position = _shell_origin
	_flash.scale = Vector2.ONE * _shell_size.y / 64.0
	_flash.z_index = 1
	_flash.hide()
	add_child(_flash)


func _process(delta: float) -> void:
	if _done or _shell == null:
		return
	_elapsed += delta
	var recovery := smoothstep(_anticipation, _anticipation + 0.45, _elapsed)
	_backdrop.color.a = 0.42 * smoothstep(0.0, 0.2, _elapsed) * (1.0 - recovery)
	if not _duck_started and _elapsed >= _anticipation - 0.18:
		_duck_started = true
		_duck = Audio.acquire_reveal_audio(self)
	var cue_lead := Sfx.COCOON_EMERGE_TRANSIENT_SECONDS if _kind == Kind.COCOON else 0.0
	if not _cue_started and _elapsed >= _anticipation - cue_lead:
		_cue_started = true
		Audio.play_owned_ui_cue(self, Sfx.Cue.COCOON_EMERGE if _kind == Kind.COCOON else Sfx.Cue.HARVEST)
	if _elapsed < _anticipation:
		_animate_anticipation()
		return
	if not _released:
		_release()
	var age := _elapsed - _anticipation
	if age >= 0.24:
		_release_duck()
	_animate_emergence(age)
	if age >= _end_time and (_kind == Kind.COCOON or _eggs_have_exited()):
		_done = true
		_release_duck()
		hide()
		finished.emit()
		queue_free()


func _animate_anticipation() -> void:
	var tension := _elapsed / _anticipation
	var squash := smoothstep(0.45, 1.0, tension) * 0.16
	_shell.scale = _shell_scale * Vector2(1.0 + squash, 1.0 - squash)
	_shell.position = _shell_origin + Vector2(sin(_elapsed * 72.0) * tension * _shell_size.x * 0.035, _shell_size.y * squash * 0.5)
	_shell.rotation = sin(_elapsed * 53.0) * tension * 0.07
	_shell.modulate = _shell_tint * Color.WHITE.lerp(Color(1.45, 1.3, 1.0), tension)


func _release() -> void:
	_released = true
	_shell.hide()
	_flash.show()
	for piece in _pieces:
		piece.show()
	_burst(_shell_origin, true)


func _animate_emergence(age: float) -> void:
	for i in _actors.size():
		var actor_age := age - _actor_delays[i]
		if actor_age < 0.0:
			continue
		var actor := _actors[i]
		actor.show()
		var pose := _destination_transforms[i]
		var floor_position := _landings[i]
		var lift := 0.0
		var tilt := 0.0
		if actor_age < _landing_time:
			var progress := actor_age / _landing_time
			floor_position = _starts[i].lerp(_landings[i], progress)
			lift = 4.0 * progress * (1.0 - progress)
			pose.origin = floor_position - Vector2(0, _flight_hops[i] * lift)
			tilt = -sin(progress * PI) * 0.14
		elif actor_age < _landing_time + _SETTLE_TIME:
			var settle := (actor_age - _landing_time) / _SETTLE_TIME
			pose.origin.y -= sin(settle * PI) * 8.0
			tilt = sin(settle * TAU) * 0.018 * (1.0 - settle)
		if _kind == Kind.EGG and actor_age >= _EGG_WALK_START:
			if not _walking[i]:
				_walking[i] = true
				actor.play_walk(false, 2.1)
			pose.origin.x += (actor_age - _EGG_WALK_START) * _walk_speed
			floor_position = pose.origin
		if not is_zero_approx(tilt):
			var turn := Transform2D(tilt, Vector2.ZERO)
			pose.x = turn.basis_xform(pose.x)
			pose.y = turn.basis_xform(pose.y)
		actor.transform = pose
		actor.modulate = _tints[i] * Color(1.25, 1.16, 1.0).lerp(Color.WHITE, smoothstep(0.0, 0.16, actor_age))
		var shadow := _shadows[i]
		if shadow != null:
			shadow.show()
			shadow.position = floor_position
			shadow.modulate.a = lerpf(1.0, 0.5, lift)
		if actor_age >= _landing_time and not _actor_landed[i]:
			_actor_landed[i] = true
			_burst(_landings[i], false)
			if not _landed:
				_landed = true
				Audio.play_owned_ui_cue(self, Sfx.Cue.GROUND)
	var split := clampf(age / 0.5, 0.0, 1.0)
	for i in _pieces.size():
		var side := -1.0 if i == 0 else 1.0
		var piece := _pieces[i]
		piece.position = _piece_origins[i] + Vector2(side * _shell_size.x * 0.55 * (1.0 - pow(1.0 - split, 2.0)), _shell_size.y * (-0.24 * sin(split * PI) + 0.3 * split * split))
		piece.rotation = side * split * 0.85
		piece.modulate.a = _shell_tint.a * (1.0 - smoothstep(0.16, 0.5, age))
	_flash.modulate.a = 1.0 - smoothstep(0.0, 0.16, age)
	if _shell_shadow != null:
		_shell_shadow.modulate.a = 1.0 - smoothstep(0.0, 0.2, age)


func _eggs_have_exited() -> bool:
	for i in _actors.size():
		if not _walking[i]:
			return false
		var actor := _actors[i]
		var bounds: Rect2 = actor.transform * actor.visual_rect_local(true, true)
		if bounds.position.x <= _right_edge:
			return false
	return true


func _burst(at: Vector2, release: bool) -> void:
	var cloud: SporeCloud = _CLOUD.instantiate()
	add_child(cloud)
	cloud.position = at
	cloud.z_index = 1
	cloud.burst(Color("ffe992") if release else Color("d7c985"), 0.45)
	var particles := cloud.get_node("Particles") as CPUParticles2D
	particles.local_coords = true
	particles.amount = 18 if release else 10
	particles.lifetime = 0.4
	particles.initial_velocity_min = 35.0
	particles.initial_velocity_max = 90.0
	particles.gravity = Vector2(0, 90)
	if release:
		var sparks: HitBurst = _SPARKS.instantiate()
		add_child(sparks)
		sparks.position = at
		sparks.z_index = 4
		sparks.burst(Color("fff1ac"), 0.8)


func _release_duck() -> void:
	if is_instance_valid(_duck):
		_duck.queue_free()
	_duck = null


func cancel() -> void:
	if _done:
		return
	_done = true
	_release_duck()
	hide()
	# Owned sound players cannot leak into another tab or survive an Undo.
	for child in get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
	cancelled.emit()
	queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		cancel()


func _exit_tree() -> void:
	_release_duck()
