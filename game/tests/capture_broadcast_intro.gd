extends SceneTree
const OUTPUT := "res://verification/commentary_box/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var game := preload("res://main.gd").new()
	viewport.add_child(game)
	game.set_physics_process(false)
	await process_frame
	var pursuit := "pursuit" in OS.get_cmdline_user_args()
	game.setup_panel.select_mode(1 if pursuit else 0)
	var prefix := "Pursuit_" if pursuit else "Flight_"
	game._confirm_start()
	var intro = game.broadcast_intro
	for pair in [[12.0,"departure"],[20.0,"opponent"],[27.5,"pizza"],[30.5,"tent_entry"],[32.0,"tent_inside"],[34.5,"tent_exit"],[38.0,"start_approach"],[43.99,"player"]]:
		intro.elapsed = pair[0]
		intro.advance(0.0)
		game._update_visuals(0.0)
		for i in range(8): await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(OUTPUT + prefix + pair[1] + ".png")
	# Render deterministic full motion for a reviewable video, including the countdown.
	var frames := OUTPUT + (".pursuit_frames/" if pursuit else ".intro_frames/")
	DirAccess.make_dir_recursive_absolute(frames)
	intro.elapsed = 0.0
	for frame in range(0 if "stills" in OS.get_cmdline_user_args() else 48*15):
		game._physics_process(1.0/15.0)
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_jpg(frames + ("%04d.jpg" % frame), .82)
	print("BROADCAST_INTRO_CAPTURE_OK")
	viewport.free()
	quit()
