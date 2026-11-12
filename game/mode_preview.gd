extends RefCounted
## One-shot 3D postcards built from the actual game rider rig and track textures.
const Rider := preload("res://rider_visual.gd")
const Wood: Texture2D = preload("res://assets/textures/velodrome_wood_pine.png")
static var filtered_wood: ImageTexture
const COUNTRIES := ["belgium", "italy", "netherlands", "france", "germany", "denmark"]
# Same safety-strip colour as infield_details.gd::_build_floor.
const SAFE_ZONE := Color("969b9e")
# Crossfall is rise/run (12%), not an angle of 12 degrees.
const TRACK_GRADIENT := 0.12
# Imported bike: trailing edge is 0.564 m behind the model origin.
const REAR_EDGE_Z := -0.564
const ELIMINATION_FINISH_Z := 0.0

static func track_height(world: Node3D, x: float) -> float:
	var run := maxf(absf(x) - 1.0, 0.0) if bool(world.get_meta("pursuit_mode", false)) else maxf(x + 6.2, 0.0)
	return run * TRACK_GRADIENT

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
	if world.has_meta("pursuit_mode") and not world.has_meta("preview_rider"):
		# Each surface occupies one straight slope or the flat safe-zone.
		# Shear only track geometry: keep plan widths and vertical thickness.
		var slope := 0.0
		if bool(world.get_meta("pursuit_mode")):
			if absf(position.x) > 1.0: slope = signf(position.x) * TRACK_GRADIENT
		elif position.x > -6.2:
			slope = TRACK_GRADIENT
		node.basis = Basis(Vector3(1, slope, 0), Vector3.UP, Vector3.BACK)
		node.position.y += track_height(world, position.x)
	world.add_child(node)
	return node

static func rider(world: Node3D, position: Vector3, team: int, reverse: bool = true) -> Node3D:
	var node := Rider.new()
	# Set before add_child: _ready selects the actual pursuit GLB.
	node.set_meta("pursuit_mode", bool(world.get_meta("pursuit_mode", false)))
	node.set_meta("rider_index", team % 4)
	node.set_meta("jersey_config", {"country_kit": COUNTRIES[posmod(team, COUNTRIES.size())]})
	node.set_meta("preview_rider", true)
	world.add_child(node)
	node.position = position
	# Lift the rig onto the surface, without inheriting its crossfall.
	node.position.y += track_height(world, position.x)
	node.rotation.y = PI if reverse else 0.0
	node.pedal(0.18 + posmod(team, 4) * 0.07, 90.0, 500.0)
	return node

