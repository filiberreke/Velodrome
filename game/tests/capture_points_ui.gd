extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verification/points_ui"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920,1080)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = preload("res://main.gd").new()
	viewport.add_child(game)
	game.set_physics_process(false)
	game.setup_panel.select_mode(3)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://verification/points_ui/menu.png")
	game._confirm_start()
	game.start_state = "RACING"
	game.clock = 235.
	for i in range(game.rider_count):
		game.distances[i] = 2380. + i * 2.1
		game.speeds[i] = 11.
		game.points_rules.points[i] = i % 6
	game.points_rules.points[0] = 8
	game._update_visuals(0.1)
	game._update_hud()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://verification/points_ui/hud.png")
	game.finished = true
	game.finish_overlay.show()
	game._set_race_hud_visible(false)
	game._refresh_fullscreen_results()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://verification/points_ui/results.png")
	print("POINTS_CAPTURES_OK")
	quit()
