extends SceneTree
const Feed := preload("res://infinity_race_feed.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := preload("res://tests/arena_roof_test_game.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	var screen = game.arena.get_node("InfinityScreen")
	var board = screen.scoreboard
	board.set_process(false)
	check(board.viewport.disable_3d and board.viewport.size == Vector2i(1536, 512), "One bounded 2D viewport")
	var cameras: int = game.find_children("*", "Camera3D", true, false).size()
	check(board.find_children("*", "Camera3D", true, false).is_empty(), "No scoreboard cameras")
	for mat in screen.display_materials: check(mat.get_shader_parameter("content_texture") == board.viewport.get_texture(), "Same dynamic texture on both faces")
	for surface in ["OuterLED", "InnerLED"]:
		var node: MeshInstance3D = screen.get_node(surface)
		var mat: ShaderMaterial = node.material_override
		check(mat.get_shader_parameter("zoned_content") == true, "Four-zone scoreboard layout is active")
		var centers: Vector4 = mat.get_shader_parameter("score_centers")
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var found := {"right": false, "left": false, "north": false, "south": false}
		for zone in 4:
			var nearest := INF
			var p := Vector3.ZERO
			for i in range(0, vertices.size(), 2):
				if absf(uv[i].x - centers[zone]) < nearest:
					nearest = absf(uv[i].x - centers[zone]); p = vertices[i]
			if p.x > 5. and absf(p.z) < .3: found.right = true
			if p.x < -5. and absf(p.z) < .3: found.left = true
			if p.z > 15. and absf(p.x) < .3: found.north = true
			if p.z < -15. and absf(p.x) < .3: found.south = true
		check(found.values().all(func(value: bool) -> bool: return value), "Four score locations align with both straights and both ends on each face")
	var side_texture := ImageTexture.create_from_image(Image.create(16, 9, false, Image.FORMAT_RGBA8))
	screen.set_side_content(side_texture)
	for mat in screen.display_materials:
		check(mat.get_shader_parameter("branding_texture") == side_texture and is_equal_approx(mat.get_shader_parameter("brand_aspect"), 16.0 / 9.0), "Future side footage preserves aspect ratio")
		check(mat.get_shader_parameter("content_texture") == board.viewport.get_texture(), "Replacing side content retains the scoreboards")
	screen.set_side_content(preload("res://assets/boarding/velodrome-boarding.png"))
	var feed := Feed.new()
	for selection in [0, 3, 1, 2]:
		game._reset()
		game.setup_panel.select_mode(selection)
		game._confirm_start()
		board.data.clear(); board.poll_elapsed = .1
		board._process(.11)
		check(board.model.state == "INTRO" and board.model.view().title == feed.sample(game).discipline, "Actual menu intro discipline")
		game.broadcast_intro.finish()
		game.start_state = "RACING"; game.clock = 22.0
		board.poll_elapsed = .1; board._process(.11)
		check(board.model.state == "RACE", "Actual discipline enters scoreboard race state")
		if game.race_mode in [4, 5]:
			game.pursuit_half_crossings = [[10., 20., 30.], [10.4, 20.6]]
			game.lap_times[0] = [20.]; game.lap_times[1] = [20.6]
			var data := feed.sample(game)
			check(is_equal_approx(data.gap_seconds, .6) and data.checkpoint_m == 250.0, "Pursuit compares last common checkpoint")
			if game.race_mode == 5:
				game.team_race.progress.assign([900., 840.])
				data = feed.sample(game)
				check(data.positions == [900., 840.] and data.names.size() == 2, "Team timing uses team progress, not individual rider positions")
		if game.race_mode == 1:
			var count: int = game.rider_count
			game.points_rules.reset(count, game.race_laps)
			var positions: Array[float] = []
			for i in count: positions.append(1002. + i * 2.)
			positions[-1] = 1252.
			game.points_rules._judge_laps(positions, 22.)
			board.poll_elapsed = .1; board._process(.11)
			check(board.model.state == "LAP_GAIN" and board.model.view().headline == "+20 POINTS", "Actual jury feeds integrated display")
			var before: Array = game.points_rules.points.duplicate()
			for i in 20: board._process(.05)
			check(game.points_rules.points == before, "Integrated display leaves scoring unchanged")
	check(game.find_children("*", "Camera3D", true, false).size() == cameras, "Discipline switches introduce no cameras")
	board.model.reset(); board.data = feed.sample(game); board.data.phase = "RACING"; board.data.winner = -1
	board.data.positions = [0.0, 0.0]
	board.model.update(board.data, .1); board.model.age = 20.; board.canvas.fade = 1.
	board.poll_elapsed = -100.
	board.render_elapsed = 0.0
	var before_render: int = board.render_count
	for i in 60: board._process(1.0 / 60.)
	check(board.render_count - before_render <= 8, "Quiet scoreboards throttle rendering to 8 Hz")
	var calm: Dictionary = board.model.view()
	board.canvas.present(calm, 20., 1.)
	var celebration: Dictionary = calm.duplicate(true)
	celebration.state = "LAP_GAIN"; celebration.moment = "lap_gain"
	board.canvas.present(celebration, .1, .1)
	check(board.canvas.fade > 0.0 and board.canvas.fade < 1.0 and board.canvas.previous.state == calm.state, "State changes retain old content and crossfade smoothly")
	board.suspend_scoreboard()
	check(board.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Future external content can suspend rendering")
	board.resume_scoreboard()
	print("INFINITY_INTEGRATION_OK failures=", failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
