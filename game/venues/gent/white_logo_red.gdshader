shader_type spatial;
render_mode cull_disabled;
uniform sampler2D wordmark : source_color, filter_linear_mipmap, repeat_disable;
uniform float panel_aspect = 4.0;
uniform bool two_sided_banner = false;
uniform vec4 red_background : source_color = vec4(0.725, 0.047, 0.102, 1.0);

void fragment() {
	// Use the front lettering of the existing Vélodrome artwork as white ink.
	// Fit its original proportions within each red panel, with a clear margin.
	vec2 logo_size = vec2(min(0.88, 0.78 * 3.626 / panel_aspect), min(0.78, 0.88 * panel_aspect / 3.626));
	vec2 panel_uv = UV;
	if (two_sided_banner && !FRONT_FACING) { panel_uv.x = 1.0 - panel_uv.x; }
	vec2 local_uv = (panel_uv - vec2(0.5)) / logo_size + vec2(0.5);
	float inside = step(0.0, local_uv.x) * step(local_uv.x, 1.0) * step(0.0, local_uv.y) * step(local_uv.y, 1.0);
	vec2 source_uv = vec2(0.01888, 0.13950) + local_uv * vec2(0.97652, 0.80801);
	vec4 logo = texture(wordmark, source_uv);
	// Exclude the blue extrusion: filling the whole alpha silhouette would
	// close the letter counters and merge neighbouring glyphs at a distance.
	float letters = smoothstep(0.35, 0.65, min(logo.r, min(logo.g, logo.b)));
	float oval = smoothstep(0.45, 0.70, logo.r) * smoothstep(0.12, 0.30, logo.g) * (1.0 - smoothstep(0.25, 0.50, logo.b));
	float ink = max(letters, oval) * logo.a * inside;
	ALBEDO = mix(red_background.rgb, vec3(1.0), ink);
	ROUGHNESS = 0.85;
	SPECULAR = 0.12;
}
