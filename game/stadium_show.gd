extends Node3D
## Lightweight race-day spectacle: national flags and a travelling stand wave.
## All spectator geometry and density remain untouched.
const LAP := 250.0
const FLAGS := [
	["belgium", Color("#171717"), Color("#f5d32d"), Color("#dc2738")],
	["netherlands", Color("#c52d35"), Color.WHITE, Color("#194c95")],
	["france", Color("#194990"), Color.WHITE, Color("#d9313d")],
	["italy", Color("#168954"), Color.WHITE, Color("#d62e38")],
	["germany", Color("#111111"), Color("#d13237"), Color("#efc22f")],
	["denmark", Color("#bd1a2e"), Color.WHITE, Color("#bd1a2e")],
	["great_britain", Color("#223d88"), Color.WHITE, Color("#d62840")],
	["portugal", Color("#158347"), Color("#ce2435"), Color("#ce2435")],
	["australia", Color("#17428b"), Color.WHITE, Color("#c9263c")],
	["new_zealand", Color("#122a63"), Color.WHITE, Color("#ca2944")],
	["united_states", Color("#c52940"), Color.WHITE, Color("#204786")]
]
var arena: Node3D
var game: Node3D
var flag_materials: Array[ShaderMaterial] = []
var wave_material: ShaderMaterial
var excitement := 0.1
var lead_s := 0.0

func _ready() -> void:
	arena = get_parent() as Node3D
	game = arena.get_parent() as Node3D
	_make_flags()
	_make_wave()

func _stadium(s: float, off: float, h: float) -> Vector3:
	return arena._stadium_point(s, off, h)

func _flag_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var id := PackedInt32Array()
	# Flags wave around a stationary mast, using two sided cloth.
	for y in range(5):
		for x in range(9):
			v.append(Vector3(float(x) / 8.0 * 0.48, 0.27 + float(y) / 4.0 * 0.31, 0.0))
			uv.append(Vector2(float(x) / 8.0, float(y) / 4.0))
	for y in range(4):
		for x in range(8):
			var a := y * 9 + x
			id.append_array(PackedInt32Array([a,a+1,a+9,a+1,a+10,a+9]))
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_TEX_UV] = uv
	a[Mesh.ARRAY_INDEX] = id
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	return m

func _make_flags() -> void:
	var mesh := _flag_mesh()
	var sticks: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 250301
	var countries: Array = []
	for i in FLAGS.size():
		countries.append([])
	var tier_specs := [[11.0, 7, 1.10, 0.88, 0.40], [20.6, 8, 1.17, 5.15, 0.47], [32.4, 7, 1.27, 11.20, 0.55]]
	for tier in 2:
		var spec: Array = tier_specs[tier]
		for s_index in 200:
			var s := (float(s_index) + rng.randf_range(-0.2,0.2)) * LAP / 200.0
			if rng.randf() > 0.30:
				continue
			var row := rng.randi_range(0, int(spec[1])-1)
			var off := float(spec[0]) + row * float(spec[2])
			var height := float(spec[3]) + row * float(spec[4])
			if arena._aisle(s):
				continue
			var foot := _stadium(s,off,height + 1.15)
			var basis: Basis = arena._seat_basis(s)
			basis = Basis(basis.x, Vector3.UP, -basis.z)
			basis = basis.rotated(Vector3.UP,rng.randf_range(-0.40,0.40))
			var country := rng.randi_range(0, FLAGS.size()-1)
			countries[country].append(Transform3D(basis,foot))
			sticks.append(Transform3D(basis,foot + Vector3.UP * 0.25))
	# One instanced thin mast per flag, matching the fabric orientation.
	if not sticks.is_empty():
		var pole_mesh := BoxMesh.new()
		pole_mesh.size = Vector3(0.015, 0.69, 0.015)
		var poles := MultiMesh.new()
		poles.transform_format = MultiMesh.TRANSFORM_3D
		poles.mesh = pole_mesh
		poles.instance_count = sticks.size()
		for i in sticks.size():
			poles.set_instance_transform(i, sticks[i])
		var pole_node := MultiMeshInstance3D.new()
		pole_node.name = "SupportersVlaggenstokken"
		pole_node.multimesh = poles
		var pole_material := StandardMaterial3D.new()
		pole_material.albedo_color = Color("#c1bbc0")
		pole_material.metallic = 0.65
		pole_node.material_override = pole_material
		pole_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pole_node)
	var flag_shader := Shader.new()
	flag_shader.code = """shader_type spatial;
render_mode cull_disabled, diffuse_lambert;
uniform vec4 stripe_a : source_color;
uniform vec4 stripe_b : source_color;
uniform vec4 stripe_c : source_color;
uniform float excitement = 0.0;
uniform int flag_type = 0;
void vertex() {
	float seed = fract(sin(float(INSTANCE_ID)*12.981)*43758.55);
	float anim = TIME*(1.6+excitement*5.0)+seed*6.28;
	VERTEX.z += sin(anim + UV.x*6.5)*UV.x*(0.035 + excitement*0.085);
	VERTEX.y += sin(anim*0.8 + UV.x*5.0)*UV.x*excitement*0.08;
}
void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	vec3 color = uv.x < 0.34 ? stripe_a.rgb : (uv.x < 0.67 ? stripe_b.rgb : stripe_c.rgb);
	bool horizontal = flag_type == 1 || flag_type == 4 || flag_type == 7;
	if (horizontal) color = uv.y < 0.34 ? stripe_a.rgb : (uv.y < 0.67 ? stripe_b.rgb : stripe_c.rgb);
	if (flag_type == 5) { // Denmark: red and white Nordic cross
		color = stripe_a.rgb;
		if (abs(uv.x - 0.36) < 0.075 || abs(uv.y - 0.50) < 0.10) color = vec3(1.0);
	}
	if (flag_type == 6) { // Great Britain: simplified Union Jack
		color = vec3(0.08,0.18,0.48);
		float diag_a = abs(uv.y - uv.x);
		float diag_b = abs(uv.y - (1.0-uv.x));
		if (diag_a < 0.11 || diag_b < 0.11) color = vec3(1.0);
		if (diag_a < 0.045 || diag_b < 0.045) color = vec3(0.80,0.07,0.16);
		if (abs(uv.x-0.5) < 0.11 || abs(uv.y-0.5) < 0.15) color = vec3(1.0);
		if (abs(uv.x-0.5) < 0.055 || abs(uv.y-0.5) < 0.085) color = vec3(0.80,0.07,0.16);
	}
	if (flag_type == 7) { // Portugal: green hoist, red fly
		color = uv.x < 0.40 ? stripe_a.rgb : stripe_b.rgb;
		float seal = length((uv-vec2(0.40,0.5))*vec2(1.0,1.4));
		if (seal < 0.11) color = vec3(0.96,0.80,0.23);
		if (seal < 0.064) color = vec3(1.0);
	}
	if (flag_type == 8 || flag_type == 9) { // Australia / New Zealand
		color = vec3(0.035,0.11,0.34);
		if (uv.x < 0.48 && uv.y < 0.48) {
			vec2 corner = uv / vec2(0.48);
			if (abs(corner.x-corner.y)<0.13 || abs(corner.x+corner.y-1.0)<0.13) color=vec3(1.0);
			if (abs(corner.x-0.5)<0.10 || abs(corner.y-0.5)<0.13) color=vec3(1.0);
			if (abs(corner.x-0.5)<0.055 || abs(corner.y-0.5)<0.075) color=vec3(0.80,0.05,0.13);
		}
		vec2 star = fract(uv*vec2(4.0,3.0))-0.5;
		float sparkle = min(abs(star.x), abs(star.y));
		if (uv.x > 0.54 && sparkle < 0.055 && length(star)<0.17)
			color = flag_type == 8 ? vec3(1.0) : vec3(0.88,0.10,0.20);
	}
	if (flag_type == 10) { // United States: thirteen stripes and canton
		color = mod(floor(uv.y * 13.0),2.0)<1.0 ? vec3(0.76,0.05,0.12) : vec3(1.0);
		if (uv.x < 0.45 && uv.y < 0.55) {
			color=vec3(0.06,0.15,0.43);
			vec2 stars=abs(fract(uv*vec2(17.0,14.0))-0.5);
			if (max(stars.x,stars.y)<0.08) color=vec3(1.0);
		}
	}
	ALBEDO = color;
	ROUGHNESS = 0.88;
}"""
	for country in FLAGS.size():
		if countries[country].is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = countries[country].size()
		for i in countries[country].size():
			mm.set_instance_transform(i,countries[country][i])
		var node := MultiMeshInstance3D.new()
		node.name = "Supportersvlaggen_" + String(FLAGS[country][0])
		node.multimesh = mm
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = flag_shader
		shader_mat.set_shader_parameter("flag_type",country)
		shader_mat.set_shader_parameter("stripe_a",FLAGS[country][1])
		shader_mat.set_shader_parameter("stripe_b",FLAGS[country][2])
		shader_mat.set_shader_parameter("stripe_c",FLAGS[country][3])
		node.material_override = shader_mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flag_materials.append(shader_mat)
		add_child(node)

func _make_wave() -> void:
	# Existing instanced crowd keeps its meshes; wave is propagated as a shader parameter.
	wave_material = arena.crowd.material

func _process(delta: float) -> void:
	if game == null:
		return
	var state := String(game.get("start_state"))
	var distances = game.get("distances")
	var lead := 0.0
	if distances is Array:
		for d in distances:
			lead = maxf(lead, float(d))
	lead_s = fposmod(lead,LAP)
	var final_lap := false
	if state == "RACING":
		final_lap = lead >= float(game.get("race_laps")) * LAP - LAP
	var target := 0.10
	if final_lap:
		target = 0.85
	elif state == "RACING":
		target = 0.25
	if bool(game.get("finished")):
		target = 0.95 if float(game.get("finish_elapsed")) < 7.0 else 0.2
	excitement = move_toward(excitement,target,delta*1.3)
	for material in flag_materials:
		material.set_shader_parameter("excitement",excitement)
	if wave_material:
		var front: Vector3 = arena._point(lead_s, 0.0)
		var angular_phase := atan2(front.z,front.x) / TAU + 0.5
		wave_material.set_shader_parameter("wave_center",angular_phase)
		wave_material.set_shader_parameter("wave_strength",0.7 if final_lap else excitement*0.38)
