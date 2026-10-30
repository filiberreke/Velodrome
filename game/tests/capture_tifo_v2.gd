extends SceneTree
const OUT := "res://verification/tifo_v2/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920,1080)
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
	var show = game.arena.get_node("VelodromeStadiumShow")
	show.set_process(false)
	show._process(0.0)
	for t in [13.0,16.0,19.0,22.0]:
		game.broadcast_intro.elapsed = t
		game._update_visuals(0.0)
		for i in range(8): await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(OUT + "intro_%02d.png" % t)
	game.broadcast_intro.cancel()
	game._set_race_hud_visible(false)
	game.setup_panel.hide()
	var center: Vector3 = game.arena._stadium_point(28.0,21.35,8.8)
	print("TIFO_CENTER ",center)
	for shot in [["stadium",Vector3(0,22,0),center,75.0],["first_bend",Vector3(0,14,-20),center,60.0]]:
		game.camera.global_position = shot[1]
		game.camera.look_at(shot[2])
		game.camera.fov = shot[3]
		for i in range(8): await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(OUT + shot[0] + ".png")
	game.start_state = "RACING"
	for i in game.distances.size(): game.distances[i] = 238.0
	show._process(0.0)
	for i in range(8): await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUT + "withdrawal.png")
	for shot in ["intro_13", "stadium", "first_bend", "withdrawal"]:
		var image := Image.load_from_file(OUT + shot + ".png")
		image.save_jpg(OUT + shot + ".jpg", 0.94)
	print("TIFO_V2_CAPTURE_OK")
	viewport.free()
	quit()
