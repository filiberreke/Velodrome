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
	game.setup_panel.select_mode(0)
	game._confirm_start()
	var intro = game.broadcast_intro
	for pair in [[0.0,"Intro_01_approach"],[5.0,"Intro_02_welcome"],[12.0,"Intro_03_depart"],[19.0,"Intro_04_orbit"],[26.0,"Intro_05_descend"],[35.99,"Intro_06_player"]]:
		intro.elapsed = pair[0]
		intro.advance(0.0)
		game._update_visuals(0.0)
		for i in range(8): await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(OUTPUT + pair[1] + ".png")
	# Render deterministic full motion for a reviewable video, including the countdown.
	var frames := OUTPUT + ".intro_frames/"
	DirAccess.make_dir_recursive_absolute(frames)
	intro.elapsed = 0.0
	for frame in range(40*15):
		game._physics_process(1.0/15.0)
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_jpg(frames + ("%04d.jpg" % frame), .82)
	print("BROADCAST_INTRO_CAPTURE_OK")
	viewport.free()
	quit()
