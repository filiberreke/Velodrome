extends SceneTree
## Production menu → event integration, tournament resume and venue isolation.
const Venues := preload("res://venues/venue_catalog.gd")
class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass
	func _ready() -> void:
		super._ready()
		set_physics_process(false)
		bridge_devices.set_process(false)
		bridge_devices.socket.close()
		bridge_devices.panel_root.hide()
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := Game.new(); root.add_child(game)
	await process_frame
	var menu = game.setup_panel
	for id in Venues.available_ids():
		for mode in [0, 1, 2, 3, 5, 6, 7, 8]:
			game._reset()
			menu.select_mode(mode)
			menu.venue_picker.tiles[id].button.pressed.emit()
			check(menu.venue_id == id, "Tile selects " + id)
			for key in menu.venue_picker.tiles:
				var tile: Dictionary = menu.venue_picker.tiles[key]
				check(tile.button.button_pressed == (key == id), "Exclusive stadium choice")
				check(is_equal_approx(float(tile.photo.material.get_shader_parameter("saturation")), 1.0 if key == id else 0.0), "Actual photo saturation follows choice")
			if mode in [1, 2]:
				menu.pursuit_flow.next_step()
				var controls: Array = []
				for row in menu.pursuit_flow._bridge_rows(): controls.append_array(row)
				for key in menu.pursuit_flow.venue_picker.tiles: check(controls.has(menu.pursuit_flow.venue_picker.tiles[key].button), "Ride controller can focus stadium tiles")
			game._confirm_start()
			check(game.venue.id == id and game.start_state in ["INTRO", "WAIT_STOP"], "%s menu mode %d starts chosen stadium" % [id, mode])
			if id == "roubaix" and mode == 0:
				check(game.arena.infield.waiting_spots.size() == 24, "Roubaix has 24 waiting places")
				check(game.arena.find_children("WaitingBay*", "Node3D", true, false).size() == 3, "Roubaix has three open bays")
				check_roubaix_infield(game.arena.infield)
				check(game.arena.find_children("Bend*Banner*", "MeshInstance3D", true, false).size() == 6, "Three ground banners per Roubaix bend")
				var suite := game.arena.get_node("EuroMaxCyclingCommentaryBox") as Node3D
				check(game.broadcast_intro.suite == suite and suite.voices.size() == 2, "Roubaix broadcast intro uses both animated commentators")
				check(suite.position.y > 5.0 and game.arena.has_node("BroadcastDeck/TVCameraGallery"), "Both broadcast positions are on the upper deck")
				var access := game.arena.get_node("RoadAccess") as Node3D
				var distance: float = access.get_meta("track_distance_m")
				check(access.has_node("ClosedRoadGate") and access.has_node("RoadApproach"), "Reserved road access stays closed during track races")
				check(access.position.distance_to(game._at(distance, game.TRACK_OUTER_EDGE)) < 0.01, "Road access meets the opposite straight at the outer edge")
			check(is_equal_approx(game.minimap.TRACK_LENGTH, game.LAP), "Minimap uses selected lap")
			if mode in [1, 2, 7]: check(is_equal_approx(game._race_length(), 1000.0), "Fixed-distance events preserve metres")
			if mode in [1, 2]:
				check(game._at(game.PURSUIT_START_M, 1.18).distance_to(-Vector3(game._at(game.PURSUIT_START_M + game.LAP * .5, 1.18).x, -game._at(game.PURSUIT_START_M + game.LAP * .5, 1.18).y, game._at(game.PURSUIT_START_M + game.LAP * .5, 1.18).z)) < .01, "Pursuit starts are opposite")
			game.broadcast_intro.finish()
			game._begin_riding()
			game._update_visuals(0.0); game._update_hud()
			check(not game._use_venue("velodrome" if id == "gent" else "gent"), "Venue cannot change during a race")
			if mode == 5: check(is_equal_approx(game.elimination_rules.interval_m, game.LAP * 2.0), "Elimination uses two actual laps")
			if id == "roubaix" and mode == 5: check_roubaix_exit(game)
			if id != "velodrome" and mode == 6: check_keirin_exit(game)
			game._restart_same_race()
			check(game.venue.id == id and game.replay_setup.venue_id == id, "Same-race restart retains stadium")
			print("VENUE_SELECTION ", id, " mode=", mode)
	game._reset()
	check(game._use_venue("velodrome"), "Switch away from previous event outside race")
	game._restart_same_race()
	check(game.venue.id == "roubaix", "Restart restores stored venue even after another stadium was loaded")
	game._reset()
	var page = menu.tournament_page
	page.manager.store.folder = "user://multiple_venue_omnium"
	page.manager.state = {"version": 1, "active": {}, "archive": []}
	page.opened = true; page.refresh()
	var selectors: Array[Node] = page.body.find_children("*", "VBoxContainer", true, false)
	var found := false
	for node in selectors:
		if node.get_script() == preload("res://venues/venue_selector.gd"):
			node.tiles.gent.button.pressed.emit(); found = true
	check(found and page.draft.venue_id == "gent", "Omnium setup offers working stadium tiles")
	check(page.draft.catalog.load_catalog(), "Omnium roster loads")
	var rng := RandomNumberGenerator.new(); rng.seed = 91
	page.draft.riders = page.draft.catalog.generate(page.player(), 8, "mixed", rng)
	page.confirm_draft()
	check(page.manager.state.active.venue_id == "gent", "Omnium stores selected venue")
	var resumed := preload("res://omnium/omnium_manager.gd").new()
	resumed.store.folder = page.manager.store.folder
	resumed.load_session(int(Time.get_unix_time_from_system()))
	check(resumed.state.active.venue_id == "gent", "Resuming omnium retains venue")
	menu.start_omnium_scratch()
	check(game.venue.id == "gent" and game.race_laps == 30, "Gent short omnium scratch keeps 5 km: thirty laps")
	check(not page.manager.update_setup(page.draft.riders, "short", 80, int(Time.get_unix_time_from_system()), "velodrome"), "Started omnium cannot change stadium")
	game._reset()
	check(game._use_venue("velodrome"), "Return to default stadium after Gent")
	check(game.arena.get_meta("venue_id") == "velodrome" and game.find_children("GentArena", "Node3D", true, false).is_empty(), "Old scenery is fully removed")
	game.free()
	await process_frame
	print("MULTIPLE_VENUE_SELECTION_OK" if failures == 0 else "MULTIPLE_VENUE_SELECTION_FAILED %d" % failures)
	quit(0 if failures == 0 else 1)

