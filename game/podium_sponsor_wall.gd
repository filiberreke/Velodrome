extends RefCounted
## Step-and-repeat branding uses the existing white/blue Velodrome artwork.
const BLUE: Texture2D = preload("res://assets/boarding/velodrome-boarding.png")
const WHITE: Texture2D = preload("res://assets/boarding/velodrome-boarding-licht.png")

static func build(podium: Node3D) -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D blue_logo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D white_logo : source_color, filter_linear_mipmap, repeat_disable;
void fragment() {
	vec2 grid = UV * vec2(4.0, 6.0);
	vec2 cell = floor(grid);
	bool blue = mod(cell.x + cell.y, 2.0) < 1.0;
	vec2 logo_uv = (fract(grid) - vec2(0.5)) / vec2(0.90, 0.675) + vec2(0.5);
	vec3 background = blue ? vec3(0.075, 0.20, 0.43) : vec3(0.97, 0.96, 0.93);
	bool inside = all(greaterThanEqual(logo_uv, vec2(0.0))) && all(lessThanEqual(logo_uv, vec2(1.0)));
	ALBEDO = inside ? (blue ? texture(blue_logo, logo_uv).rgb : texture(white_logo, logo_uv).rgb) : background;
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("blue_logo", BLUE)
	material.set_shader_parameter("white_logo", WHITE)
	for back in [false, true]:
		var panel := MeshInstance3D.new()
		panel.name = "SponsorachtergrondAchterkant" if back else "Sponsorachtergrond"
		var quad := QuadMesh.new()
		quad.size = Vector2(3.6, 2.4)
		panel.mesh = quad
		panel.position = Vector3(0, 1.4, -0.948 if back else -0.832)
		panel.rotation.y = PI if back else 0.0
		panel.material_override = material
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		podium.add_child(panel)
