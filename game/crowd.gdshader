// Velodrome 250 – crowd shader (MultiMesh friendly, GL Compatibility safe).
// The Blender meshes store a body-region id in UV.x (see assets/source_blender/crowd/vlib.py).
//   instance COLOR          -> shirt / top colour (sRGB)
//   INSTANCE_CUSTOM.r       -> skin tone 0..1 (light .. dark)
//   INSTANCE_CUSTOM.g       -> hair colour index 0..1
//   INSTANCE_CUSTOM.b       -> trousers / skirt colour index 0..1
//   INSTANCE_CUSTOM.a       -> accent colour (scarf, cap, apron, lanyard) index 0..1
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_back;

uniform float excitement : hint_range(0.0, 1.0) = 0.15;   // driven by arena.gd (last lap, sprint)
uniform float bounce_height = 0.06;
uniform float bounce_share : hint_range(0.0, 1.0) = 0.55;
uniform float wave_center = 0.0;
uniform float wave_strength = 0.0;  // fraction of the crowd that jumps along

varying vec4 v_custom;

vec3 to_linear(vec3 c) { return pow(c, vec3(2.2)); }

vec3 skin_tone(float t) {
	vec3 a = vec3(0.98, 0.82, 0.70);
	vec3 b = vec3(0.93, 0.70, 0.54);
	vec3 c = vec3(0.78, 0.54, 0.38);
	vec3 d = vec3(0.55, 0.36, 0.24);
	vec3 e = vec3(0.36, 0.23, 0.15);
	float x = clamp(t, 0.0, 1.0) * 4.0;
	if (x < 1.0) return mix(a, b, x);
	if (x < 2.0) return mix(b, c, x - 1.0);
	if (x < 3.0) return mix(c, d, x - 2.0);
	return mix(d, e, x - 3.0);
}

vec3 hair_colour(float t) {
	int i = int(clamp(t, 0.0, 0.999) * 8.0);
	if (i == 0) return vec3(0.10, 0.08, 0.07);
	if (i == 1) return vec3(0.22, 0.14, 0.09);
	if (i == 2) return vec3(0.36, 0.22, 0.12);
	if (i == 3) return vec3(0.55, 0.38, 0.20);
	if (i == 4) return vec3(0.85, 0.70, 0.42);
	if (i == 5) return vec3(0.62, 0.28, 0.12);
	if (i == 6) return vec3(0.62, 0.62, 0.62);
	return vec3(0.16, 0.10, 0.07);
}

vec3 bottom_colour(float t) {
	int i = int(clamp(t, 0.0, 0.999) * 8.0);
	if (i == 0) return vec3(0.20, 0.27, 0.42);   // denim
	if (i == 1) return vec3(0.12, 0.13, 0.15);   // black
	if (i == 2) return vec3(0.62, 0.56, 0.44);   // khaki
	if (i == 3) return vec3(0.40, 0.42, 0.45);   // grey
	if (i == 4) return vec3(0.13, 0.18, 0.32);   // navy
	if (i == 5) return vec3(0.30, 0.40, 0.58);   // light denim
	if (i == 6) return vec3(0.30, 0.25, 0.20);   // brown
	return vec3(0.85, 0.85, 0.82);               // white / light
}

vec3 accent_colour(float t) {
	int i = int(clamp(t, 0.0, 0.999) * 8.0);
	if (i == 0) return vec3(0.95, 0.80, 0.10);
	if (i == 1) return vec3(0.90, 0.20, 0.20);
	if (i == 2) return vec3(0.10, 0.10, 0.12);
	if (i == 3) return vec3(0.95, 0.45, 0.10);
	if (i == 4) return vec3(0.20, 0.50, 0.95);
	if (i == 5) return vec3(0.25, 0.65, 0.35);
	if (i == 6) return vec3(0.96, 0.96, 0.96);
	return vec3(0.55, 0.25, 0.65);
}

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	float h = fract(sin(float(INSTANCE_ID) * 12.9898 + v_custom.r * 78.233) * 43758.5453);
	float phase = h * 6.2831;
	// breathing / fidgeting for everyone, bouncing for part of the crowd when it gets exciting
	float idle = sin(TIME * (1.1 + h * 0.6) + phase) * 0.004;
	float jumper = step(1.0 - bounce_share, fract(h * 7.31));
	float b = pow(max(0.0, sin(TIME * (5.5 + h * 2.0) + phase)), 2.0) * excitement * bounce_height * jumper;
	vec3 world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float angle = atan(world_at.z, world_at.x) / 6.283185 + 0.5;
	float circular_gap = abs(fract(angle - wave_center + 0.5) - 0.5);
	float cheer = smoothstep(0.16, 0.0, circular_gap) * wave_strength;
	VERTEX.y += idle + b + 0.09 * cheer * (0.4 + 0.6 * h);
}

void fragment() {
	int r = int(UV.x * 16.0);
	vec3 shirt = to_linear(COLOR.rgb);
	vec3 c = shirt;
	if (r == 0) c = to_linear(skin_tone(v_custom.r));
	else if (r == 1) c = to_linear(hair_colour(v_custom.g));
	else if (r == 2) c = shirt;
	else if (r == 3) c = to_linear(bottom_colour(v_custom.b));
	else if (r == 4) c = to_linear(fract(v_custom.r * 7.3 + v_custom.b * 3.1) < 0.5 ? vec3(0.92, 0.92, 0.90) : vec3(0.14, 0.14, 0.16));
	else if (r == 5) c = to_linear(vec3(0.10, 0.08, 0.07));
	else if (r == 6) c = to_linear(vec3(0.96, 0.96, 0.95));
	else if (r == 7) c = to_linear(vec3(0.45, 0.20, 0.17));
	else if (r == 8) c = to_linear(accent_colour(v_custom.a));
	else if (r == 9) c = to_linear(vec3(0.12, 0.12, 0.13));
	else if (r == 10) c = shirt * 0.55;
	else if (r == 11) c = to_linear(vec3(0.72, 0.74, 0.76));
	else if (r == 12) c = to_linear(vec3(0.80, 0.34, 0.40));
	else if (r == 13) c = to_linear(hair_colour(v_custom.g)) * 0.7;
	ALBEDO = c;
	ROUGHNESS = (r == 9 || r == 11) ? 0.35 : 0.78;
	SPECULAR = 0.3;
}