func check_roubaix_exit(game: Game) -> void:
	var rider := 1
	var gate: float = fposmod(game.arena.infield.gate_distance, game.LAP)
	var target: Vector3 = game._elimination_box_target(rider)
	game.lane_offsets[rider] = game.LANES[0]
	game.coast_distances[rider] = gate - 0.5
	game.coast_speeds[rider] = 5.0
	game.elimination_exit[rider] = {"stage": 0, "start_d": gate - 80.0, "target": target, "gate_z": 0.0}
	for step in 270:
		game._update_eliminated_exit(rider, 0.1)
	var route: Dictionary = game.elimination_exit[rider]
	check(route.stage == 5 and Vector3(route.position).distance_to(target) < 0.12, "Roubaix elimination riders cross to their assigned bay")

func check_roubaix_infield(infield: Node3D) -> void:
	check(infield.has_node("TechnicalZone") and infield.has_node("RiderBayBypass"), "Cyclist technical zone and infield bypass are present")
	for name_text in ["SpectatorNorth", "SpectatorSouth", "OperationsWorkZone", "MediaWorkZone"]:
		var zone := infield.get_node_or_null(name_text) as Node3D
		check(zone != null, "Roubaix infield has " + name_text)
		if zone == null: continue
		var footprint: Vector2 = zone.get_meta("footprint_m")
		check(absf(zone.position.x) - footprint.x * 0.5 > 2.5, "Zone leaves the main passage open")
		check(absf(zone.position.z - 51.0) - footprint.y * 0.5 >= 2.5, "Zone leaves the cross passage open")
		var gate := zone.get_node_or_null("GateOpening") as Marker3D
		check(gate != null and is_equal_approx(gate.position.x, -signf(zone.position.x) * footprint.x * 0.5), "Zone gate opens onto the grass passage")

func check_keirin_exit(game: Game) -> void:
	var rider := 0
	var gate := game._race_exit_distance()
	var target := game._elimination_box_target(rider)
	game.lane_offsets[rider] = game.keirin.SAFETY_LANE
	game.coast_distances[rider] = gate - 0.25
	game.coast_speeds[rider] = 4.0
	game.elimination_exit[rider] = {"stage": 0, "elapsed": 4.0, "target": target}
	for step in 220: game.keirin.update_finish_exit(game, rider, 0.1)
	var route: Dictionary = game.elimination_exit[rider]
	var waypoints: PackedVector3Array = route.get("waypoints", PackedVector3Array())
	check(not waypoints.is_empty() and route.stage == waypoints.size() + 1 and Vector3(route.position).distance_to(target) < 0.05, "Keirin finishes through the correct venue gate and reaches the waiting place")
