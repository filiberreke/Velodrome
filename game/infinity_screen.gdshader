shader_type spatial;
render_mode unshaded, cull_back;
// UV.x is metres along the screen, UV.y is top to bottom.
// Texture2D also accepts a future SubViewportTexture through set_content().
uniform sampler2D content_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float panel_pitch = 12.0;
uniform float screen_height = 4.0;
uniform float content_aspect = 3.0;
uniform float brightness = 1.0;
// Four fixed scoreboard locations: the centres of the two straights and ends.
// The spaces between them carry brand artwork rather than more score copies.
uniform bool zoned_content = false;
uniform sampler2D branding_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float perimeter_m = 90.0;
uniform vec4 score_centers = vec4(0.0, 22.5, 45.0, 67.5);
uniform vec4 brand_centers = vec4(11.25, 33.75, 56.25, 78.75);
uniform float score_width = 7.8;
uniform float brand_width = 7.8;
uniform float brand_aspect = 3.0;

vec2 contain_uv(vec2 uv, float aspect, float width_m) {
	float bay_aspect = width_m / screen_height;
	vec2 fit = vec2(max(bay_aspect / aspect, 1.0), max(aspect / bay_aspect, 1.0));
	return (uv - 0.5) * fit + 0.5;
}
float inside_uv(vec2 uv) {
	return step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
}
void fragment() {
	vec3 color = vec3(0.014, 0.035, 0.085);
	if (zoned_content) {
		float score_delta = perimeter_m;
		float brand_delta = perimeter_m;
		for (int i = 0; i < 4; i++) {
			float s = mod(UV.x - score_centers[i] + perimeter_m * 1.5, perimeter_m) - perimeter_m * 0.5;
			float b = mod(UV.x - brand_centers[i] + perimeter_m * 1.5, perimeter_m) - perimeter_m * 0.5;
			if (abs(s) < abs(score_delta)) { score_delta = s; }
			if (abs(b) < abs(brand_delta)) { brand_delta = b; }
		}
		color = vec3(0.014, 0.035, 0.085);
		if (abs(score_delta) <= score_width * 0.5) {
			vec2 tile_uv = contain_uv(vec2(score_delta / score_width + 0.5, UV.y), content_aspect, score_width);
			color = mix(color, texture(content_texture, clamp(tile_uv, vec2(0.0), vec2(1.0))).rgb, inside_uv(tile_uv));
		} else if (abs(brand_delta) <= brand_width * 0.5) {
			vec2 tile_uv = contain_uv(vec2(brand_delta / brand_width + 0.5, UV.y), brand_aspect, brand_width);
			color = mix(color, texture(branding_texture, clamp(tile_uv, vec2(0.0), vec2(1.0))).rgb, inside_uv(tile_uv));
		}
	}
	else {
		// Retain phase-1 continuous tiling when the zone layout is disabled.
		vec2 source_uv = contain_uv(vec2(fract(UV.x / panel_pitch), UV.y), content_aspect, panel_pitch);
		color = mix(color, texture(content_texture, clamp(source_uv, vec2(0.0), vec2(1.0))).rgb, inside_uv(source_uv));
	}
	// Fine cabinet joints; no time-based animation or new light emission.
	float joint = smoothstep(0.0, 0.007, min(fract(UV.x / 0.75), 1.0 - fract(UV.x / 0.75)));
	ALBEDO = color * brightness * mix(0.87, 1.0, joint);
}
