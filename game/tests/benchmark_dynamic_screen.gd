extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 1000)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var game := preload("res://tests/arena_roof_test_game.gd").new()
	viewport.add_child(game)
	game.set_physics_process(false)
	await process_frame
	game.setup_panel.select_mode(3); game._confirm_start()
	game.broadcast_intro.cancel(); game._set_race_hud_visible(false)
	game.start_state = "RACING"; game.clock = 120.
	game.camera.position = Vector3(-39, 15, -22)
	game.camera.look_at(Vector3(0, 14, 0)); game.camera.fov = 80
	var screen = game.arena.get_node("InfinityScreen")
	var board = screen.scoreboard
	var results := []
	for enabled in [false, true, false, true]:
		if enabled: board.resume_scoreboard()
		else:
			board.suspend_scoreboard()
			screen.set_content(preload("res://assets/boarding/velodrome-boarding.png"))
		for i in 25: await RenderingServer.frame_post_draw
		var start := Time.get_ticks_usec()
		var updates: int = board.render_count
		for i in 60: await RenderingServer.frame_post_draw
		var elapsed := (Time.get_ticks_usec() - start) / 1000000.0
		results.append({"dynamic": enabled, "frame_ms": elapsed * 1000.0 / 60.0, "content_updates": board.render_count - updates, "elapsed_s": elapsed,
			"scoreboard_cameras": board.find_children("*", "Camera3D", true, false).size(), "resolution": "1536x512"})
	var file := FileAccess.open("res://verification/dynamic_screen/benchmark.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	print("DYNAMIC_SCREEN_BENCHMARK ", JSON.stringify(results))
	game.queue_free()
	await process_frame
	quit()
