shader_type spatial;
render_mode unshaded, cull_back;
// UV.x is metres along the screen, UV.y is top to bottom.
// Texture2D also accepts a future SubViewportTexture through set_content().
uniform sampler2D content_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float panel_pitch = 12.0;
uniform float screen_height = 4.0;
uniform float content_aspect = 3.0;
uniform float brightness = 1.0;
void fragment() {
	vec2 uv = vec2(fract(UV.x / panel_pitch), UV.y);
	// Contain the supplied artwork in every bay, retaining its exact aspect.
	float bay_aspect = panel_pitch / screen_height;
	vec2 fit = vec2(max(bay_aspect / content_aspect, 1.0), max(content_aspect / bay_aspect, 1.0));
	vec2 source_uv = (uv - 0.5) * fit + 0.5;
	float inside = step(0.0, source_uv.x) * step(source_uv.x, 1.0) * step(0.0, source_uv.y) * step(source_uv.y, 1.0);
	vec3 color = mix(vec3(0.014, 0.035, 0.085), texture(content_texture, clamp(source_uv, vec2(0.0), vec2(1.0))).rgb, inside);
	// Fine cabinet joints; no time-based animation or new light emission.
	float joint = smoothstep(0.0, 0.007, min(fract(UV.x / 0.75), 1.0 - fract(UV.x / 0.75)));
	ALBEDO = color * brightness * mix(0.87, 1.0, joint);
}
