extends Node3D
## Real moving spots plus visible beam meshes for the GL Compatibility renderer.
var game: Node3D
var spots: Array[SpotLight3D] = []
var beams: Array[MeshInstance3D] = []
var saved_lights: Array[Dictionary] = []
var environment: Environment
var ambient := 0.7
var running := false

func setup(owner_game: Node3D) -> void:
	game = owner_game
	name = "IntroLichtshow"
	game.add_child(self)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 beam_color : source_color;
uniform float strength = 1.0;
void fragment() {
	float edge = pow(max(0.0, 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)))), 0.75);
	ALBEDO = beam_color.rgb;
	ALPHA = strength * 0.20 * edge * (1.0 - smoothstep(0.15, 1.0, UV.y));
}"""
	for i in range(6):
		var spot := SpotLight3D.new()
		spot.position = Vector3(-24.0 if i % 2 == 0 else 24.0, 21.0, -40.0 + float(i / 2) * 40.0)
		spot.spot_range = 95.0
		spot.spot_angle = 8.0
		spot.spot_attenuation = 0.55
		spot.light_color = Color("67ddff") if i % 2 == 0 else Color("ffcb7a")
		spot.light_energy = 4.0
		spot.shadow_enabled = false
		add_child(spot)
		spots.append(spot)
		var beam := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.08
		cone.bottom_radius = 1.0
		cone.height = 1.0
		cone.radial_segments = 24
		cone.cap_top = false
		cone.cap_bottom = false
		beam.mesh = cone
		beam.rotation.x = PI * 0.5
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("beam_color", spot.light_color)
		beam.material_override = material
		spot.add_child(beam)
		beams.append(beam)
	hide()

func start() -> void:
	if running: return
	saved_lights.clear()
	for node in game.find_children("*", "Light3D", true, false):
		if is_ancestor_of(node): continue
		saved_lights.append({"node": node, "energy": node.light_energy, "visible": node.visible})
	for node in game.find_children("*", "WorldEnvironment", true, false):
		environment = node.environment
		if environment != null:
			ambient = environment.ambient_light_energy
			break
	running = true
	show()
	update_show(0.0, 18.0, Vector3.ZERO)

func update_show(seconds: float, duration: float, focus: Vector3) -> void:
	if not running: return
	# Normal light returns smoothly before handing control to the player.
	var restore := smoothstep(duration - 2.5, duration, seconds)
	var show_strength := 1.0 - restore
	if environment != null: environment.ambient_light_energy = ambient * lerpf(0.28, 1.0, restore)
	for saved in saved_lights:
		var light: Light3D = saved.node
		if not is_instance_valid(light): continue
		# Booth practicals keep faces readable. Suppress existing race spots to
		# reserve the Compatibility renderer's per-mesh light budget for the show.
		if light.name == "CabinPractical": continue
		light.light_energy = float(saved.energy) * lerpf(0.22, 1.0, restore)
		if light is SpotLight3D: light.visible = bool(saved.visible) and restore > 0.0
	for i in range(spots.size()):
		var light := spots[i]
		var angle := seconds * 0.72 + float(i) * TAU / 6.0
		var sweep := Vector3(sin(angle) * 16.0, 0.6, cos(angle * 0.8) * 34.0)
		var reveal := smoothstep(duration - 5.0, duration - 2.5, seconds)
		var target := sweep.lerp(focus, reveal)
		if i == 0: target = focus
		light.look_at(target)
		light.light_energy = (3.8 + sin(seconds * 1.8 + i) * 0.6) * show_strength
		var length := light.global_position.distance_to(target)
		var radius := tan(deg_to_rad(light.spot_angle)) * length
		beams[i].position.z = -length * 0.5
		beams[i].scale = Vector3(radius, length, radius)
		beams[i].material_override.set_shader_parameter("strength", show_strength)

func stop() -> void:
	if not running: return
	for saved in saved_lights:
		if is_instance_valid(saved.node):
			saved.node.light_energy = saved.energy
			saved.node.visible = saved.visible
	if environment != null: environment.ambient_light_energy = ambient
	saved_lights.clear()
	running = false
	hide()
