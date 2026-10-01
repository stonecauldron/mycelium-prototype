class_name CompostRelease
extends Control

## Presentation only: spores are the actual committed additions to Stock.
signal finished
signal cancelled

const _SPORE_TEXTURE := preload("res://assets/base/nursery/spores.png")
const _CLOUD := preload("res://assets/vfx/spore_cloud/spore_cloud.tscn")
const _SPARKS := preload("res://assets/vfx/hit_burst/hit_burst.tscn")
const ANTICIPATION_SECONDS := 0.42
const _FLIGHT_TIME := 0.95
const _SPORE_DELAY := 0.045
const _DIM_ALPHA := 0.42

var _elapsed := 0.0
var _released := false
var _done := false
var _duck: Node
var _bin: Sprite2D
var _bin_scale := Vector2.ONE
var _bin_tint := Color.WHITE
var _bin_size := Vector2.ZERO
var _opening := Vector2.ZERO
var _dim: ColorRect
var _spores: Array[Sprite2D] = []
var _flight_ends: Array[Vector2] = []


static func play(
	parent: Control,
	bin_snapshot: Dictionary,
	released_spores: Array[SporeData],
	dim_background: bool = true
) -> CompostRelease:
	DetailTooltipPopup.dismiss_current()
	var effect := CompostRelease.new()
	effect.name = "CompostRelease"
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.process_mode = Node.PROCESS_MODE_PAUSABLE
	effect.z_index = 90
	parent.add_child(effect)
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect._build(bin_snapshot, released_spores, dim_background)
	return effect


func _ready() -> void:
	get_viewport().size_changed.connect(cancel)


func _build(snapshot: Dictionary, released_spores: Array[SporeData], dim_background: bool) -> void:
	var texture := snapshot.get("texture") as Texture2D
	var canvas_rect: Rect2 = snapshot.get("canvas_rect", Rect2())
	if texture == null or not canvas_rect.has_area() or get_tree().paused:
		cancel.call_deferred()
		return
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var bin_rect := inverse * canvas_rect
	var texture_size := texture.get_size()
	var ratio := minf(bin_rect.size.x / texture_size.x, bin_rect.size.y / texture_size.y)
	_bin_size = texture_size * ratio
	_bin_scale = Vector2.ONE * ratio
	_bin_tint = snapshot.get("tint", Color.WHITE)
	var painted := Rect2(Vector2.ZERO, texture_size)
	var image := texture.get_image()
	if image != null and not image.is_empty():
		if not image.is_compressed() or image.decompress() == OK:
			painted = Rect2(image.get_used_rect())
	var ground := bin_rect.get_center().y + (painted.end.y - texture_size.y * 0.5) * ratio
	_opening = bin_rect.get_center() + Vector2(0, -_bin_size.y * 0.3)
	_bin = Sprite2D.new()
	_bin.name = "AnimatedBin"
	_bin.texture = texture
	_bin.centered = false
	# Pin the painted base, so squash never lifts or sinks the bin into its ground.
	_bin.offset = Vector2(-texture_size.x * 0.5, -painted.end.y)
	_bin.position = Vector2(bin_rect.get_center().x, ground)
	_bin.scale = _bin_scale
	_bin.modulate = _bin_tint
	_bin.z_index = 2
	add_child(_bin)
	if dim_background:
		_dim = ColorRect.new()
		_dim.name = "RevealDim"
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dim.color = Color(0.025, 0.045, 0.02, 0.0)
		_dim.z_index = -1
		add_child(_dim)
		_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var atlas := AtlasTexture.new()
	atlas.atlas = _SPORE_TEXTURE
	atlas.region = Rect2(157, 174, 211, 167)
	var screen_rect := inverse * get_viewport().get_visible_rect()
	for spore in released_spores:
		if spore == null:
			continue
		var icon := Sprite2D.new()
		icon.name = "ReleasedSpore%d" % _spores.size()
		icon.set_meta("spore", spore)
		icon.texture = atlas
		icon.modulate = spore.tint
		icon.scale = Vector2.ONE * 84.0 / atlas.get_width()
		icon.position = _opening
		icon.z_index = 4
		icon.hide()
		add_child(icon)
		_spores.append(icon)
		_flight_ends.append(Vector2(screen_rect.position.x - 120.0 - _spores.size() * 24.0,
			_opening.y - 70.0 - _spores.size() * 16.0))