static func make(owner_node: Node, mode: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "Spelbeeld_" + mode
	viewport.size = Vector2i(640, 420)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.msaa_3d = Viewport.MSAA_2X
	owner_node.add_child(viewport)
	var world := Node3D.new()
	var pursuit := mode in ["pursuit", "team_pursuit"]
	world.set_meta("pursuit_mode", pursuit)
	viewport.add_child(world)
	var sky := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("e0edf5")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c6dded")
	environment.ambient_light_energy = 0.85
	sky.environment = environment
	world.add_child(sky)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.4
	world.add_child(light)
	var wood := StandardMaterial3D.new()
	# The shared game texture is imported without mipmaps. Build a preview-only
	# copy to prevent fine plank grain aliasing at the banked camera angle.
	if filtered_wood == null:
		var image := Wood.get_image()
		if image.is_compressed(): image.decompress()
		image.generate_mipmaps()
		filtered_wood = ImageTexture.create_from_image(image)
	wood.albedo_texture = filtered_wood
	wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	wood.uv1_scale = Vector3(3, 3, 1)
	wood.roughness = 0.85
	# Separate wood from blue and safe-zone so their shared edges stay flush.
	if pursuit:
		for side in [-1.0, 1.0]:
			var floor := box(world, Vector3(side * 5.15, -0.06, 0), Vector3(6.7, 0.12, 18), Color.WHITE)
			floor.material_override = wood
	else:
		var floor := box(world, Vector3(1.75, -0.06, 0), Vector3(13.5, 0.12, 18), Color.WHITE)
		floor.material_override = wood
	if pursuit:
		# Opposite straights, separated by the infield. Both ride anticlockwise:
		# +X straight faces -Z; -X straight faces +Z. Blue is on each rider's left.
		box(world, Vector3(0, -0.0125, 0), Vector3(2.0, 0.025, 18), SAFE_ZONE)
		for side in [-1.0, 1.0]:
			box(world, Vector3(side * 1.4, -0.0125, 0), Vector3(0.8, 0.025, 18), Color("329fb9"))
			box(world, Vector3(side * 1.98, 0.012, 0), Vector3(0.045, 0.025, 18), Color("18202a"))
			box(world, Vector3(side * 2.7, 0.012, 0), Vector3(0.055, 0.025, 18), Color("d34b50"))
			box(world, Vector3(side * 4.0, 0.012, 0), Vector3(0.055, 0.025, 18), Color("329fb9"))
			box(world, Vector3(side * 4.6, 0.025, 0), Vector3(5.5, 0.025, 0.20), Color("fff8e9"))
	else:
		# GLBs face +Z. A half turn makes forward -Z and rider-left -X.
		box(world, Vector3(-7.35, -0.0125, 0), Vector3(2.3, 0.025, 18), SAFE_ZONE)
		box(world, Vector3(-5.6, -0.0125, 0), Vector3(1.2, 0.025, 18), Color("329fb9"))
		for x in [-4.8, -3.7, 4.9]:
			box(world, Vector3(x, 0.012, 0), Vector3(0.065, 0.025, 18), Color("18202a") if x < -4.0 else (Color("d34b50") if x < 0 else Color("329fb9")))
	match mode:
		"free_training":
			for i in range(4):
				var pacer := rider(world,Vector3(-3+i*2.0,0,-2.4+i*1.5),i)
				pacer.set_training_colour(preload("res://free_training_pacers.gd").COLOURS[i])
		"flying_training":
			box(world,Vector3(.75,.025,1.5),Vector3(11.5,.025,.20),Color("bb262b"))
			rider(world,Vector3(1.2,0,1.1),0)
		"derny_training":
			var motor := preload("res://derny_visual.gd").new(); world.add_child(motor)
			motor.position = Vector3(0,track_height(world,0),-2.3); motor.rotation.y = PI
			rider(world,Vector3(0,0,1.5),0)
		"scratch":
			for i in range(6):
				rider(world, Vector3(-2.4 + (i % 3) * 2.15, 0, -2.0 + (i / 3) * 3.4), i)
		"pursuit":
			rider(world, Vector3(3.1, 0, 0.7), 0)
			rider(world, Vector3(-3.1, 0, -0.7), 1, false)
		"team_pursuit":
			for i in range(4):
				rider(world, Vector3(3.1, 0, -3.3 + 2.2 * i), 0)
				rider(world, Vector3(-3.1, 0, 3.3 - 2.2 * i), 1, false)
		"points":
			box(world, Vector3(0.75, 0.025, 2), Vector3(11.5, 0.025, 0.30), Color("fff8e9"))
			for i in range(5):
				rider(world, Vector3(-3.5 + i * 1.7, 0, 2.4 - absf(i - 2.0) * 1.2), i)
		"madison":
			for i in range(4):
				rider(world, Vector3(-3.4 + i * 2.2, 0, 1.0 if i < 2 else -1.5), 0 if i < 2 else 1)
		"elimination":
			# Look from behind: all six riders have crossed; the last rear tyre
			# has only just cleared the narrow black finish mark.
			box(world, Vector3(0.75, 0.025, ELIMINATION_FINISH_Z), Vector3(11.5, 0.025, 0.42), Color("fff8e9"))
			var finish:=box(world, Vector3(0.75, 0.043, ELIMINATION_FINISH_Z), Vector3(11.5, 0.012, 0.035), Color("18202a"))
			finish.name="EliminationFinishLine"
			var positions:=[Vector3(-2.5,0,-5.4),Vector3(-0.3,0,-5.8),Vector3(2.2,0,-5.1),Vector3(-1.5,0,-3.0),Vector3(1.3,0,-2.8),Vector3(0.1,0,REAR_EDGE_Z-0.025)]
			for i in positions.size():
				var cyclist:=rider(world,positions[i],i,true);cyclist.name="EliminationRider%d"%i
		"time_trial":
			rider(world, Vector3(0, 0, 1.2), 0)
		"tempo":
			rider(world, Vector3(-2, 0, -4.6), 2)
			for i in range(5):
				rider(world, Vector3(-2.4 + (i % 3) * 2.0, 0, -2 + (i / 3) * 2.4), i)
		"keirin":
			var pacer := rider(world, Vector3(0, 0, -5.3), 3)
			# An engine under the existing bicycle frame distinguishes the pacing bike.
			box(pacer, Vector3(0, 0.48, 0.02), Vector3(0.42, 0.35, 0.6), Color("414954"))
			for i in range(5):
				rider(world, Vector3(0.5 * sin(float(i)), 0, -3.0 + i * 2.3), i)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(9, 4.2, 11)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.5
	camera.current = true
	return viewport
