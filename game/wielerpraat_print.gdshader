shader_type spatial;
render_mode cull_disabled;

// Reuse UV crops of the existing artwork as ink on the tent fabric.
// Removing only its blue background avoids blue rectangular patches on the roof.
uniform sampler2D logo : source_color, filter_linear_mipmap, repeat_disable;

void fragment() {
	vec3 ink = texture(logo, UV).rgb;
	float background = smoothstep(0.02, 0.06, ink.b - max(ink.r, ink.g));
	background *= 1.0 - smoothstep(0.4, 0.75, min(ink.r, min(ink.g, ink.b)));
	if (background > 0.98) discard;
	ALBEDO = ink;
	ALPHA = 1.0 - background;
	ROUGHNESS = 0.85;
}