func _process(delta: float) -> void:
	if _done or _bin == null:
		return
	if not is_visible_in_tree():
		cancel()
		return
	_elapsed += delta
	if _duck == null and _elapsed < ANTICIPATION_SECONDS and _elapsed >= ANTICIPATION_SECONDS - 0.18:
		_duck = Audio.acquire_reveal_audio(self)
	if _elapsed < ANTICIPATION_SECONDS:
		var tension := smoothstep(0.0, 1.0, _elapsed / ANTICIPATION_SECONDS)
		_bin.scale = _bin_scale * Vector2(1.0 + tension * 0.2, 1.0 - tension * 0.3)
		_bin.modulate = _bin_tint * Color.WHITE.lerp(Color(1.15, 1.1, 0.94), tension)
		if _dim != null:
			_dim.color.a = _DIM_ALPHA * tension
		return
	if not _released:
		_release()
	var age := _elapsed - ANTICIPATION_SECONDS
	if age >= 0.24:
		_release_duck()
	_animate_release(age)
	var duration := _FLIGHT_TIME + float(maxi(_spores.size() - 1, 0)) * _SPORE_DELAY
	if age >= duration:
		_done = true
		_release_duck()
		hide()
		finished.emit()
		queue_free()


func _release() -> void:
	_released = true
	Audio.play_owned_ui_cue(self, Sfx.Cue.COMPOST)
	var cloud: SporeCloud = _CLOUD.instantiate()
	add_child(cloud)
	cloud.position = _opening
	cloud.z_index = 3
	var particles := cloud.get_node("Particles") as CPUParticles2D
	particles.local_coords = true
	particles.amount = 24
	particles.lifetime = 0.45
	particles.direction = Vector2.UP
	particles.spread = 65.0
	particles.gravity = Vector2(0, 100)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 140.0
	cloud.burst(Color("d7c985"), 0.65)
	var sparks: HitBurst = _SPARKS.instantiate()
	add_child(sparks)
	sparks.position = _opening
	sparks.z_index = 3
	sparks.burst(Color("ffe992"), 0.65)


func _animate_release(age: float) -> void:
	var stretch := sin(minf(age / 0.16, 1.0) * PI * 0.5)
	if age < 0.16:
		_bin.scale = _bin_scale * Vector2(lerpf(1.2, 0.88, stretch), lerpf(0.7, 1.17, stretch))
	else:
		var settle := clampf((age - 0.16) / 0.4, 0.0, 1.0)
		var bounce := cos(settle * PI * 2.0) * pow(1.0 - settle, 2.0)
		_bin.scale = _bin_scale * Vector2(1.0 - bounce * 0.12, 1.0 + bounce * 0.17)
	_bin.modulate = _bin_tint
	if _dim != null:
		_dim.color.a = _DIM_ALPHA * (1.0 - smoothstep(0.0, 0.45, age))
	for i in _spores.size():
		var flight_age := age - i * _SPORE_DELAY
		if flight_age < 0.0:
			continue
		var icon := _spores[i]
		icon.show()
		var travel := clampf(flight_age / _FLIGHT_TIME, 0.0, 1.0)
		var lift := minf(220.0, maxf(_opening.y - 45.0, 80.0))
		var first := _opening + Vector2(80.0 + i * 35.0, -lift)
		var second := Vector2(lerpf(_opening.x, _flight_ends[i].x, 0.52), _opening.y - lift)
		icon.position = _opening.bezier_interpolate(first, second, _flight_ends[i], travel)
		icon.rotation = sin(travel * PI) * -0.45


func _release_duck() -> void:
	if is_instance_valid(_duck):
		_duck.queue_free()
	_duck = null


func biomass_source_canvas_rect() -> Rect2:
	return get_global_transform_with_canvas() * Rect2(_opening + Vector2(-170, -100), Vector2(340, 100))


func cancel() -> void:
	if _done:
		return
	_done = true
	_release_duck()
	hide()
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
	if not _done:
		_done = true
		cancelled.emit()
