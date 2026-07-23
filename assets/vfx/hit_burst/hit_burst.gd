class_name HitBurst
extends Node2D

@onready var _particles: CPUParticles2D = $Particles


func _ready() -> void:
	_particles.texture = _make_spark_texture()
	_particles.finished.connect(queue_free)


func burst(color: Color = Color(1.0, 0.75, 0.35, 1.0), size_scale: float = 1.0) -> void:
	_particles.color = color
	_particles.scale_amount_min = 0.35 * size_scale
	_particles.scale_amount_max = 0.85 * size_scale
	_particles.emitting = true


func _make_spark_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.85),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 12
	texture.height = 12
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture
