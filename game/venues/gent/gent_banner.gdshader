shader_type spatial;
render_mode cull_disabled;
uniform sampler2D poster : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float panel_aspect = 3.0;
uniform float poster_aspect = 3.0;
uniform vec4 art_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool two_sided_banner = false;
uniform bool white_on_red = false;
uniform vec4 margin_colour : source_color = vec4(1.0);
uniform vec4 boarding_red : source_color = vec4(0.847059, 0.149020, 0.196078, 1.0);

void fragment() {
	vec2 panel_uv = UV;
	if (two_sided_banner && !FRONT_FACING) { panel_uv.x = 1.0 - panel_uv.x; }
	vec2 fit = vec2(min(1.0, poster_aspect / panel_aspect), min(1.0, panel_aspect / poster_aspect));
	vec2 local_uv = (panel_uv - vec2(0.5)) / fit + vec2(0.5);
	vec2 source_uv = art_uv.xy + clamp(local_uv, vec2(0.0), vec2(1.0)) * art_uv.zw;
	vec3 color = texture(poster, source_uv).rgb;
	float inside = step(0.0, local_uv.x) * step(local_uv.x, 1.0) * step(0.0, local_uv.y) * step(local_uv.y, 1.0);
	if (white_on_red) {
		// The PNG already contains clean white letterforms. A continuous ink
		// coverage keeps its antialiasing, while every red pixel uses exactly
		// the boarding colour, including margins and mipmapped distant views.
		float ink = clamp((min(color.g, color.b) - 0.20) / 0.80, 0.0, 1.0) * inside;
		color = mix(boarding_red.rgb, vec3(1.0), ink);
	} else {
		color = mix(margin_colour.rgb, color, inside);
	}
	ALBEDO = color;
	ROUGHNESS = 0.85;
	SPECULAR = 0.5;
}
