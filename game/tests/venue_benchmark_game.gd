extends "res://main.gd"
## Production scenery, with a fixed shared rider fixture and no race/IO/HUD.
var benchmark_simple := false
var benchmark_track: RefCounted
var benchmark_riders: Array[Node3D] = []

func _ready() -> void:
	benchmark_track = preload("res://venues/venue_track.gd").new(venue)
	LAP = venue.lap_length_m
	race_mode = 3
	race_laps = 40
	rider_count = 12
	start_state = "RACING"
	distances.resize(12); distances.fill(0.0)
	speeds.resize(12); speeds.fill(13.0)
	finish_times.resize(12); finish_times.fill(-1.0)
	lap_times.clear()
	for i in 12: lap_times.append([])
	if venue.id == "gent":
		# Identical lighting/environment to the current Gent design preview.
		var world := WorldEnvironment.new()
		world.environment = Environment.new()
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color("242b33")
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color("f5eddf")
		world.environment.ambient_light_energy = .58
		world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		add_child(world)
		arena = preload("res://venues/gent/gent_arena.gd").new()
		arena.simple = benchmark_simple
		arena.density = .60
		add_child(arena)
		arena.build(self, venue, benchmark_track)
		camera = Camera3D.new()
		add_child(camera)
	else:
		_build_world()
		boost_dog.queue_free()
		arena = preload("res://arena.gd").new()
		add_child(arena)
		_set_stadium_training_lighting(false)
	camera.near = .10
	camera.far = 220.0
	camera.current = true
	for i in 12:
		var rider := preload("res://rider_visual.gd").new()
		rider.set_meta("rider_index", i % 4)
		rider.set_meta("country_kit", ["belgium", "netherlands", "france", "italy"][i % 4])
		add_child(rider)
		benchmark_riders.append(rider)
		# Same 3 m spacing, three lanes; fixed placement removes lap/view bias.
		var s := 8.0 + float(i) * 3.0
		var offset := 1.15 + float(i % 3) * .73
		distances[i] = s
		rider.position = benchmark_track.at(s, offset)
		var forward: Vector3 = benchmark_track.direction(s, offset)
		rider.rotation = Vector3(0, atan2(forward.x, forward.z), -benchmark_track.bank(s) * benchmark_track.geometry.bend(benchmark_track.phase(s)) * .84)
	set_physics_process(false)
	set_benchmark_view("overview")

func _at(s: float, offset: float) -> Vector3:
	return benchmark_track.at(s, offset)

func _physics_process(_delta: float) -> void:
	pass

func _process(delta: float) -> void:
	for rider in benchmark_riders: rider.pedal(delta, 92.0, 290.0)

func set_benchmark_view(view: String) -> void:
	if view == "overview":
		# Same framing relative to each oval's radius and half-length.
		var extent_x := 0.0
		var extent_z := 0.0
		for i in 360:
			var p: Vector3 = benchmark_track.at(LAP * float(i) / 360.0, 0.0)
			extent_x = maxf(extent_x, absf(p.x))
			extent_z = maxf(extent_z, absf(p.z))
		# Keep the camera below Vélodrome's sloping canopy and inside Gent's wall.
		camera.position = Vector3(extent_x * .78, minf(14.0, extent_z * .345), -extent_z * 1.15)
		camera.look_at(Vector3(-extent_x * .375, 1.0, -extent_z * .215))
		camera.fov = 68.0
	else:
		var p: Vector3 = benchmark_track.at(0.0, 2.0)
		var direction: Vector3 = benchmark_track.direction(0.0, 2.0)
		camera.position = p - direction * 14.0 + Vector3.UP * 2.2
		camera.look_at(benchmark_track.at(20.0, 2.0) + Vector3.UP * .7)
		camera.fov = 72.0
