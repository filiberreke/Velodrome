extends SceneTree
## Real Compatibility GPU captures of the integrated stadium.
const OUTPUT := "res://verification/arena_roof/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var viewport := SubViewport.new()
	var review := "--review-previews" in OS.get_cmdline_user_args()
	viewport.size = Vector2i(1000, 625) if review else Vector2i(1600, 1000)
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
	var intro = game.broadcast_intro
	for pair in [[2.0, "intro_cabin"], [13.0, "intro_arena"], [16.0, "intro_roof"], [22.0, "intro_stands"], [43.99, "intro_start"]]:
		intro.elapsed = pair[0]
		intro.advance(0.0)
		game._update_visuals(0.0)
		for i in 6: await RenderingServer.frame_post_draw
		if review:
			viewport.get_texture().get_image().save_jpg(OUTPUT + pair[1] + ".jpg", 0.86)
		else:
			viewport.get_texture().get_image().save_png(OUTPUT + pair[1] + ".png")
	intro.cancel()
	game._set_race_hud_visible(false)
	if game.setup_panel: game.setup_panel.hide()
	for view in [
		["track", Vector3(21, 2.8, -18), Vector3(0, 14, 2), 78.0],
		["stands", Vector3(-39, 15, -22), Vector3(0, 14, 0), 80.0],
		["under_screen", Vector3(0, 5, -8), Vector3(0, 20, 4), 98.0],
		["roof_overview", Vector3(34, 16, 44), Vector3(0, 23, 0), 90.0],
		["screen_detail", Vector3(14, 14.3, -8), Vector3(7, 14.3, -8), 75.0]]:
		game.camera.position = view[1]
		game.camera.look_at(view[2])
		game.camera.fov = view[3]
		for i in 8: await RenderingServer.frame_post_draw
		if review:
			viewport.get_texture().get_image().save_jpg(OUTPUT + view[0] + ".jpg", 0.86)
		else:
			viewport.get_texture().get_image().save_png(OUTPUT + view[0] + ".png")
	print("ARENA ROOF CAPTURES COMPLETE")
	game.queue_free()
	await process_frame
	quit()
