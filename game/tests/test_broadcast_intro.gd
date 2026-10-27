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
	check(intro.caption_panel.visible and intro.subtitle.text == intro.WELCOME, "Welcome subtitle missing")
	check(intro.suite.voices[0].is_playing() and not intro.suite.voices[1].is_playing(), "First speaker cue")
	intro.elapsed = 8.0
	intro.advance(0.0)
	check(not intro.suite.voices[0].is_playing() and intro.suite.voices[1].is_playing(), "Second speaker cue")
	intro.elapsed = 11.0
	intro.advance(0.0)
	check(not intro.caption_panel.visible, "Welcome did not clear")
	# Path is continuous, finite and above the riding surface for the whole orbit.
	for boundary in [4.0, 10.0, 14.0, 32.0]:
		check(intro.sample(boundary - .0001).position.distance_to(intro.sample(boundary + .0001).position) < .02, "Camera position jump")
		check(intro.sample(boundary - .0001).target.distance_to(intro.sample(boundary + .0001).target) < .02, "Camera target jump")
	for i in range(181):
		var u := float(i) / 180.0
		var pose: Dictionary = intro.orbit_pose(u)
		var expected: Vector3 = game._at(game.LAP * intro.smooth_phase(u), 6.0)
		check(Vector2(pose.position.x, pose.position.z).distance_to(Vector2(expected.x, expected.z)) < .001, "Orbit must follow CCW track")
		check(pose.position.y > expected.y + 1.5, "Orbit intersects banking")
	check(intro.orbit_pose(0.0).position.x == intro.orbit_pose(1.0).position.x, "Full lap did not close")
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
