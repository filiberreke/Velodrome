extends SceneTree
class IntroGame extends "res://main.gd":
	func _bind_bridge(_port: int = UDP_PORT) -> Error:
		return super._bind_bridge(0)
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	# Exercise persisted settings without leaving changes in the player's files.
	var saved_preferences: Dictionary = {}
	for path in ["user://config/display_settings.cfg", "user://config/rider_profile.cfg", "user://config/player_appearance.cfg"]:
		saved_preferences[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	var defaults := ConfigFile.new()
	defaults.load("user://config/display_settings.cfg")
	if defaults.has_section_key("presentation", "always_show_intro"): defaults.erase_section_key("presentation", "always_show_intro")
	defaults.save("user://config/display_settings.cfg")
	for scenario in [[0, 3], [1, 3], [2, 3], [2, 4]]:
		var choice: int = scenario[0]
		var game := IntroGame.new()
		root.add_child(game)
		game.set_physics_process(false)
		await process_frame
		game.setup_panel.select_mode(choice)
		if choice == 2: game.setup_panel.team_options.teammates.select(scenario[1] - 3)
		if game.setup_panel.pursuit_flow.visible: game.setup_panel.pursuit_flow.next_step()
		game._confirm_start()
		game._update_visuals(0.0)
		var intro = game.broadcast_intro
		check(intro.active and game.start_state == "INTRO", "First event must show intro")
		check(intro.duration == (26.0 if choice == 0 else 28.0), "Mode duration incorrect")
		var before: Array = game.distances.duplicate()
		for i in range(120): game._physics_process(1.0 / 60.0)
		check(game.clock == 0.0 and game.distances == before and not game.running, "Race advanced during intro")
		intro.elapsed = 1.0; intro.advance(0.0)
		check(intro.subtitle.text == "Welkom bij Velodrome!" and intro.caption_panel.visible, "Short welcome missing")
		check(intro.suite.voices[0].is_playing() and not intro.suite.voices[1].is_playing(), "Welcome mouth cue incorrect")
		intro.elapsed = 3.0; intro.advance(0.0)
		check(intro.subtitle.text.contains("wedstrijd:") and intro.suite.voices[1].is_playing(), "Continuation missing")
		check(intro.sample(3.0).position.distance_to(intro.sample(2.2).position) > 0.5, "Camera waited for second sentence")
		check(intro.light_show.running and intro.light_show.spots.size() == 6, "Moving spotlights missing")
		if choice > 0:
			check(not intro.opponent_visible(7.999) and intro.opponent_visible(8.0) and intro.opponent_visible(9.999) and not intro.opponent_visible(10.0), "Card must hold exactly two seconds")
			var hold: Dictionary = intro.sample(8.0)
			for t in [8.5, 9.0, 9.999]:
				var pose: Dictionary = intro.sample(t)
				check(pose.position.distance_to(hold.position) < 0.0001 and pose.target.distance_to(hold.target) < 0.0001, "Opponent framing moved during hold")
			intro.elapsed = 9.0; intro.advance(0.0)
			check(intro.opponent_card.visible and not intro.opponent_card.profile.name.is_empty(), "Profile missing")
			check(intro.opponent_card.portraits.size() == game.team_size if choice == 2 else is_instance_valid(intro.opponent_card.passport), "Actual opponent portrait/passport missing")
			check(intro.opponent_card.profile.cp_w == (game.team_race.pacer.cp_w if choice == 2 else game.pursuit_pacer.cp_w), "Card differs from actual opponent capacity")
			var replay := {"name": "Opgeslagen tegenstander", "time_s": 70.5, "distance_m": 1000}
			if choice == 2: game.team_race.replay = replay
			else: game.pursuit_replay = replay
			intro.opponent_card.prepare()
			check(intro.opponent_card.profile.name == replay.name and intro.opponent_card.profile.time_s == 70.5 and not intro.opponent_card.profile.has("cp_w"), "Replay card invented AI capabilities")
			if choice == 2: game.team_race.replay = {}
			else: game.pursuit_replay = {}
		var joins: Array = []
		for knot in intro.flight_knots(): joins.append(knot[0])
		for t in joins:
			var a: Vector3 = intro.sample(t - 0.001).position
			var b: Vector3 = intro.sample(t).position
			var c: Vector3 = intro.sample(t + 0.001).position
			check(a.distance_to(c) < 0.1, "Camera position discontinuity at %.1f" % t)
			check(((b-a)-(c-b)).length() < 0.001, "Camera velocity discontinuity at %.1f" % t)
		var final_start: float = intro.tour_start() + 10.0
		# The scenic turns must retain a stadium view rather than dive at the floor.
		for frame in range(int((intro.duration - intro.tour_start()) * 60.0)):
			var pose: Dictionary = intro.sample(intro.tour_start() + float(frame) / 60.0)
			var direction: Vector3 = (pose.target - pose.position).normalized()
			check(direction.y >= sin(deg_to_rad(-20.01)), "Scenic turn lost the stadium horizon")
		var last_y: float = intro.sample(final_start).position.y
		for i in range(1, 601):
			var t: float = lerpf(final_start, intro.duration, float(i)/600.0)
			var p: Vector3 = intro.sample(t).position
			check(p.y <= last_y + 0.00001, "Final approach bounced upward")
			last_y = p.y
			check(not (absf(p.x-9.4) < 1.8 and absf(p.z-23.0) < 1.8 and p.y < 3.5), "Final path clips press tent")
		check(intro.sample(intro.duration).position.distance_to(intro.chase_pose().position) < 0.001, "Route misses actual player start")
		intro.elapsed = intro.duration - .01; intro.advance(.02)
		check(game.start_state == "WAIT_STOP" and not intro.active and intro.holding_chase, "Intro did not hand off to stop gate")
		check(not intro.light_show.running and not intro.opponent_card.visible and intro.opponent_card.portraits.is_empty(), "Presentation resources not cleaned")
		check(is_equal_approx(intro.light_show.environment.ambient_light_energy, intro.light_show.ambient), "Ambient light not restored")
		intro.apply_camera()
		check(game.camera.position.distance_to(intro.chase_pose().position) < .001, "Camera did not end behind rider")
		for i in range(60): game._physics_process(.02)
		check(game.start_state == "COUNTDOWN", "Normal countdown did not start")
		for i in range(170): game._physics_process(.02)
		check(game.start_state == ("NEUTRAL" if choice == 0 else "RACING") and game.running, "Countdown enters the discipline's start phase")
		game._reset()
		game.setup_panel.select_mode((choice + 1) % 3)
		if game.setup_panel.pursuit_flow.visible: game.setup_panel.pursuit_flow.next_step()
		game._confirm_start()
		check(not intro.active and not intro.overlay.visible and game.start_state == "WAIT_STOP", "Second event replayed intro")
		game.trainer_seen = true; game.connected = true; game.trainer_ready = true
		game.trainer_speed_kmh = 12.0; game.watts = 150.0; game.last_telemetry = game._now_s()
		for i in range(30): game._physics_process(.02)
		check(game.start_state == ("WAIT_STOP" if game._start_requires_standstill() else "COUNTDOWN") and not game.running, "Session skip preserves standstill or rolling trainer gate")
		game._reset(); game.free()
		await process_frame
	var game := IntroGame.new()
	root.add_child(game); game.set_physics_process(false)
	await process_frame
	game._confirm_start(); game.broadcast_intro.finish()
	check(not game.broadcast_intro.light_show.running, "Manual skip left lightshow active")
	game._reset(); game._confirm_start()
	check(not game.broadcast_intro.active, "Manual skip was forgotten")
	var settings = game.get_node("GameSettings")
	check(not settings.always_show_intro and not settings.intro_check.button_pressed, "Repeat intro must default off")
	settings.intro_check.button_pressed = true
	settings._on_apply()
	check(settings.always_show_intro, "Settings apply did not enable repeat")
	var stored := ConfigFile.new()
	stored.load(settings.SETTINGS_PATH)
	check(stored.get_value("presentation", "always_show_intro", false), "Repeat preference not saved")
	settings.always_show_intro = false
	settings._load_settings()
	check(settings.always_show_intro, "Repeat preference did not reload")
	game._reset(); game._confirm_start()
	check(game.broadcast_intro.active, "Enabled preference did not repeat intro")
	game.broadcast_intro.cancel()
	check(not game.broadcast_intro.light_show.running, "Cancel did not restore lights")
	settings.intro_check.button_pressed = false
	settings._on_apply()
	game._reset(); game._confirm_start()
	check(not game.broadcast_intro.active, "Disabling repeat forgot session history")
	game._reset(); game.free()
	for path in saved_preferences:
		if saved_preferences[path] == null:
			DirAccess.remove_absolute(path)
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(saved_preferences[path])
			file.close()
	if failures == 0: print("BROADCAST_INTRO_OK")
	quit(0 if failures == 0 else 1)
