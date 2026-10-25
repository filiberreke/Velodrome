shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D poster : source_color, filter_linear_mipmap, repeat_disable;
uniform bool match_blue = false;
uniform vec4 shared_blue : source_color = vec4(0.1098, 0.2941, 0.5686, 1.0);

void fragment() {
	vec3 color = texture(poster, UV).rgb;
	if (match_blue) {
		// The supplied backgrounds are blue; white and orange artwork stays intact.
		float blue_background = smoothstep(0.02, 0.06, color.b - max(color.r, color.g));
		// A vivid blue can have a bright B channel too. Protect neutral white
		// by its darkest channel, rather than leaving bright blue uncorrected.
		blue_background *= 1.0 - smoothstep(0.4, 0.75, min(color.r, min(color.g, color.b)));
		color = mix(color, shared_blue.rgb, blue_background);
	}
	ALBEDO = color;
}
