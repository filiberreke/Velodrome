shader_type spatial;
// Helpers use the same torso/sleeve atlas coordinates as the rider's outfit.
uniform sampler2D team_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 team_color : source_color = vec4(0.15, 0.25, 0.40, 1.0);
uniform bool use_atlas = false;
void fragment() {
	vec4 cloth = texture(team_atlas, UV);
	ALBEDO = use_atlas ? mix(team_color.rgb, cloth.rgb, cloth.a) : team_color.rgb;
	ROUGHNESS = 0.76;
}
