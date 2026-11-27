shader_type spatial;
render_mode cull_disabled;

uniform vec3 tint : source_color = vec3(1.0);
uniform int surface_kind = 0;
varying vec2 ground_position;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float weathering(vec2 p) {
	vec2 weight = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	vec2 cell = floor(p);
	return mix(
		mix(grain(cell), grain(cell + vec2(1.0, 0.0)), weight.x),
		mix(grain(cell + vec2(0.0, 1.0)), grain(cell + vec2(1.0, 1.0)), weight.x),
		weight.y
	);
}

void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 surface_position = UV * vec2(12.5, 2.24);
	float fine = grain(floor(ground_position * 58.0));
	float variation = weathering(ground_position * 0.31);
	float shade;
	if (surface_kind == 0) {
		float along = fract(surface_position.x / 5.0);
		float joint = 1.0 - smoothstep(0.001, 0.005 + fwidth(along), min(along, 1.0 - along));
		shade = 0.90 + 0.12 * variation + 0.045 * fine - 0.16 * joint;
		shade -= 0.075 * smoothstep(0.55, 0.85, weathering(ground_position * 0.9));
	} else if (surface_kind == 1) {
		shade = 0.61 + 0.16 * variation + 0.38 * fine;
	} else {
		float mower = smoothstep(-0.08, 0.08, cos(ground_position.y * 0.49));
		shade = 0.78 + 0.10 * mower + 0.18 * variation + 0.08 * fine;
	}
	ALBEDO = tint * shade;
	ROUGHNESS = 0.98;
}
