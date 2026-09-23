shader_type canvas_item;
render_mode unshaded;

// Driven by combat's clock and camera, including pause, hitstop and fast-forward.
uniform float rain_time = 0.0;
uniform float strength : hint_range(0.0, 2.0) = 0.0;
uniform vec2 world_origin = vec2(0.0);
uniform vec2 world_size = vec2(1920.0, 1080.0);
uniform float floor_y = 786.0;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float rain_layer(vec2 world, float spacing, float speed, float seed) {
	// Shear the columns so drops fall at a slight angle, with varied spacing/speed.
	float column = floor((world.x - world.y * 0.18) / spacing);
	float random = hash(column + seed);
	float x = mod(world.x - world.y * 0.18, spacing);
	float center = spacing * (0.2 + random * 0.6);
	float distance_x = abs(x - center);
	float cycle = 190.0 + random * 180.0;
	float y = mod(world.y - rain_time * speed * (0.8 + random * 0.4)
		+ random * cycle, cycle);
	float length = 24.0 + random * 30.0;
	float streak = (1.0 - smoothstep(0.6, 1.8, distance_x))
		* smoothstep(0.0, length, y) * (1.0 - smoothstep(length, length + 3.0, y));
	return streak * (0.45 + random * 0.55);
}

float ground_splashes(vec2 world) {
	float column = floor(world.x / 60.0);
	float random = hash(column + 71.0);
	float phase = fract(rain_time * (1.5 + random) + random * 7.0);
	vec2 local = vec2(mod(world.x, 60.0) - (12.0 + random * 36.0),
		world.y - floor_y + 2.0);
	// Small expanding half-rings evaporate just above the combat floor.
	float radius = phase * 12.0 + 1.0;
	float ring = 1.0 - smoothstep(0.7, 1.8, abs(length(local * vec2(1.0, 1.8)) - radius));
	return ring * (1.0 - phase) * (1.0 - smoothstep(0.0, 3.0, local.y));
}

void fragment() {
	vec2 world = world_origin + UV * world_size;
	float above_ground = 1.0 - smoothstep(floor_y - 6.0, floor_y + 3.0, world.y);
	float rain = rain_layer(world, 42.0, 650.0, 13.0) * 0.42
		+ rain_layer(world + vec2(123.0, 0.0), 71.0, 900.0, 47.0) * 0.6;
	float splash = ground_splashes(world) * 0.6;
	float mist = exp(-abs(world.y - floor_y + 10.0) / 42.0)
		* (0.65 + 0.35 * sin(world.x * 0.012 + rain_time * 0.7));
	float haze = above_ground * 0.025 + mist * 0.09;
	float droplets = rain * above_ground + splash;
	vec3 acid_color = mix(vec3(0.25, 0.46, 0.09), vec3(0.72, 1.0, 0.3),
		clamp(droplets * 2.0, 0.0, 1.0));
	COLOR = vec4(acid_color, clamp((droplets + haze) * strength, 0.0, 0.72));
}
