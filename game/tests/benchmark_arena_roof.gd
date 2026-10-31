extends SceneTree
## Paired measurement of the new static components in the same real viewport.
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
	game.setup_panel.select_mode(0)
	game._confirm_start()
	game.broadcast_intro.cancel()
	game.camera.position = Vector3(-39, 15, -22)
	game.camera.look_at(Vector3(0, 14, 0))
	game.camera.fov = 80
	var results := []
	for enabled in [false, true, false, true]:
		for component in ["ArenaRoofStructure", "ProfessionalFloodlights", "InfinityScreen"]:
			game.arena.get_node(component).visible = enabled
		for i in 10: await RenderingServer.frame_post_draw
		var start := Time.get_ticks_usec()
		for i in 40: await RenderingServer.frame_post_draw
		results.append({"new_components": enabled, "frame_ms": (Time.get_ticks_usec() - start) / 40000.0,
			"draw_calls": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"primitives": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)})
	var file := FileAccess.open("res://verification/arena_roof/benchmark.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	print("ARENA ROOF GPU BENCHMARK: ", JSON.stringify(results))
	game.queue_free()
	await process_frame
	quit()
