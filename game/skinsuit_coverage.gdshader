shader_type spatial;

// Atlas alpha is fabric coverage, not transparency of the rider mesh.
// Uncovered UVs show the existing model skin color and stay fully opaque.
uniform sampler2D skinsuit_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 skin_color : source_color = vec4(0.96, 0.72, 0.56, 1.0);
uniform float fabric_roughness : hint_range(0.0, 1.0) = 0.65;

void fragment() {
	vec4 cloth = texture(skinsuit_atlas, UV);
	ALBEDO = mix(skin_color.rgb, cloth.rgb, cloth.a);
	ROUGHNESS = fabric_roughness;
}
