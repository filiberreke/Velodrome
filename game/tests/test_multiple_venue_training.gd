extends SceneTree

const Venues := preload("res://venues/venue_catalog.gd")
const Navigation := preload("res://ride_navigation.gd")

class Game extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error: return super._bind_bridge(0)
	func _save_recording(_reason: String) -> void: pass

var failures := 0
var sample_id := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: return
	failures += 1
	push_error(message)

func feed_power(game: Game) -> void:
	sample_id += 1
	game._process_bridge_packet({"type": "telemetry", "valid": true, "power_w": 180.0, "speed_kmh": 30.0,
		"cadence_rpm": 86.0, "sample_id": sample_id, "power_sample_id": sample_id, "power_age_s": 0.0})

func pick(page: VBoxContainer, id: String) -> void:
	for control in Navigation.controls(page):
		if control.name == "Venue_" + id:
			control.pressed.emit()
			return
	check(false, "Venue tile is visible and focusable in " + page.name)

func check_training(game: Game, scene: Node3D, id: String, label: String) -> void:
	check(is_instance_valid(scene) and scene.active and game.venue.id == id, "%s starts in %s" % [label, id])
	check(is_equal_approx(game.LAP, Venues.find(id).lap_length_m), label + " uses the selected lap length")
	if is_instance_valid(scene):
		check(scene.prepared_venue_id == id, label + " refreshes the reusable training scenery")
		check(game.camera.is_inside_tree(), label + " has a live venue camera")

func run() -> void:
	root.size = Vector2i(1920, 1080)
	var game := Game.new()
	root.add_child(game)
	game.set_physics_process(false)
	game.bridge_devices.set_process(false)
	game.bridge_devices.socket.close()
	var menu = game.setup_panel
	menu.training_store.folder = "user://venue_training_archive"
	menu.workout_library.folder = "user://venue_training_workouts"
	var workout_id: String = menu.workout_library.save_workout("venue-workout", "Venue test", [{"kind": "FreeRide", "duration": 60.0, "events": []}])
	menu.ftp_page.set_process(false)
	menu.workout_play_page.set_process(false)
	await process_frame

	for id in ["gent", "roubaix", "velodrome"]:
		game.trainer_seen = false
		menu.show_derny()
		await process_frame
		pick(menu.derny_page, id)
		menu.derny_page.begin()
		check_training(game, game.piste_training, id, "Derny")
		var derny = game.derny_training_environment
		if is_instance_valid(derny):
			check(is_equal_approx(derny.session.LAP, game.LAP), "Derny run-up takes a full venue lap")
			check(derny.motor.planned_venue_id == id, "Derny power calibration refreshes after switching")
			check(derny.activity.venue_id == id, "Derny saves the venue")
		menu.derny_page.leave()

		for kind in ["free_ride", "flying_start", "take_lap"]:
			menu.show_piste_exercise(kind)
			await process_frame
			pick(menu.exercise_page, id)
			menu.exercise_page.begin()
			check_training(game, game.piste_training, id, kind)
			var scene = game.exercise_training_environment
			if is_instance_valid(scene):
				scene.hud.update_training(scene)
				check(is_equal_approx(scene.hud.map.TRACK_LENGTH, game.LAP), kind + " map uses the venue")
				check(is_equal_approx(scene.hud.mission_bar.max_value, game.LAP), kind + " progress uses the venue")
				check(scene.activity.venue_id == id, kind + " saves the venue")
			menu.exercise_page.leave()

		menu.show_madison_training()
		await process_frame
		pick(menu.madison_page, id)
		menu.madison_page.begin()
		check_training(game, game.piste_training, id, "Madison exchange")
		if is_instance_valid(game.madison_training_environment):
			check(is_equal_approx(game.madison_training_environment.madison.lap_length_m, game.LAP), "Madison spacing uses the full venue lap")
		menu.madison_page.leave()

		for twenty in [false, true]:
			if twenty: menu.show_ftp_twenty()
			else: menu.show_ftp()
			await process_frame
			pick(menu.ftp_page, id)
			feed_power(game)
			menu.ftp_page.begin()
			check_training(game, game.training_environment, id, "20-minute FTP" if twenty else "FTP ramp")
			check(menu.ftp_page.activity_venue.get("venue_id") == id, "FTP stores the chosen location")
			menu.ftp_page.leave()

		menu.show_workout(workout_id)
		await process_frame
		pick(menu.workout_play_page, id)
		feed_power(game)
		menu.workout_play_page.begin()
		check_training(game, game.training_environment, id, "ERG workout")
		check(menu.workout_play_page.activity_venue.get("venue_id") == id, "Workout stores the chosen location")
		menu.workout_play_page.leave()
		print("VENUE_TRAINING ", id)

	game.trainer_seen = false
	var tournament = menu.tournament_page
	var manager = tournament.manager
	manager.store.folder = "user://venue_training_omnium"
	var catalog := preload("res://omnium/omnium_catalog.gd").new()
	check(catalog.load_catalog(), "Omnium roster is available")
	var rng := RandomNumberGenerator.new()
	rng.seed = 81
	var roster := catalog.generate(tournament.player(), 8, "mixed", rng)
	for id in Venues.available_ids():
		manager.state = {"version": 1, "active": {}, "archive": []}
		check(manager.create(roster, "short", 80, int(Time.get_unix_time_from_system()), id), "Omnium accepts " + id)
		menu.select_venue("roubaix" if id == "velodrome" else "velodrome")
		menu.start_omnium_warmup()
		check_training(game, game.piste_training, id, "Omnium warmup")
		check(game.exercise_training_environment.activity.get("omnium_id") == manager.state.active.get("id"), "Warmup is saved under its omnium")
		menu.exercise_page.leave()
		await process_frame

	game.free()
	await process_frame
	print("MULTIPLE_VENUE_TRAINING failures=", failures)
	quit(0 if failures == 0 else 1)
