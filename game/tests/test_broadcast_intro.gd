extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := preload("res://main.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.setup_panel.selected = 0
	game._confirm_start()
	var intro = game.broadcast_intro
	check(game.start_state == "INTRO" and intro.active, "Start must enter intro")
	var before: Array = game.distances.duplicate()
	for i in range(120): game._physics_process(1.0 / 60.0)
	check(game.clock == 0.0 and game.distances == before and not game.running, "Race advanced during intro")
	intro.elapsed = 5.0
	intro.advance(0.0)
	check(intro.caption_panel.visible and intro.subtitle.text == "Welkom bij Velodrome! Welkom bij de volgende wedstrijd: de scratch!", "Welcome subtitle missing")
	check(intro.suite.voices[0].is_playing() and not intro.suite.voices[1].is_playing(), "First speaker cue")
	intro.elapsed = 8.0
	intro.advance(0.0)
	check(not intro.suite.voices[0].is_playing() and intro.suite.voices[1].is_playing(), "Second speaker cue")
	intro.elapsed = 11.0
	intro.advance(0.0)
	check(not intro.caption_panel.visible, "Welcome did not clear")
	# Position and velocity remain continuous at every flight join, in every route.
	for mode in [0, 4, 5]:
		game._reset()
		game.setup_panel.select_mode({0: 0, 4: 1, 5: 2}[mode])
		game._confirm_start()
		check(intro.subtitle.text == intro.welcome_for_mode(mode), "Discipline subtitle stale after mode switch")
		check(game.race_mode == mode and intro.active, "Test did not enter requested race intro")
		game._update_visuals(0.0)
		for knot in intro.flight_knots():
			var t: float = knot[0]
			var before_pos: Vector3 = intro.sample(t - .001).position
			var at_pos: Vector3 = intro.sample(t).position
			var after_pos: Vector3 = intro.sample(t + .001).position
			check(before_pos.distance_to(after_pos) < .05, "Camera position jump")
			check(((at_pos-before_pos) - (after_pos-at_pos)).length() < .0002, "Camera velocity discontinuity")
		for i in range(301):
			var t := 30.0 + float(i) / 100.0
			var pos: Vector3 = intro.sample(t).position
			check(absf(pos.x - 9.15) < .01 and pos.y < 2.1 and pos.y > 1.8, "Camera leaves tent clearance corridor")
		check(intro.sample(intro.DURATION).position.distance_to(intro.chase_pose().position) < .001, "Route misses actual start")
		if mode in [4, 5]:
			for i in range(901):
				var pos: Vector3 = intro.sample(35.0 + float(i)/100.0).position
				check(pos.z >= intro.chase_pose().position.z - .01, "Pursuit overshoots its start")
	game._reset()
	game.setup_panel.select_mode(0)
	game._confirm_start()
	intro.elapsed = intro.DURATION - .01
	intro.advance(.02)
	check(game.start_state == "WAIT_STOP" and not intro.active and intro.holding_chase, "Intro did not hand off to stop gate")
	intro.apply_camera()
	check(game.camera.position.distance_to(intro.chase_pose().position) < .001, "Camera did not end behind rider")
	for i in range(100): game._physics_process(.02)
	check(game.start_state == "COUNTDOWN", "Normal countdown did not start")
	for i in range(170): game._physics_process(.02)
	check(game.start_state == "RACING" and game.running, "Countdown failed to start racing")
	game._reset()
	check(not intro.active and not intro.holding_chase and not intro.overlay.visible, "Reset left intro active")
	game.setup_panel.selected = 0
	game._confirm_start()
	intro.finish()
	check(game.start_state == "WAIT_STOP" and not intro.overlay.visible, "Skip failed")
	# Live trainer movement must still block the countdown after skipping.
	game.trainer_seen = true
	game.connected = true
	game.trainer_ready = true
	game.trainer_speed_kmh = 12.0
	game.watts = 150.0
	game.last_telemetry = game._now_s()
	for i in range(60): game._physics_process(.02)
	check(game.start_state == "WAIT_STOP" and not game.running, "Intro bypassed trainer stop gate")
	game._reset()
	game.free()
	if failures == 0: print("BROADCAST_INTRO_OK")
	quit(0 if failures == 0 else 1)
