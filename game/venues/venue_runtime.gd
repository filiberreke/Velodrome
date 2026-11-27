extends RefCounted
## Reconfigure the shared race engine before spawning a new event's riders.
const Track := preload("res://track_geometry.gd")

static func configure(game: Node, profile: Resource) -> void:
	game.venue = profile
	game.LAP = profile.lap_length_m
	game.RADIUS = profile.bend_radius_m
	game.STRAIGHT = (game.LAP - TAU * game.RADIUS) * .5
	game.TRACK_EDGE = profile.apron_width_m
	game.TRACK_OUTER_EDGE = profile.track_outer_offset_m
	game.BLUE_APRON_BANK_DEG = profile.apron_bank_deg
	game.STRAIGHT_BANK_DEG = profile.straight_bank_deg
	game.CORNER_BANK_DEG = profile.corner_bank_deg
	game.BANK_TRANSITION_M = profile.transition_m
	game.FINISH_STRAIGHT_CLEARANCE_M = profile.finish_straight_clearance_m
	game.FINISH_REFERENCE_S = profile.transition_m * .5 + profile.finish_straight_clearance_m
	game.PURSUIT_START_M = game.LAP + game.FINISH_REFERENCE_S - game.STRAIGHT * .5
	game.NEUTRAL_DEPARTURE_M = game.FINISH_REFERENCE_S - game.STRAIGHT * .5
	game.OPPOSITE_STRAIGHT_GATE_M = fposmod(game.PURSUIT_START_M + game.LAP * .5, game.LAP)
	game.RACE_AMBIENT_LIGHT_ENERGY = profile.race_ambient_energy
	game.track_geometry = Track.new(profile)
	game.scratch_rules.LAP_M = game.LAP
	game.points_rules.LAP = game.LAP
	game.tempo_rules.LAP = game.LAP
	game.peloton_state.LAP = game.LAP
	game.x_ai.LAP = game.LAP
	game.pursuit_library.venue_id = profile.id
	game.team_library.venue_id = profile.id
	game.performance_records.venue_id = profile.id
	if is_instance_valid(game.minimap): game.minimap.TRACK_LENGTH = game.LAP
	if is_instance_valid(game.race_overlay): game.race_overlay.lap_length_m = game.LAP

static func build_custom_stadium(game: Node3D) -> void:
	var outdoor: bool = game.venue.outdoor
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("242b33")
	if outdoor:
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color("77a9c2")
		sky_material.sky_horizon_color = Color("e4ede9")
		sky_material.ground_horizon_color = sky_material.sky_horizon_color
		world.environment.sky = Sky.new()
		world.environment.sky.sky_material = sky_material
		world.environment.background_mode = Environment.BG_SKY
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("f5eddf")
	world.environment.ambient_light_energy = game.venue.race_ambient_energy
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	game.stadium_environment = world.environment
	game.add_child(world)
	game.stadium_sun = DirectionalLight3D.new()
	game.stadium_sun.light_energy = 0.0
	if outdoor:
		game.stadium_sun.rotation_degrees = Vector3(-52, -35, 0)
		game.stadium_sun.light_color = Color("fff1da")
		game.stadium_sun.light_energy = 1.10
		game.stadium_sun.shadow_enabled = true
		game.stadium_sun.directional_shadow_max_distance = 160.0
	game.add_child(game.stadium_sun)
	game.camera = Camera3D.new()
	game.camera.near = .1; game.camera.far = 420.0 if outdoor else 180.0; game.camera.fov = 72
	game.add_child(preload("res://interpolation_guard.gd").interpolate(game.camera))
	game.camera.current = true
	game.boost_dog = preload("res://boost_dog.gd").new()
	game.add_child(preload("res://interpolation_guard.gd").interpolate(game.boost_dog))
	game.countdown_label = Label3D.new()
	game.countdown_label.hide()
	game.add_child(game.countdown_label)
	game.arena = load(game.venue.arena_path).new()
	var cfg := ConfigFile.new()
	preload("res://config_paths.gd").load_user(cfg, "display_settings.cfg")
	game.arena.simple = bool(cfg.get_value("arena", "simple_infield", false))
	game.arena.density = clampf(float(cfg.get_value("arena", "crowd_density", .60)), 0.0, 1.0)
	game.add_child(game.arena)
	game.arena.build(game, game.venue, preload("res://venues/venue_track.gd").new(game.venue))
	# Pursuit gates belong to the race geometry, not to the stadium artwork.
	for start in [game.PURSUIT_START_M, game.PURSUIT_START_M + game.LAP * .5]:
		game._track_band(game.TRACK_EDGE, game.TRACK_OUTER_EDGE, Color("eeeeee"), start - .055, .11, .035)
