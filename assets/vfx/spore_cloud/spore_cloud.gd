class_name SporeCloud
extends Node2D

@onready var _particles: CPUParticles2D = $Particles


func _ready() -> void:
	_particles.texture = _make_glow_texture()
	_particles.finished.connect(queue_free)


func burst(
	color: Color = Color("b7b08d"),
	size_scale: float = 1.0,
	momentum: Vector2 = Vector2.ZERO
) -> void:
	_particles.color = color
	_particles.scale_amount_min = 0.45 * size_scale
	_particles.scale_amount_max = 1.35 * size_scale
	if momentum.length_squared() > 1.0:
		_particles.direction = momentum.normalized()
		_particles.spread = 50.0
		var speed := momentum.length()
		_particles.initial_velocity_min = speed * 0.45
		_particles.initial_velocity_max = speed * 1.05
		# Soften upward bias so hop direction reads clearly.
		_particles.gravity = Vector2(0.0, -18.0)
	_particles.emitting = true


## Fill a combat AOE disk (e.g. spore mortar detonation).
func burst_aoe(radius: float, color: Color = Color("b7b08d")) -> void:
	var r := maxf(radius, 24.0)
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = r
	_particles.amount = clampi(int(r * 0.55), 32, 80)
	_particles.explosiveness = 0.92
	_particles.lifetime = 1.35
	_particles.spread = 180.0
	_particles.direction = Vector2(0.0, -1.0)
	_particles.gravity = Vector2(0.0, -28.0)
	_particles.initial_velocity_min = 28.0
	_particles.initial_velocity_max = maxf(55.0, r * 0.45)
	var puff := clampf(r / 55.0, 1.15, 2.8)
	_particles.color = color
	_particles.scale_amount_min = 0.55 * puff
	_particles.scale_amount_max = 1.65 * puff
	_particles.emitting = true


func _make_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.65),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture
