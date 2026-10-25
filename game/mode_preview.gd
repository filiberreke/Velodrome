extends RefCounted
## One-shot 3D postcards built from the actual game rider rig and track textures.
const Rider := preload("res://rider_visual.gd")
const Wood: Texture2D = preload("res://assets/textures/velodrome_wood_pine.png")
const Colours := ["ffab45", "43ccd4", "e86267", "8da0ff"]

static func box(world: Node3D, position: Vector3, dimensions: Vector3, colour: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.85
	node.mesh = mesh
	node.material_override = material
	node.position = position
	world.add_child(node)
	return node

static func rider(world: Node3D, position: Vector3, team: int, reverse: bool = false) -> Node3D:
	var node := Rider.new()
	node.set_meta("rider_index", team % 4)
	node.set_meta("jersey_config", {"jersey_color": Colours[team % 4], "helmet_color": Colours[team % 4], "jersey_design": "solid"})
	world.add_child(node)
	node.position = position
	node.rotation.y = PI if reverse else 0.0
	node.pedal(0.25, 90.0, 500.0)
	return node

static func make(owner_node: Node, mode: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "Spelbeeld_" + mode
	viewport.size = Vector2i(640, 300)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.msaa_3d = Viewport.MSAA_2X
	owner_node.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var sky := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("12283c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c6dded")
	environment.ambient_light_energy = 0.85
	sky.environment = environment
	world.add_child(sky)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.4
	world.add_child(light)
	var floor := box(world, Vector3(0, -0.08, 0), Vector3(17, 0.12, 18), Color.WHITE)
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = Wood
	wood.uv1_scale = Vector3(3, 3, 1)
	wood.roughness = 0.85
	floor.material_override = wood
	box(world, Vector3(-7.0, 0.0, 0), Vector3(2.0, 0.025, 18), Color("329fb9"))
	for x in [-5.5, -3.7, 4.9]:
		box(world, Vector3(x, 0.012, 0), Vector3(0.065, 0.025, 18), Color("f3ebd9") if x < -4.0 else Color("d34b50"))
	match mode:
		"scratch":
			for i in range(6):
				rider(world, Vector3(-2.4 + (i % 3) * 2.15, 0, -2.0 + (i / 3) * 3.4), i)
		"pursuit":
			rider(world, Vector3(-2.9, 0, 2.6), 0)
			rider(world, Vector3(2.9, 0, -2.6), 1, true)
		"team_pursuit":
			for i in range(4):
				rider(world, Vector3(-2.5, 0, -4.2 + 2.8 * i), 0)
				rider(world, Vector3(2.5, 0, 4.2 - 2.8 * i), 1, true)
		"points":
			box(world, Vector3(0, 0.025, 2), Vector3(13, 0.025, 0.30), Color("fff8e9"))
			for i in range(5):
				rider(world, Vector3(-3.5 + i * 1.7, 0, 2.4 - absf(i - 2.0) * 1.2), i)
		"madison":
			for i in range(4):
				rider(world, Vector3(-3.4 + i * 2.2, 0, 1.0 if i < 2 else -1.5), 0 if i < 2 else 1)
		"keirin":
			var pacer := rider(world, Vector3(0, 0, 4.3), 3)
			# An engine under the existing bicycle frame distinguishes the pacing bike.
			box(pacer, Vector3(0, 0.48, 0.02), Vector3(0.42, 0.35, 0.6), Color("414954"))
			for i in range(5):
				rider(world, Vector3(0.5 * sin(float(i)), 0, 1.6 - i * 2.3), i)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(12, 10, 14)
	camera.look_at(Vector3(0, 0.4, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.5
	camera.current = true
	return viewport
